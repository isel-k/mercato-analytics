# dbt/models/marts

Modèles finaux consommés par le dashboard : dimensions et faits.

Convention de nommage : `dim_<entité>` / `fct_<domaine>` (ex. `dim_player`, `fct_transfer`). Matérialisation : `table` par défaut (`incremental` si justifié par le volume).
