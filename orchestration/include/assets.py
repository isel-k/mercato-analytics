"""Shared Asset definitions for cross-DAG (data-aware) scheduling.

Lives under include/, not dags/, so importing it never re-triggers DAG
registration as a side effect (unlike importing a dags/*.py module directly).
"""

from airflow.sdk import Asset

RAW_TRANSFERMARKT = Asset("snowflake://raw/raw_transfermarkt")
RAW_FOOTBALLDATA = Asset("snowflake://raw/raw_footballdata")
