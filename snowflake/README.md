# snowflake

Dossier absent de l'arborescence cible initiale du CLAUDE.md — ajouté pour versionner le bootstrap Snowflake (rôles, warehouse, resource monitor) plutôt que de le documenter uniquement en prose. Pas de nouvel outil, juste du SQL de setup.

## `setup.sql`

A exécuter **une seule fois**, en tant qu'`ACCOUNTADMIN`, dans un worksheet Snowsight :

1. Remplace `<YOUR_USER>` par ton nom d'utilisateur Snowflake (visible en haut à droite dans Snowsight) en bas du script.
2. Colle tout le script dans un worksheet et exécute-le (Run All).
3. Une fois fait, note ton **account identifier** (dans l'URL Snowsight, ex. `abcd-xy12345`) : c'est le `host` à renseigner dans `.dlt/secrets.toml` et dans le profil dbt.

Crée : warehouse `MERCATO_WH` (XS, auto-suspend 60s), un resource monitor à 10 crédits/mois, les bases `RAW`/`ANALYTICS`, les schémas `raw_transfermarkt`/`raw_footballdata`/`raw_fbref`, et les rôles `LOADER`/`TRANSFORMER` avec le principe du moindre privilège.
