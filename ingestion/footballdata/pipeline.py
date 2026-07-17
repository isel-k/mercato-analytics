"""dlt pipeline: football-data.org API -> Snowflake RAW.raw_footballdata.

Source: https://www.football-data.org/ (free tier: 10 req/min, restricted to a
subset of competitions and to the current season for most endpoints).

Complements the Transfermarkt Kaggle snapshot (updated weekly) with near
real-time competitions/matches/teams data via a live REST API.
"""

import time

import dlt
from dlt.sources.helpers import requests

BASE_URL = "https://api.football-data.org/v4"

# Competitions available on the free tier (top 5 leagues + Champions League).
COMPETITION_CODES = ["PL", "PD", "SA", "BL1", "FL1", "CL"]

# Free tier limit is 10 requests/minute; stay comfortably under it.
SECONDS_BETWEEN_REQUESTS = 7


def _get(path: str, api_token: str) -> dict:
    response = requests.get(
        f"{BASE_URL}/{path}",
        headers={"X-Auth-Token": api_token},
    )
    response.raise_for_status()
    time.sleep(SECONDS_BETWEEN_REQUESTS)
    return response.json()


@dlt.source(name="footballdata")
def footballdata_source(api_token: str = dlt.secrets.value):
    @dlt.resource(name="competitions", write_disposition="replace", primary_key="id")
    def competitions():
        yield _get("competitions", api_token)["competitions"]

    @dlt.resource(name="teams", write_disposition="merge", primary_key="id")
    def teams():
        for code in COMPETITION_CODES:
            yield _get(f"competitions/{code}/teams", api_token)["teams"]

    @dlt.resource(name="matches", write_disposition="merge", primary_key="id")
    def matches():
        for code in COMPETITION_CODES:
            yield _get(f"competitions/{code}/matches", api_token)["matches"]

    return competitions, teams, matches


def run() -> None:
    pipeline = dlt.pipeline(
        pipeline_name="footballdata",
        destination="snowflake",
        dataset_name="raw_footballdata",
    )
    load_info = pipeline.run(footballdata_source())
    print(load_info)


if __name__ == "__main__":
    run()
