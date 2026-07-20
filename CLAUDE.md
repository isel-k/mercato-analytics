# CLAUDE.md — Mercato Analytics

## Contexte du projet

Data warehouse du mercato football : croiser transferts, valeurs marchandes et performances joueurs pour analyser la rentabilité sportive des transferts (métrique signature : **ROI transfert**).

C'est un **projet portfolio** : la qualité, la lisibilité et la documentation comptent autant que le fonctionnel. Il matérialise la transition de son auteur (9 ans de Talend/ELT) vers le modern data stack — les choix doivent refléter les best practices dbt/dlt/Airflow, pas des habitudes ETL legacy.

Le projet suit l'**Analytics Development Lifecycle (ADLC)** de dbt Labs : Plan → Develop → Test → Deploy → Operate → Observe → Discover → Analyze. Le README est structuré selon ces 8 étapes.

## Architecture

```
Sources : Kaggle Transfermarkt (davidcariboo/player-scores) · API football-data.org · FBref (lib soccerdata)
   ↓ dlt (Python, chargement incrémental)
Snowflake base RAW (schémas : raw_transfermarkt, raw_footballdata, raw_fbref)
   ↓ dbt (exécuté en local et via Cosmos dans Airflow — pas de dbt Cloud)
Snowflake base ANALYTICS (staging → intermediate → marts)
   ↓
Dashboard Evidence (GitHub Pages) · dbt MCP Server (bonus)

Orchestration : Airflow local via Astronomer (astro dev start), Cosmos pour dbt
CI/CD : GitHub Actions (sqlfluff, dbt build sur PR, déploiement DAGs)
```

## Arborescence cible

```
/
├── CLAUDE.md
├── README.md              # structuré selon l'ADLC
├── ingestion/             # pipelines dlt (un module par source)
│   ├── transfermarkt/
│   ├── footballdata/
│   └── fbref/
├── dbt/                   # projet dbt
│   └── models/
│       ├── staging/       # 1 dossier par source
│       ├── intermediate/
│       └── marts/
├── orchestration/         # DAGs Airflow (projet Astro)
│   └── dags/
├── dashboard/             # projet Evidence
└── .github/workflows/     # CI/CD
```

## Conventions dbt

- **Nommage des modèles** : `stg_<source>__<entité>` (staging), `int_<domaine>__<description>` (intermediate), `dim_<entité>` / `fct_<domaine>` (marts). Exemples : `stg_transfermarkt__players`, `int_players__identity_resolution`, `dim_player`, `fct_transfer`.
- **Un modèle staging par table source**, rôle strict : renommage, typage, dédoublonnage. Aucune jointure ni logique métier en staging.
- **Dépendances via `ref()` et `source()` uniquement** — jamais de nom de table en dur. Le DAG dérive exclusivement des `ref()`, pas de la structure des dossiers.
- **Matérialisations** : staging en `view`, intermediate en `ephemeral` ou `view`, marts en `table` (passage en `incremental` justifié par le volume, pas par défaut).
- **Tests** : chaque modèle a au minimum `unique` + `not_null` sur sa clé primaire. Tests custom pour les règles métier (montants ≥ 0, pas de joueurs orphelins). **Unit tests dbt** sur la logique du ROI transfert.
- **Sources** : déclarées avec `freshness` configuré.
- **Doc** : chaque modèle a une description dans son YAML ; colonnes clés documentées.
- **SQL style** : sqlfluff (config à la racine du projet dbt) ; CTEs nommées explicitement, `import` CTEs en tête de modèle ; mots-clés SQL en minuscules.

## Conventions dlt

- Un pipeline par source, dans son propre module sous `ingestion/`.
- **Chargement incrémental** avec `merge` sur clés naturelles (player_id, transfer_id…) dès que la source le permet ; `replace` uniquement pour les référentiels de petite taille.
- Secrets via `.dlt/secrets.toml` (jamais commité) ; `.dlt/config.toml` versionné.
- Destination Snowflake : rôle `LOADER`, base `RAW`, un schéma par source.
- Gestion des erreurs API : respect des rate limits (football-data.org : 10 req/min), retries avec backoff.

## Conventions Airflow

- 3 DAGs : `ingest_daily` (pipelines dlt), `transform` (dbt via Cosmos, déclenché après ingestion), `full_refresh_monthly`.
- Pas de logique métier dans les DAGs — ils orchestrent, c'est tout.
- Alerting sur échec configuré. Idempotence exigée : relancer un DAG ne doit jamais corrompre les données.

## Snowflake

- Rôles : `LOADER` (dlt, écrit dans RAW), `TRANSFORMER` (dbt, lit RAW, écrit ANALYTICS). Principe du moindre privilège.
- Warehouse XS par défaut ; resource monitors actifs — surveiller les coûts.
- **Schémas dbt isolés par target** : seul le target `prod` écrit dans le schéma nu
  (`staging`/`intermediate`/`marts`, celui lu par le dashboard Evidence en
  production) ; tout autre target (`dev` local, `ci`) est préfixé automatiquement
  (`dbt_marts`, `ci_marts`…) par `dbt/macros/generate_schema_name.sql`. Un `dbt run`
  local ou une CI de PR ne peut donc jamais écraser les données publiées. Voir
  [`ARCHITECTURE.md`](./ARCHITECTURE.md) décision 11.

## Git & CI

- Branches courtes, une PR par sujet ; messages de commit en anglais, format `type: description` (feat/fix/docs/refactor/test/ci).
- La CI (GitHub Actions) doit passer avant merge : sqlfluff + dbt build sur environnement de dev.
- **Demander une revue critique à Claude Code avant chaque PR** (c'est un réflexe voulu du workflow).

## Style de collaboration attendu

- L'auteur vient du monde Talend (ETL visuel) : quand une analogie Talend aide à expliquer un concept dbt/dlt/Airflow, l'utiliser — et **corriger explicitement les transpositions erronées** (ex. penser le DAG dbt en termes de dossiers plutôt que de `ref()`).
- Recommander une approche et justifier, plutôt que lister des options sans trancher.
- Privilégier les solutions simples et idiomatiques du modern stack ; signaler quand une demande reproduit un pattern legacy sans bénéfice.
- Ne jamais introduire de dépendance ou d'outil non listé ici sans le signaler et le justifier.

## Garde-fous

- **Aucun secret dans le repo** : credentials Snowflake et clés API uniquement en variables d'environnement locales / secrets GitHub Actions / `.dlt/secrets.toml` (gitignoré).
- Repo public : pas de données sous licence restrictive commitées ; les données vivent dans Snowflake, pas dans git (seuls des seeds de petite taille sont tolérés).
- Environnement de travail : ce repo n'est cloné que sur le PC personnel — jamais sur un poste client.
