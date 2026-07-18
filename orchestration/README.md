# orchestration

Projet [Astronomer](https://www.astronomer.io/) (Airflow 3, local via `astro dev start`).

## DAGs

- **`ingest_daily`** : lance les pipelines dlt (`transfermarkt`, `footballdata`) en
  important directement `ingestion.<source>.pipeline.run()`. Chaque tâche déclare un
  `Asset` en outlet (`include/assets.py`) pour déclencher `transform` une fois les deux
  chargements terminés.
- **`transform`** : `dbt build` via [Cosmos](https://astronomer.github.io/astronomer-cosmos/),
  déclenché par les `Asset` d'`ingest_daily`. Le graphe de tâches est dérivé
  automatiquement du projet dbt (`../dbt`, monté dans le conteneur) — aucune logique
  métier ici.
- **`full_refresh_monthly`** : mêmes modèles dbt en `--full-refresh`, mensuel. Sert
  surtout le jour où un modèle passe en matérialisation `incremental`.

## Secrets

Tout passe par variables d'environnement dans `orchestration/.env` (gitignoré, jamais
committé) — aucun fichier secret n'est monté dans les conteneurs :
- `DESTINATION__SNOWFLAKE__CREDENTIALS__*` et `SOURCES__FOOTBALLDATA__API_TOKEN` pour
  les pipelines dlt (convention native dlt de résolution de config par env var).
- `KAGGLE_API_TOKEN` pour `kagglehub`.
- `SNOWFLAKE_*` pour `include/dbt_profiles/profiles.yml` (profil dbt dédié à
  l'orchestration, distinct de `~/.dbt/profiles.yml` utilisé en local — ce fichier ne
  contient que des références `env_var()`, aucun secret, donc committé sans risque).

Le rôle Snowflake utilisé diffère selon la tâche : `LOADER` pour les pipelines dlt,
`TRANSFORMER` pour dbt/Cosmos — même principe de moindre privilège que le reste du
projet.

## Alerting

Chaque DAG a `on_failure_callback=notify_failure` (`include/alerting.py`) : toute
tâche en échec logue un message `[ALERT]` structuré (visible dans l'UI Airflow, sans
config supplémentaire). Pour aussi recevoir une notification Slack, ajoute
`SLACK_WEBHOOK_URL=https://hooks.slack.com/...` dans `.env` — rien à changer côté
code, c'est le seul interrupteur.

## Code monté dans les conteneurs

`docker-compose.override.yml` monte `../ingestion` et `../dbt` (le code, jamais les
secrets) dans `scheduler`/`dag-processor`/`api-server`/`triggerer`, pour que les DAGs
puissent importer les pipelines dlt et que Cosmos trouve le projet dbt.
