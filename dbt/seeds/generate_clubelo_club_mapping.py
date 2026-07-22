"""Regenerate dbt/seeds/clubelo_club_mapping.csv.

Maintenance tool, not part of any pipeline — run this by hand when `dim_club`
gains enough new clubs that the mapping's coverage is worth refreshing. See
ARCHITECTURE.md decision 13 for why this exists and the correctness bugs this
approach already hit once (naive stopwords, substring bonuses, character-diff
scoring all produced confident wrong matches — read that before changing the
scoring logic here).

Usage:
    1. Export the two inputs this script needs (run from dbt/, against a real
       Snowflake connection):

        dbt show --inline "select club_id, club_name, domestic_competition_id
            from {{ ref('dim_club') }}" --target dev --output json --limit 2000 \\
            > /tmp/dim_club_raw.json
        dbt show --inline "select competition_id, country_name
            from {{ ref('stg_transfermarkt__competitions') }}" --target dev \\
            --output json --limit 500 > /tmp/competitions_countries_raw.json

    2. Run this script (needs `rapidfuzz`: `uv add --dev rapidfuzz` if not
       already a dev dependency):

        uv run python dbt/seeds/generate_clubelo_club_mapping.py \\
            /tmp/dim_club_raw.json /tmp/competitions_countries_raw.json

    3. Review the printed rejected/low-confidence list by hand (real club
       knowledge, not more tuning, is what catches wrong matches) before
       committing the overwritten clubelo_club_mapping.csv.
"""

import csv
import io
import json
import re
import sys
import unicodedata
import urllib.request

from rapidfuzz import fuzz

MAPPING_OUTPUT_PATH = "dbt/seeds/clubelo_club_mapping.csv"
ACCEPT_THRESHOLD = 0.75

# ClubElo only covers European football — every country name absent here has
# no possible match and is skipped up front rather than scored.
COMP_TO_COUNTRY_CODE = {
    "Austria": "AUT", "Belgium": "BEL", "Croatia": "CRO", "Czech Republic": "CZE",
    "Denmark": "DEN", "England": "ENG", "France": "FRA", "Germany": "GER",
    "Greece": "GRE", "Italy": "ITA", "Netherlands": "NED", "Norway": "NOR",
    "Poland": "POL", "Portugal": "POR", "Romania": "ROM", "Russia": "RUS",
    "Scotland": "SCO", "Serbia": "SRB", "Spain": "ESP", "Sweden": "SWE",
    "Switzerland": "SUI", "Türkiye": "TUR", "Ukraine": "UKR",
}

# Pure legal-entity / club-type suffixes — safe to strip, they carry no
# identity. Do NOT add words like "real", "atletico", "athletic", "sporting",
# "united", "deportivo", "racing": those distinguish otherwise-identical club
# names (Real Madrid vs Atletico Madrid) and stripping them caused a same-city
# false match the first time this script was written.
GENERIC_LEGAL = {
    "fc", "cf", "ac", "sc", "sk", "afc", "cfc", "ss", "ssd", "asd", "spa", "sad",
    "as", "cd", "ud", "rc", "nk", "hnk", "gnk", "if", "bk", "fk", "vv", "sv",
    "club", "football", "futbol", "futebol", "calcio", "clube", "klub",
    "sportowy", "sportivo", "sportiva", "spolka", "akcyjna", "association",
    "societa", "spzoo", "the",
    "sportsklubb", "idrettslag", "fotballklubb", "idrettsforening",
    "allmanna", "idrottsklubb", "idrottsforening", "boldklub", "fotbollforening",
}
RESERVE_MARKERS = {"b", "ii", "2", "u23", "u21", "u19", "reserves", "reserve", "youth", "young"}
WORD_ALIASES = {"manchester": "man", "monchengladbach": "gladbach"}

# Individually verified against clubelo.com — the automated matcher either
# missed these (acronyms it can't expand, e.g. QPR) or got them wrong.
MANUAL_OVERRIDES = {
    "West Bromwich Albion": "West Brom",
    "Wolverhampton Wanderers": "Wolves",
    "Heart of Midlothian FC": "Hearts",
    "Stade Rennais FC": "Rennes",
    "Deportivo de La Coruña": "Depor",
    "SpVgg Greuther Fürth": "Fuerth",
    "FC Copenhagen": "FC Kobenhavn",
    "Union Saint-Gilloise": "St Gillis",
    "Red Star Belgrade": "Crvena Zvezda",
    "FCSB": "Steaua",
    "1.FC Köln": "Koeln",
    "1.FC Nuremberg": "Nuernberg",
    "PFK Krylya Sovetov Samara": "Kryliya Sovetov",
    "FC Dinamo 1948": "Dinamo Bucuresti",
    "Grasshopper Club Zurich": "Grasshoppers",
    "Chornomorets Odesa": "Chernomorets",
    "FC Rapid 1923": "Rapid Bucuresti",
}


