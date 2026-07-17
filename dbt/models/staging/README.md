# dbt/models/staging

Un dossier par source. Rôle strict : renommage, typage, dédoublonnage — aucune jointure ni logique métier.

Convention de nommage : `stg_<source>__<entité>` (ex. `stg_transfermarkt__players`). Matérialisation : `view`.
