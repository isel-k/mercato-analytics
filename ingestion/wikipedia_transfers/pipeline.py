"""dlt pipeline: Wikipedia club-season pages -> Snowflake RAW.raw_wikipedia_transfers.

Why this exists: the Kaggle Transfermarkt snapshot (ingestion/transfermarkt/) has a
real coverage gap for the most recent ~1-2 seasons — verified directly, not
assumed: Real Madrid has zero transfers recorded since July 2024, while other big
clubs (Man Utd, Man City, PSG) do have partial 2025-26 records, so it's inconsistent
per-club scraper staleness upstream, not a blanket cutoff. See ARCHITECTURE.md.

Scraping transfermarkt.com directly to fix this was considered and explicitly
rejected: their robots.txt names ClaudeBot/Claude-SearchBot/anthropic-ai (plus every
other AI crawler) with `Disallow: /`, not just a generic bot block. Wikipedia is
different — checked directly, no Claude/AI-specific disallow, content is
CC-BY-SA-licensed for reuse, and the MediaWiki API is the documented, intended way
to access it programmatically (this pipeline uses that API, not raw HTML scraping).

Two-stage per club:
1. Fetch the "Transfers" section of "{season} {club} season" (In/Out wikitables).
   Reliable and structured, but not standardized across clubs — verified 5
   different column-naming conventions for the from/to club alone ("From"/"To",
   "Transfer from/to", "Transferred from/to", "Moving from/to", "Loaned
   from/to" + "Returning from/to"), handled by substring matching rather than
   exact names (see `_club_season_rows`).
2. Fee: some pages put it directly in a structured "Fee" column (preferred when
   present — free, no extra request, more reliable). Otherwise, for rows that
   plausibly have one (not free/loan/contract-end), fetch that player's own
   Wikipedia page and regex-search its prose for a fee mention near the
   destination club. This fallback is inherently best-effort: verified against
   real examples that fee phrasing is inconsistent (present for some
   confirmed-fee moves, absent even when a fee exists elsewhere in the same
   article) — expect real false negatives, not a complete fee dataset.

Only a curated list of clubs is targeted (TARGET_CLUBS below) — big European clubs
identified as having gone unusually long without a Transfermarkt-recorded transfer.
Not a general replacement for Transfermarkt; a targeted patch for its biggest gap.
"""

import datetime as dt
import json
import re
import time
import urllib.parse
import urllib.request

import dlt
from bs4 import BeautifulSoup

USER_AGENT = "mercato-analytics-portfolio-project/1.0 (https://github.com/isel-k/mercato-analytics)"
API_URL = "https://en.wikipedia.org/w/api.php"
SECONDS_BETWEEN_REQUESTS = 0.5

# Big European clubs found to have gone > ~300 days without a Transfermarkt-
# recorded transfer despite a current ClubElo rating >= 1700 (i.e. still a top-
# division, notable club) — see the query in this module's README. Re-run that
# query periodically; this list will drift as Transfermarkt's own coverage
# catches up (or doesn't) for a given club.
TARGET_CLUBS = [
    (989, "AFC Bournemouth"), (162, "AS Monaco"), (11, "Arsenal FC"),
    (12, "Associazione Sportiva Roma"), (800, "Atalanta BC"), (13, "Atlético de Madrid"),
    (1148, "Brentford FC"), (1237, "Brighton & Hove Albion"), (940, "Celta de Vigo"),
    (631, "Chelsea FC"), (2282, "Club Brugge KV"), (29, "Everton FC"),
    (131, "FC Barcelona"), (720, "FC Porto"), (931, "Fulham FC"), (46, "Inter Milan"),
    (506, "Juventus FC"), (1082, "LOSC Lille"), (399, "Leeds United"),
    (31, "Liverpool FC"), (762, "Newcastle United"), (703, "Nottingham Forest"),
    (1041, "Olympique Lyon"), (244, "Olympique Marseille"), (383, "PSV Eindhoven"),
    (150, "Real Betis Balompié"), (418, "Real Madrid"), (60, "SC Freiburg"),
    (294, "SL Benfica"), (289, "Sunderland AFC"), (1050, "Villarreal CF"),
]

