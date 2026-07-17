"""dlt pipeline: Kaggle Transfermarkt dataset -> Snowflake RAW.raw_transfermarkt.

Source: https://www.kaggle.com/datasets/davidcariboo/player-scores (CC0, updated weekly).
The dataset ships as one CSV per table; there is no incremental API, so "incremental
loading" here means merging each weekly snapshot on natural keys rather than appending
raw files — updates and new rows land without duplicating history.

Primary keys below are derived from the dataset's own published schema, not guessed:
https://github.com/dcaribou/transfermarkt-datasets/blob/master/data/prep/dataset-metadata.json
"""

import kagglehub
import dlt
from dlt.sources.filesystem import filesystem, read_csv

KAGGLE_DATASET = "davidcariboo/player-scores"

PRIMARY_KEYS = {
    "competitions": ["competition_id"],
    "countries": ["country_id"],
    "national_teams": ["national_team_id"],
    "clubs": ["club_id"],
    "players": ["player_id"],
    "games": ["game_id"],
    "club_games": ["club_id", "game_id"],
    "appearances": ["appearance_id"],
    "game_events": ["game_event_id"],
    "game_lineups": ["game_lineups_id"],
    "player_valuations": ["player_id", "date"],
    "transfers": ["player_id", "transfer_date", "from_club_id", "to_club_id"],
}


@dlt.source(name="transfermarkt")
def transfermarkt_source(dataset_path: str):
    for table_name, primary_key in PRIMARY_KEYS.items():
        files = filesystem(bucket_url=dataset_path, file_glob=f"{table_name}.csv")
        resource = (files | read_csv()).with_name(table_name)
        resource.apply_hints(write_disposition="merge", primary_key=primary_key)
        yield resource


def run() -> None:
    dataset_path = kagglehub.dataset_download(KAGGLE_DATASET)
    pipeline = dlt.pipeline(
        pipeline_name="transfermarkt",
        destination="snowflake",
        dataset_name="raw_transfermarkt",
    )
    load_info = pipeline.run(transfermarkt_source(dataset_path))
    print(load_info)


if __name__ == "__main__":
    run()
