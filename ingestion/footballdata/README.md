# ingestion/footballdata

Pipeline dlt pour l'API [football-data.org](https://www.football-data.org/).

Charge vers Snowflake `RAW.raw_footballdata`. Respecte le rate limit de l'API (10 req/min) avec retries et backoff.
