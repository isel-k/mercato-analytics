# dbt

Projet dbt (staging → intermediate → marts). Voir [`CLAUDE.md`](../CLAUDE.md) pour
les conventions détaillées.

## Développement local

```bash
dbt build --project-dir .   # ou depuis dbt/ : dbt build
dbt docs generate && dbt docs serve
```

Utilise `~/.dbt/profiles.yml` (rôle `TRANSFORMER`, auth par clé RSA — voir
`../snowflake/setup.sql`). **Ne pas créer de `profiles.yml` dans ce dossier** : dbt
cherche un `profiles.yml` dans le répertoire courant avant `~/.dbt/`, donc un
fichier ici court-circuiterait silencieusement le profil local pour toute commande
lancée depuis `dbt/`. Les profils non interactifs (CI, Cosmos) vivent volontairement
ailleurs : `.github/dbt_profiles/` et `orchestration/include/dbt_profiles/`.

Le target par défaut, `dev`, écrit dans un schéma isolé (`dbt_marts`,
`dbt_intermediate`…) — jamais dans celui que lit le dashboard Evidence en
production. `dbt build`/`dbt run` en local sont donc toujours sans risque. Pour
publier un changement sur le dashboard public (tant que le DAG Airflow `transform`
n'est pas déployé pour le faire automatiquement), il faut le demander explicitement :

```bash
dbt build --target prod
```

Voir [`ARCHITECTURE.md`](../ARCHITECTURE.md) décision 11 pour le détail (le schéma
nu n'est donné qu'au target littéralement nommé `prod`, dans
`macros/generate_schema_name.sql`).

## Sources

- `raw_transfermarkt` (12 tables) et `raw_footballdata` (3 tables), déclarées avec
  `freshness` dans `models/staging/*/`.

## Marts

- `dim_player`, `dim_club`, `fct_transfer` : ROI transfert (`roi_financier`,
  `cost_per_goal_contribution`), voir description dans
  `models/marts/_marts__models.yml`.
- `dim_team`, `fct_match` : référentiel football-data.org, pas encore rapproché de
  `dim_club`/`dim_player` (pas de résolution d'identité entre les deux sources).
