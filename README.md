# Mercato Analytics

Data warehouse du mercato football : croiser transferts, valeurs marchandes et performances joueurs pour analyser la rentabilité sportive des transferts. Métrique signature : **ROI transfert**.

Projet portfolio suivant l'[Analytics Development Lifecycle (ADLC)](https://www.getdbt.com/blog/analytics-development-lifecycle) de dbt Labs. Voir [`CLAUDE.md`](./CLAUDE.md) pour les conventions détaillées du projet.

## 1. Plan

- **Question métier** : un transfert a-t-il été rentable au regard des performances sportives du joueur, comparées à son coût d'acquisition et à sa valeur marchande ?
- **Sources** :
  - [Kaggle — Transfermarkt (davidcariboo/player-scores)](https://www.kaggle.com/datasets/davidcariboo/player-scores) : transferts, valeurs marchandes, clubs, compétitions.
  - [football-data.org API](https://www.football-data.org/) : calendriers, résultats, compositions.
  - [FBref](https://fbref.com/) via la librairie [`soccerdata`](https://github.com/probberechts/soccerdata) : statistiques de performance avancées.
- **Métrique cible** : ROI transfert (à définir précisément dans un modèle dbt dédié, avec unit tests).

## 2. Develop

- **Ingestion** : pipelines [dlt](https://dlthub.com/) sous [`ingestion/`](./ingestion), un module par source, chargement incrémental (`merge`) vers Snowflake `RAW`.
- **Transformation** : projet [dbt](https://www.getdbt.com/) sous [`dbt/`](./dbt), couches staging → intermediate → marts vers Snowflake `ANALYTICS`.
- **Orchestration** : DAGs [Airflow](https://airflow.apache.org/) (via [Astronomer](https://www.astronomer.io/)) sous [`orchestration/`](./orchestration), utilisant [Cosmos](https://astronomer.github.io/astronomer-cosmos/) pour exécuter dbt.
- **Restitution** : dashboard [Evidence](https://evidence.dev/) sous [`dashboard/`](./dashboard), publié sur GitHub Pages.

## 3. Test

- Tests génériques dbt (`unique`, `not_null`) sur toutes les clés primaires.
- Tests custom pour les règles métier (montants ≥ 0, pas de joueurs orphelins).
- Unit tests dbt sur la logique de calcul du ROI transfert.
- Lint SQL avec [sqlfluff](https://sqlfluff.com/).

## 4. Deploy

- CI GitHub Actions ([`.github/workflows/`](./.github/workflows)) : sqlfluff + `dbt build` sur chaque PR (environnement de dev).
- Déploiement des DAGs Airflow après merge sur `main`.
- Projet dbt connecté à dbt Cloud pour les runs de production.

## 5. Operate

- 3 DAGs Airflow : `ingest_daily`, `transform` (déclenché après ingestion), `full_refresh_monthly`.
- Idempotence exigée sur tous les DAGs ; alerting configuré sur échec.
- Warehouse Snowflake XS par défaut, resource monitors actifs pour la maîtrise des coûts.

## 6. Observe

- Fraîcheur des sources (`freshness`) surveillée via les tests dbt de source.
- (Bonus) Observabilité exposée via le [dbt MCP Server](https://github.com/dbt-labs/dbt-mcp).

## 7. Discover

- Documentation dbt générée (descriptions de modèles, colonnes clés) et catalogue consultable.
- Lignée des modèles dérivée exclusivement des `ref()`/`source()`.

## 8. Analyze

- Dashboard Evidence : suivi du ROI transfert par joueur, club, compétition, fenêtre de mercato.

## Architecture

```
Sources : Kaggle Transfermarkt · API football-data.org · FBref (soccerdata)
   ↓ dlt (chargement incrémental)
Snowflake RAW (raw_transfermarkt, raw_footballdata, raw_fbref)
   ↓ dbt (staging → intermediate → marts)
Snowflake ANALYTICS
   ↓
Dashboard Evidence (GitHub Pages) · dbt MCP Server (bonus)

Orchestration : Airflow local via Astronomer, Cosmos pour dbt
CI/CD : GitHub Actions (sqlfluff, dbt build sur PR)
```

## Arborescence

```
/
├── CLAUDE.md
├── README.md
├── ingestion/             # pipelines dlt (un module par source)
│   ├── transfermarkt/
│   ├── footballdata/
│   └── fbref/
├── dbt/                   # projet dbt
│   └── models/
│       ├── staging/
│       ├── intermediate/
│       └── marts/
├── orchestration/         # DAGs Airflow (projet Astro)
│   └── dags/
├── dashboard/             # projet Evidence
└── .github/workflows/     # CI/CD
```

## Statut

🚧 Projet en cours de démarrage — scaffolding initial en place, implémentation à venir.
