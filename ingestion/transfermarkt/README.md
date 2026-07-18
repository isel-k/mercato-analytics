# ingestion/transfermarkt

Pipeline dlt pour la source Kaggle Transfermarkt (`davidcariboo/player-scores`).

Charge vers Snowflake `RAW.raw_transfermarkt`, en `merge` incrémental sur les clés naturelles de chaque table (voir `PRIMARY_KEYS` dans `pipeline.py`, dérivées du schéma publié par le dataset).

## Prérequis

- **Identifiants Kaggle** : le téléchargement passe par [`kagglehub`](https://github.com/Kagglehub/kagglehub) (dépendance ajoutée en plus de la liste du CLAUDE.md — nécessaire pour accéder à l'API Kaggle, pas d'alternative plus légère). Kaggle a remplacé son ancien système de clé (`kaggle.json`) par un token bearer :
  génère-le sur [kaggle.com/settings](https://www.kaggle.com/settings) → *API* → *Create New Token*, puis :
  ```bash
  mkdir -p ~/.kaggle && echo "<ton_token>" > ~/.kaggle/access_token && chmod 600 ~/.kaggle/access_token
  ```
  (ou variable d'environnement `KAGGLE_API_TOKEN`, utile pour Airflow — voir `orchestration/.env.example`).
- **Identifiants Snowflake** : copier `.dlt/secrets.toml.example` vers `.dlt/secrets.toml` (gitignoré) et renseigner les valeurs réelles — utilisateur `PIPELINE_SVC` (voir [`snowflake/README.md`](../../snowflake/README.md)), rôle `LOADER`, auth par clé RSA.

## Exécuter

```bash
uv run python -m ingestion.transfermarkt.pipeline
```