# How many seasons back from the current one to check per club (current season
# a club is refreshed for depends on today's date, computed in current_seasons()).
SEASONS_BACK = 2

FEE_PATTERN = re.compile(
    r"(?:fee|signing|deal|transfer|clause)[^.]{0,80}?"
    r"(?:reported to be|of|worth|around|approximately|for|understood to be)?"
    r"[^.\d]{0,25}?([€£$]\s?\d[\d,.]*\s?(?:million|m\b))",
    re.IGNORECASE,
)
FALLBACK_FEE_PATTERN = re.compile(r"([€£$]\s?\d[\d,.]*\s?(?:million|m\b))", re.IGNORECASE)

# Rows with this Type text can't have a fee (nothing to extract for) — skip the
# per-player page fetch entirely for these, it would only ever come back empty.
NO_FEE_TYPES = {
    "free transfer", "loan", "end of loan", "end of contract", "mutual agreement",
    "released", "promotion", "return from loan",
}


MAX_ATTEMPTS_PER_REQUEST = 3


def _api_get(params: dict) -> dict | None:
    """Retries transient failures instead of raising — found for real that an
    unretried exception here (this function used to have no retry logic at
    all) silently truncated whole clubs out of a run: ~14 of 31 target clubs
    came back with zero rows despite each one resolving fine when called
    individually right after, with failures scattered non-contiguously across
    the club list (not a crash-and-stop pattern) — consistent with isolated
    transient failures during a long batch, not a systematic bug. Returns None
    on exhausted retries rather than raising, so callers can skip gracefully."""
    url = f"{API_URL}?{urllib.parse.urlencode(params)}&format=json"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error = None
    for attempt in range(MAX_ATTEMPTS_PER_REQUEST):
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                data = json.load(r)
            time.sleep(SECONDS_BETWEEN_REQUESTS)
            return data
        except Exception as error:  # noqa: BLE001 - deliberately broad, see docstring
            last_error = error
            time.sleep(2 * (attempt + 1))
    print(f"WARNING: giving up on Wikipedia API call {params!r} after {MAX_ATTEMPTS_PER_REQUEST} attempts: {last_error}", flush=True)
    return None


def current_seasons(n_back: int) -> list[str]:
    """European season strings ("2026–27") for the current season and n_back-1
    prior ones, based on today's date (season flips on 1 July)."""
    today = dt.date.today()
    start_year = today.year if today.month >= 7 else today.year - 1
    return [f"{start_year - i}–{str(start_year - i + 1)[2:]}" for i in range(n_back)]


_GENERIC_CLUB_WORDS = {"fc", "cf", "afc", "sc", "the", "club", "ac", "as"}


def find_season_page(club_name: str, season: str) -> dict | None:
    """Blindly trusting the top search hit is wrong: found for real that
    searching "2026–27 Villarreal CF season" (a page that doesn't exist yet)
    returned "2026–27 Real Madrid CF season" as the #1 result, and a naive
    caller would silently attribute Real Madrid's transfers to Villarreal.
    Requires the season string AND a distinguishing club-name token (skipping
    generic words like "FC"/"CF") to both appear in a candidate's title before
    accepting it — checks the top 3 hits, not just the first."""
    query = f"{season} {club_name} season"
    data = _api_get({"action": "query", "list": "search", "srsearch": query, "srlimit": 3})
    if data is None:
        return None
    hits = data.get("query", {}).get("search", [])
    club_tokens = [w.lower() for w in club_name.split() if w.lower() not in _GENERIC_CLUB_WORDS]
    for hit in hits:
        title = hit["title"]
        title_lower = title.lower()
        if season not in title:
            continue
        if any(tok in title_lower for tok in club_tokens):
            return {"pageid": hit["pageid"], "title": title}
    return None


