# ingestion/footballdata

Pipeline dlt pour l'API [football-data.org](https://www.football-data.org/).

Charge vers Snowflake `RAW.raw_footballdata` (competitions en `replace`, teams et
matches en `merge`). Respecte le rate limit de l'API (10 req/min, tier gratuit) avec
un délai fixe entre appels ; retries/backoff gérés par `dlt.sources.helpers.requests`.

## Prérequis

- **Token API** : inscription gratuite sur
  [football-data.org/client/register](https://www.football-data.org/client/register),
  puis renseigner `.dlt/secrets.toml` :
  ```toml
  [sources.footballdata]
  api_token = "<ton_token>"
  ```
- **Identifiants Snowflake** : utilisateur `PIPELINE_SVC` (voir
  [`snowflake/README.md`](../../snowflake/README.md)), rôle `LOADER`.
- Tier gratuit = accès restreint à un sous-ensemble de compétitions (voir
  `COMPETITION_CODES` dans `pipeline.py` : les 5 grands championnats + la Ligue des
  champions) et à la saison courante pour la plupart des endpoints.

## Exécuter

```bash
uv run python -m ingestion.footballdata.pipeline
```
