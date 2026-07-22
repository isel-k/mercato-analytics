"""dlt pipeline: ClubElo -> Snowflake RAW.raw_clubelo.

Source: http://api.clubelo.com/ (free, no auth, no documented rate limit — a
single-maintainer research API widely used via tools like the `soccerdata`
library). Provides Elo strength ratings for European club sides back to 1939.

Two-stage load, since ClubElo has no "list all clubs" endpoint:
1. `discover_clubs` samples one yearly snapshot (api.clubelo.com/YYYY-06-01) to
   build the set of club names ClubElo has ever tracked — a club relegated out
   of the top flight years ago still needs its *historical* rating available
   for old transfers, so a "clubs tracked today" snapshot alone isn't enough.
2. `club_ratings` fetches each discovered club's full rating history
   (api.clubelo.com/CLUBNAME) and yields every period row.

ClubElo only covers European football — no South American, North American,
Asian, or Middle Eastern clubs — so a meaningful share of `dim_club` will never
match here. That's a real coverage limit of the source, not a bug: see
`dbt/seeds/clubelo_club_mapping.csv` and ARCHITECTURE.md for the club-name
matching this feeds into.
"""

import csv
import io
import time
import urllib.parse

import dlt
from dlt.sources.helpers import requests
from requests.exceptions import RequestException

BASE_URL = "http://api.clubelo.com"

# One sampled snapshot per year is enough to discover (almost) every club
# ClubElo has ever tracked, at a fraction of the request cost of finer-grained
# sampling — the ratings themselves come from the per-club endpoint below.
DISCOVERY_YEARS = range(1996, 2027)

# Respectful, fixed delay between requests. Started at 0.2s; raised to 1s after
# a ~1700-request run in one burst was followed by every request timing out
# outright (HTTP 000, no response at all) — looks like a soft rate-limit or
# block from ClubElo's side reacting to the burst, not a coincidence. No
# documented limit to target instead, so this is a deliberately conservative
# guess, not a verified-safe number.
SECONDS_BETWEEN_REQUESTS = 1.0

# A run touches ~1700 clubs sequentially; a transient timeout on any single one
# used to crash the whole extraction and lose everything (dlt only loads after
# extraction fully completes — hit this for real on the first run, ~12 minutes
# in). Retry a few times, then skip that one club with a warning rather than
# fail the run — a club Elo will just fetch clean next run via `merge`.
MAX_ATTEMPTS_PER_REQUEST = 3

# If the host is unreachable or throttling us, every one of the ~1700 requests
# will fail the same way — better to abort loudly after a short run of
# consecutive failures than silently burn ~3 * 30s per club for hours. Hit this
# for real too: a run right after the burst above saw every single request
# time out (even ones that worked fine seconds earlier).
MAX_CONSECUTIVE_FAILURES = 8
_consecutive_failures = 0


def _get_csv(path: str) -> list[dict]:
    global _consecutive_failures
    last_error = None
    for attempt in range(MAX_ATTEMPTS_PER_REQUEST):
        try:
            response = requests.get(f"{BASE_URL}/{urllib.parse.quote(path)}", timeout=30)
            response.raise_for_status()
            time.sleep(SECONDS_BETWEEN_REQUESTS)
            _consecutive_failures = 0
            return list(csv.DictReader(io.StringIO(response.text)))
        except RequestException as error:
            last_error = error
            time.sleep(2 * (attempt + 1))
    _consecutive_failures += 1
    if _consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
        raise RuntimeError(
            f"{MAX_CONSECUTIVE_FAILURES} consecutive requests to {BASE_URL} all failed — "
            "looks like the host is down or throttling us, not isolated flakiness. "
            "Aborting rather than grinding through the rest of the club list."
        ) from last_error
    print(f"WARNING: giving up on {path!r} after {MAX_ATTEMPTS_PER_REQUEST} attempts: {last_error}")
    return []


def _discover_clubs() -> list[tuple[str, str]]:
    seen = {}
    for year in DISCOVERY_YEARS:
        for row in _get_csv(f"{year}-06-01"):
            seen[(row["Club"], row["Country"])] = True
    return list(seen)


@dlt.source(name="clubelo")
def clubelo_source():
    clubs = _discover_clubs()

    @dlt.resource(name="discovered_clubs", write_disposition="replace", primary_key=["club", "country"])
    def discovered_clubs():
        for club, country in clubs:
            yield {"club": club, "country": country}

    @dlt.resource(
        name="ratings",
        write_disposition="merge",
        primary_key=["club", "country", "from_date"],
    )
    def ratings():
        for club, _country in clubs:
            for period in _get_csv(club):
                yield {
                    "club": period["Club"],
                    "country": period["Country"],
                    "level": period["Level"],
                    "elo": period["Elo"],
                    "from_date": period["From"],
                    "to_date": period["To"],
                }

    return discovered_clubs, ratings


def run() -> None:
    pipeline = dlt.pipeline(
        pipeline_name="clubelo",
        destination="snowflake",
        dataset_name="raw_clubelo",
    )
    load_info = pipeline.run(clubelo_source())
    print(load_info)


if __name__ == "__main__":
    run()