def find_transfers_section(pageid: int) -> int | None:
    data = _api_get({"action": "parse", "pageid": pageid, "prop": "sections"})
    if data is None:
        return None
    for section in data.get("parse", {}).get("sections", []):
        if "transfer" in section["line"].lower():
            return int(section["index"])
    return None


def _parse_wikitable(table_soup) -> list[dict]:
    """Rowspan/colspan-aware. Each cell value is (text, wikipedia_href_or_None) —
    href is the first link with visible text (skips flag-icon-only links)."""
    rows = table_soup.find_all("tr")
    if not rows:
        return []
    headers = [c.get_text(strip=True) for c in rows[0].find_all(["th", "td"])]
    pending: dict[int, tuple[int, tuple]] = {}
    parsed_rows = []
    for tr in rows[1:]:
        cells = iter(tr.find_all(["td", "th"]))
        current_cell = next(cells, None)
        row_out: dict[int, tuple] = {}
        col_idx = 0
        while col_idx < len(headers):
            if col_idx in pending and pending[col_idx][0] > 0:
                remaining, value = pending[col_idx]
                row_out[col_idx] = value
                pending[col_idx] = (remaining - 1, value)
                col_idx += 1
                continue
            if current_cell is None:
                break
            links = [a for a in current_cell.find_all("a") if a.get_text(strip=True)]
            value = (current_cell.get_text(strip=True), links[0].get("href") if links else None)
            rowspan = int(current_cell.get("rowspan", 1))
            colspan = int(current_cell.get("colspan", 1))
            for c in range(colspan):
                if c == 0:
                    row_out[col_idx] = value
                if rowspan > 1:
                    pending[col_idx + c] = (rowspan - 1, value)
            col_idx += colspan
            current_cell = next(cells, None)
        parsed_rows.append({headers[i]: row_out.get(i, ("", None)) for i in range(len(headers))})
    return parsed_rows


def fetch_transfer_tables(pageid: int, section: int) -> list[dict]:
    data = _api_get({"action": "parse", "pageid": pageid, "prop": "text", "section": section})
    if data is None:
        return []
    html = data.get("parse", {}).get("text", {}).get("*", "")
    soup = BeautifulSoup(html, "lxml")
    rows = []
    for table in soup.find_all("table", class_="wikitable"):
        rows.extend(_parse_wikitable(table))
    return rows


def extract_fee(player_title: str, destination_club_name: str) -> str | None:
    """Best-effort only: searches every mention of the destination club in the
    player's prose (not just the last one — that's commonly "External links",
    verified for real on Marc Cucurella's page) for a nearby fee figure. Real
    articles phrase this inconsistently (present for some confirmed-fee moves,
    absent even when a fee exists elsewhere in the same article), so a None
    here means "not found in prose", not "confirmed free". Also verified a
    range gets reduced to its lower bound (Trent Alexander-Arnold: "reported
    to be between €6.2m and €10m" -> "€6.2m") — a known simplification, not
    a confirmed exact figure, since there's no reliable way to tell "this is
    the one true number" from "this is a range's first half" in free text."""
    data = _api_get({"action": "query", "titles": player_title, "prop": "extracts", "explaintext": 1})
    if data is None:
        return None
    pages = data.get("query", {}).get("pages", {})
    for page in pages.values():
        text = page.get("extract", "")
        if not text:
            continue
        start = 0
        while True:
            idx = text.find(destination_club_name, start)
            if idx == -1:
                break
            window = text[max(0, idx - 100) : idx + 400]
            match = FEE_PATTERN.search(window) or FALLBACK_FEE_PATTERN.search(window)
            if match:
                return match.group(1).strip()
            start = idx + 1
    return None


