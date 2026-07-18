"""Runs the dlt ingestion pipelines (Transfermarkt, football-data.org) into RAW.

No business logic here — each task just invokes the pipeline's own run()
function, which is idempotent (merge on natural keys, cf. ingestion/*/pipeline.py).
"""

import pendulum
from airflow.sdk import dag, task

from include.alerting import notify_failure
from include.assets import RAW_FOOTBALLDATA, RAW_TRANSFERMARKT


@dag(
    schedule="@daily",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    default_args={"retries": 2, "on_failure_callback": notify_failure},
    tags=["ingestion", "dlt"],
)
def ingest_daily():
    @task(outlets=[RAW_TRANSFERMARKT])
    def transfermarkt():
        from ingestion.transfermarkt.pipeline import run

        run()

    @task(outlets=[RAW_FOOTBALLDATA])
    def footballdata():
        from ingestion.footballdata.pipeline import run

        run()

    transfermarkt()
    footballdata()


ingest_daily()
