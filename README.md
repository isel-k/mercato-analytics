# Mercato Analytics

Data warehouse du mercato football : croiser transferts, valeurs marchandes et performances joueurs pour analyser la rentabilité sportive des transferts. Métrique signature : **ROI transfert**.

Projet portfolio suivant l'[Analytics Development Lifecycle (ADLC)](https://www.getdbt.com/blog/analytics-development-lifecycle) de dbt Labs. Voir [`CLAUDE.md`](./CLAUDE.md) pour les conventions détaillées du projet, et [`ARCHITECTURE.md`](./ARCHITECTURE.md) pour le schéma complet du pipeline et le pourquoi des principales décisions techniques (auth Snowflake, orchestration, etc.).

**Dashboard live** : https://isel-k.github.io/mercato-analytics/

## 1. Plan

- **Question métier** : un transfert a-t-il été rentable au regard des performances sportives du joueur, comparées à son coût d'acquisition et à sa valeur marchande ?
- **Sources** :
  - [Kaggle — Transfermarkt (davidcariboo/player-scores)](https://www.kaggle.com/datasets/davidcariboo/player-scores) : transferts, valeurs marchandes, clubs, compétitions.
  - [football-data.org API](https://www.football-data.org/) : calendriers, résultats, compositions.
  - [FBref](https://fbref.com/) via la librairie [`soccerdata`](https://github.com/probberechts/soccerdata) : statistiques de performance avancées. **Bloqué** — FBref sert un challenge Cloudflare interactif à toute requête automatisée (voir [`ingestion/fbref/README.md`](./ingestion/fbref/README.md)).
- **Métrique cible** : ROI transfert, définie dans `fct_transfer` (voir
  [`dbt/models/marts/_marts__models.yml`](./dbt/models/marts/_marts__models.yml)) en
  deux indicateurs séparés — `roi_financier` (plus-value de valeur marchande / coût
  d'acquisition) et `cost_per_goal_contribution` (coût / buts+passes) — couverts par
  3 unit tests dbt.

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

- CI GitHub Actions ([`.github/workflows/ci.yml`](./.github/workflows/ci.yml)) : sqlfluff + `dbt build --target ci` sur chaque PR, dans un schéma Snowflake isolé (`ci_marts`…) — jamais celui lu par le dashboard en production. Même isolation pour tout `dbt run` local (target `dev`) ; seul le target `prod` écrit dans le schéma public. Voir [`ARCHITECTURE.md`](./ARCHITECTURE.md) décision 11.
- Dashboard Evidence : [`deploy-dashboard.yml`](./.github/workflows/deploy-dashboard.yml) publie sur GitHub Pages à chaque push sur `main` touchant `dashboard/`.
- dbt orchestré via [Cosmos](https://astronomer.github.io/astronomer-cosmos/) dans Airflow (pas de dbt Cloud) — voir [2. Develop](#2-develop).
- DAGs Airflow : tournent en local (`astro dev start`) pour l'instant. Déploiement
  production sur Astronomer Cloud pas encore fait (nécessite un compte).

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

Schéma complet + décisions de conception : [`ARCHITECTURE.md`](./ARCHITECTURE.md).

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

- Ingestion : pipelines dlt `transfermarkt` et `footballdata` opérationnels, auth par
  clé sur un user Snowflake `SERVICE` dédié (`PIPELINE_SVC`, pas le compte personnel).
  `fbref` **bloqué** — FBref sert un challenge Cloudflare interactif à toute requête
  automatisée (voir [`ingestion/fbref/README.md`](./ingestion/fbref/README.md)).
- Transformation : staging complet sur `transfermarkt` (12 modèles) et `footballdata`
  (3 modèles) ; marts `fct_transfer` (ROI transfert : `roi_financier`,
  `cost_per_goal_contribution`) et `dim_team`/`fct_match` (football-data.org).
  Testé (unit tests + tests génériques dbt), documenté (`dbt docs generate`).
- Orchestration : 3 DAGs Airflow (Astronomer + Cosmos) — `ingest_daily`, `transform`,
  `full_refresh_monthly` — avec alerting sur échec, validés en local
  (`astro dev start`).
- Restitution : dashboard Evidence (`pages/index.md`) sur `fct_transfer`.
- CI : `.github/workflows/ci.yml` (sqlfluff + `dbt build --target ci`) et
  `deploy-dashboard.yml` (build + publie sur GitHub Pages) sont en place et
  passent réellement sur GitHub Actions, secrets `SNOWFLAKE_*` (valeurs de
  `PIPELINE_SVC`) configurés côté repo.
- Déploiement Airflow (Astronomer Cloud) : pas fait — nécessite un compte
  Astronomer (payant au-delà du trial) et un `astro deployment create` que je ne
  peux pas faire à ta place. Reste en local (`astro dev start`) pour l'instant.
- Reste à faire, plus mineur : résolution d'identité club/joueur entre Transfermarkt
  et football-data.org (aucun rapprochement pour l'instant, deux référentiels
  parallèles), dbt MCP Server (bonus), pages Evidence par club/compétition.
