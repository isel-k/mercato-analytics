# dbt/models/intermediate

Logique métier intermédiaire, réutilisable entre marts (ex. résolution d'identité joueur entre sources).

Convention de nommage : `int_<domaine>__<description>` (ex. `int_players__identity_resolution`). Matérialisation : `ephemeral` ou `view`.
