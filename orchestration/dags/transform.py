"""Runs dbt build (staging -> intermediate -> marts) via Cosmos.

Triggered by ingest_daily completing (Asset-based scheduling below) — no
business logic here, Cosmos derives the task graph straight from the dbt
project's ref()/source() lineage.
"""

from pathlib import Path

from cosmos import DbtDag, ExecutionConfig, ProfileConfig, ProjectConfig

from include.alerting import notify_failure
from include.assets import RAW_FOOTBALLDATA, RAW_TRANSFERMARKT

DBT_PROJECT_DIR = Path("/usr/local/airflow/dbt")
DBT_PROFILES_DIR = Path("/usr/local/airflow/include/dbt_profiles")

transform = DbtDag(
    dag_id="transform",
    schedule=[RAW_TRANSFERMARKT, RAW_FOOTBALLDATA],
    catchup=False,
    default_args={"retries": 2, "on_failure_callback": notify_failure},
    tags=["transform", "dbt"],
    project_config=ProjectConfig(dbt_project_path=DBT_PROJECT_DIR),
    profile_config=ProfileConfig(
        profile_name="mercato_analytics",
        target_name="dev",
        profiles_yml_filepath=DBT_PROFILES_DIR / "profiles.yml",
    ),
    execution_config=ExecutionConfig(dbt_executable_path="/usr/local/bin/dbt"),
    operator_args={"install_deps": True},
)
