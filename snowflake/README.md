# snowflake

Dossier absent de l'arborescence cible initiale du CLAUDE.md — ajouté pour versionner le bootstrap Snowflake (rôles, warehouse, resource monitor) plutôt que de le documenter uniquement en prose. Pas de nouvel outil, juste du SQL de setup.

## `setup.sql`

A exécuter **une seule fois**, en tant qu'`ACCOUNTADMIN`, dans un worksheet Snowsight :

1. Génère une paire de clés RSA localement (voir commentaire dans le script juste
   avant `create user pipeline_svc`) et remplace `<RSA_PUBLIC_KEY_BODY>` par la clé
   publique générée.
2. Colle tout le script dans un worksheet et exécute-le (Run All).
3. Note ton **account identifier** (dans l'URL Snowsight, ex. `abcd-xy12345`) : c'est
   le `host` à renseigner dans `.dlt/secrets.toml` et dans les profils dbt.

Crée : warehouse `MERCATO_WH` (XS, auto-suspend 60s), un resource monitor à 10
crédits/mois, les bases `RAW`/`ANALYTICS`, les schémas
`raw_transfermarkt`/`raw_footballdata`/`raw_fbref`, les rôles `LOADER`/`TRANSFORMER`
avec le principe du moindre privilège, et un utilisateur **SERVICE** dédié
(`PIPELINE_SVC`, auth par clé uniquement — pas de mot de passe possible) qui porte
les deux rôles. Tous les pipelines (dlt, dbt, Airflow, Evidence) s'authentifient en
tant que `PIPELINE_SVC`, jamais en tant que ton compte personnel — voir
[`ARCHITECTURE.md`](../ARCHITECTURE.md) pour le pourquoi (finding Snowflake Trust
Center sur l'auth password-only des comptes PERSON).
