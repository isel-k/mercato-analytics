# orchestration/dags

DAGs Airflow (projet Astro) : `ingest_daily` (pipelines dlt), `transform` (dbt via Cosmos, déclenché après ingestion), `full_refresh_monthly`.

Pas de logique métier ici — orchestration uniquement. Idempotence exigée.
