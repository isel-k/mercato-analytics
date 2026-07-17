# ingestion/transfermarkt

Pipeline dlt pour la source Kaggle Transfermarkt (`davidcariboo/player-scores`).

Charge vers Snowflake `RAW.raw_transfermarkt`, en `merge` incrémental sur les clés naturelles de chaque table (voir `PRIMARY_KEYS` dans `pipeline.py`, dérivées du schéma publié par le dataset).

## Prérequis

- **Identifiants Kaggle** : le téléchargement passe par [`kagglehub`](https://github.com/Kagglehub/kagglehub) (dépendance ajoutée en plus de la liste du CLAUDE.md — nécessaire pour accéder à l'API Kaggle, pas d'alternative plus légère). Authentification via `~/.kaggle/kaggle.json` (format standard du CLI Kaggle) **ou** les variables d'environnement `KAGGLE_USERNAME` / `KAGGLE_KEY`.
- **Identifiants Snowflake** : copier `.dlt/secrets.toml.example` vers `.dlt/secrets.toml` (gitignoré) et renseigner les valeurs réelles (rôle `LOADER`).

## Exécuter

```bash
uv run python -m ingestion.transfermarkt.pipeline
```

