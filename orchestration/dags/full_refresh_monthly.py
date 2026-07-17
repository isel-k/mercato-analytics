"""Monthly full refresh: dbt build --full-refresh via Cosmos.

Not needed by any current model (none are incremental yet), but kept ready
for when a mart is switched to incremental — running it monthly rebuilds
history from scratch to catch any drift.
"""

from pathlib import Path

from cosmos import DbtDag, ExecutionConfig, ProfileConfig, ProjectConfig
from pendulum import datetime

DBT_PROJECT_DIR = Path("/usr/local/airflow/dbt")
DBT_PROFILES_DIR = Path("/usr/local/airflow/include/dbt_profiles")

full_refresh_monthly = DbtDag(
    dag_id="full_refresh_monthly",
    schedule="@monthly",
    start_date=datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    default_args={"retries": 2},
    tags=["transform", "dbt", "full-refresh"],
    project_config=ProjectConfig(dbt_project_path=DBT_PROJECT_DIR),
    profile_config=ProfileConfig(
        profile_name="mercato_analytics",
        target_name="dev",
        profiles_yml_filepath=DBT_PROFILES_DIR / "profiles.yml",
    ),
    execution_config=ExecutionConfig(dbt_executable_path="/usr/local/bin/dbt"),
    operator_args={"full_refresh": True},
)