def _club_season_rows(club_id: int, club_name: str, season: str) -> list[dict]:
    """One club-season's transfer rows. Wrapped in a broad try/except at the
    call site (not here) so a parsing edge case for one club-season (a
    BeautifulSoup/KeyError surprise, not just a network failure — `_api_get`
    already retries those) can't take out the rest of the run."""
    page = find_season_page(club_name, season)
    if page is None:
        return []
    section = find_transfers_section(page["pageid"])
    if section is None:
        return []
    out = []
    for row in fetch_transfer_tables(page["pageid"], section):
        player_text, player_href = row.get("Player", ("", None))
        if not player_text:
            continue
        # Wikipedia's own club-season pages don't agree on column names for
        # this — verified 5 different conventions on real pages: "From"/"To"
        # (Real Madrid), "Transfer from"/"Transfer to" (Barcelona),
        # "Transferred from"/"Transferred to" (Monaco, Benfica), "Moving
        # from"/"Moving to" (Juventus), "Loaned from"/"Loaned to" plus
        # "Returning from"/"Returning to" (Inter Milan, separate loan
        # tables). A literal "From"/"To" check silently dropped every real
        # transfer row for any club not using that exact convention — found
        # this for real (14 of 31 target clubs came back completely empty,
        # Barcelona/Inter/Juventus/Monaco among them) after ruling out
        # network flakiness as the cause.
        from_key = next((k for k in row if "from" in k.lower()), None)
        to_key = next((k for k in row if k.lower().endswith("to")), None)
        if from_key is None and to_key is None:
            # the genuine contract-renewal/no-direction case (Rüdiger,
            # Gonzalo García on Real Madrid's page) — not a transfer at all.
            continue
        other_text, other_href = row.get(from_key) or row.get(to_key) or ("", None)
        direction = "in" if from_key else "out"

        # Some pages put an actual fee/status directly in a "Fee" column
        # (Barcelona: "€70M + €10M variables"; Monaco/Benfica: "None" for a
        # loan return) — more reliable than the player-page prose search
        # below, and free (no extra request), so prefer it when it looks
        # like real money.
        fee_cell_text = next((row[k][0] for k in row if k.lower() == "fee"), "")
        fee_from_table = None
        cell_match = FALLBACK_FEE_PATTERN.search(fee_cell_text)
        if cell_match:
            fee_from_table = cell_match.group(1).strip()

        type_text = row.get("Type", ("", None))[0]
        if not type_text and fee_cell_text:
            lowered = fee_cell_text.lower()
            if "loan" in lowered:
                type_text = "Loan"
            elif "free" in lowered or "none" in lowered or lowered.strip() in {"-", ""}:
                type_text = "Free transfer" if "free" in lowered else ""
            elif fee_from_table:
                type_text = "Transfer"

        fee = fee_from_table
        if (
            fee is None
            and direction == "in"
            and type_text.strip().lower() not in NO_FEE_TYPES
            and player_href
        ):
            player_title = urllib.parse.unquote(player_href.removeprefix("/wiki/"))
            fee = extract_fee(player_title, club_name)
        out.append({
            "club_id": club_id,
            "club_name": club_name,
            "season": season,
            "direction": direction,
            "date": row.get("Date", ("", None))[0],
            "player_name": player_text,
            "player_wiki_title": urllib.parse.unquote(player_href.removeprefix("/wiki/")) if player_href else None,
            "other_club_name": other_text,
            "transfer_type": type_text,
            "fee_text": fee,
            "source_page": page["title"],
        })
    return out


@dlt.source(name="wikipedia_transfers")
def wikipedia_transfers_source():
    @dlt.resource(name="club_transfers", write_disposition="merge", primary_key=["club_id", "player_name", "date", "direction"])
    def club_transfers():
        for club_id, club_name in TARGET_CLUBS:
            for season in current_seasons(SEASONS_BACK):
                try:
                    yield from _club_season_rows(club_id, club_name, season)
                except Exception as error:  # noqa: BLE001 - one club-season must never abort the whole run
                    print(f"WARNING: skipping {club_name!r} {season!r} after unexpected error: {error}", flush=True)

    return club_transfers


def run() -> None:
    pipeline = dlt.pipeline(
        pipeline_name="wikipedia_transfers",
        destination="snowflake",
        dataset_name="raw_wikipedia_transfers",
    )
    load_info = pipeline.run(wikipedia_transfers_source())
    print(load_info)


if __name__ == "__main__":
    run()