def tokens(name: str) -> list[str]:
    name = re.sub(r"\(.*?\)", " ", name)
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    name = name.lower()
    name = re.sub(r"[^a-z0-9\s]", " ", name)
    toks = [t for t in name.split() if t not in GENERIC_LEGAL]
    return [WORD_ALIASES.get(t, t) for t in toks]


def has_reserve_marker(toks: list[str]) -> bool:
    return any(t in RESERVE_MARKERS for t in toks)


def fetch_clubelo_master_list() -> dict[str, list[str]]:
    """One sampled snapshot per year since 1996 — see ingestion/clubelo/pipeline.py."""
    by_country: dict[str, list[str]] = {}
    seen = set()
    for year in range(1996, 2027):
        url = f"http://api.clubelo.com/{year}-06-01"
        with urllib.request.urlopen(url, timeout=15) as r:
            text = r.read().decode()
        for row in csv.DictReader(io.StringIO(text)):
            key = (row["Club"], row["Country"])
            if key not in seen:
                seen.add(key)
                by_country.setdefault(row["Country"], []).append(row["Club"])
    return by_country


def load_dbt_show_json(path: str) -> list[dict]:
    with open(path) as f:
        content = f.read()
    return json.loads(content[content.find("{"):])["show"]


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(1)
    dim_club_path, competitions_path = sys.argv[1], sys.argv[2]

    dim_club = load_dbt_show_json(dim_club_path)
    comp_to_country = {
        r["COMPETITION_ID"]: r["COUNTRY_NAME"] for r in load_dbt_show_json(competitions_path)
    }
    clubelo_by_country = fetch_clubelo_master_list()

    results = []
    skipped_non_european = 0
    for row in dim_club:
        country_name = comp_to_country.get(row["DOMESTIC_COMPETITION_ID"])
        country_code = COMP_TO_COUNTRY_CODE.get(country_name) if country_name else None
        if not country_code or country_code not in clubelo_by_country:
            skipped_non_european += 1
            continue

        club_name = row["CLUB_NAME"]
        if club_name in MANUAL_OVERRIDES:
            results.append((row["CLUB_ID"], club_name, MANUAL_OVERRIDES[club_name], country_code, 1.0, "manual"))
            continue

        target_toks = tokens(club_name)
        target_is_reserve = has_reserve_marker(target_toks)
        norm_target = " ".join(target_toks)

        best_score, best_candidate = -1.0, None
        for cand in clubelo_by_country[country_code]:
            cand_toks = tokens(cand)
            if target_is_reserve != has_reserve_marker(cand_toks):
                continue
            score = fuzz.token_set_ratio(norm_target, " ".join(cand_toks)) / 100.0
            if score > best_score:
                best_score, best_candidate = score, cand
        if best_candidate:
            results.append((row["CLUB_ID"], club_name, best_candidate, country_code, round(best_score, 3), "auto"))

    accepted = [r for r in results if r[4] >= ACCEPT_THRESHOLD]
    rejected = [r for r in results if r[4] < ACCEPT_THRESHOLD]

    accepted.sort(key=lambda r: int(r[0]))
    with open(MAPPING_OUTPUT_PATH, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["club_id", "club_name", "clubelo_club", "clubelo_country"])
        for club_id, club_name, clubelo_club, country_code, _score, _source in accepted:
            w.writerow([club_id, club_name, clubelo_club, country_code])

    print(f"wrote {len(accepted)} rows to {MAPPING_OUTPUT_PATH}")
    print(f"skipped (non-European, no possible match): {skipped_non_european}")
    print(f"rejected (< {ACCEPT_THRESHOLD}, review before trusting): {len(rejected)}")
    for club_id, club_name, clubelo_club, country_code, score, source in sorted(rejected, key=lambda r: -r[4]):
        print(f"  {score:.3f}  {club_name!r} -> {clubelo_club!r} ({country_code}, {source})")


if __name__ == "__main__":
    main()
