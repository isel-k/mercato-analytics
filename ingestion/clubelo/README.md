# ingestion/clubelo

Pipeline dlt pour [ClubElo](http://clubelo.com/) — ratings de force Elo des clubs
européens, mis à jour en continu depuis 1939.

Charge vers Snowflake `RAW.raw_clubelo` (`discovered_clubs` en `replace`, `ratings`
en `merge` sur `(club, country, from_date)`). Aucune authentification requise ; pas
de rate limit documenté, mais un délai fixe entre requêtes est appliqué par respect
pour une API gratuite maintenue par une seule personne.

## Pourquoi cette source

Aucune des sources existantes (Transfermarkt, football-data.org) ne donne de mesure
de force sportive des clubs — impossible aujourd'hui de dire si un transfert est une
montée ou une descente en niveau. ClubElo comble ce manque avec un historique
quotidien, gratuit, sans clé.

**Limite connue** : ClubElo ne couvre que le football européen — aucun club
d'Amérique du Sud, d'Amérique du Nord (MLS), d'Asie ou du Moyen-Orient. Le mapping
`dbt/seeds/clubelo_club_mapping.csv` (jointure `dim_club.club_id` ↔ nom ClubElo,
résolue par correspondance approximative puis vérifiée manuellement pour les cas
ambigus) ne couvre donc qu'environ 70% des clubs de `dim_club`, tous européens — voir
`ARCHITECTURE.md` pour le détail de la méthode et ses limites.

## Exécuter

```bash
uv run python -m ingestion.clubelo.pipeline
```

Deux étapes internes à chaque run : découverte des clubs suivis par ClubElo depuis
1996 (un snapshot par an, ~30 requêtes), puis récupération de l'historique complet
de chacun (~1700 requêtes — la majorité des clubs découverts n'ont pas de
correspondance dans `dim_club` et ne seront jamais utilisés en aval, mais dlt charge
la donnée source telle quelle ; c'est `dbt/seeds/clubelo_club_mapping.csv` qui fait
le tri côté transformation).
