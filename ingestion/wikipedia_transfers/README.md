# ingestion/wikipedia_transfers

Pipeline dlt qui comble un vrai trou de couverture trouvé dans le snapshot Kaggle
Transfermarkt : certains grands clubs européens (Real Madrid en tête — aucun
transfert enregistré depuis juillet 2024) n'ont simplement plus de transferts
scrapés depuis 1 à 2 ans, alors que d'autres clubs continuent d'être rafraîchis
normalement. Ce n'est pas un problème de fee (`ARCHITECTURE.md` décision 12),
c'est le transfert lui-même qui manque.

## Pourquoi Wikipedia et pas transfermarkt.com directement

Le scraping direct de transfermarkt.com a été explicitement écarté : leur
`robots.txt` nomme `ClaudeBot`, `Claude-SearchBot` et `anthropic-ai` avec
`Disallow: /` — pas un blocage anti-bot générique, une interdiction ciblant
spécifiquement les crawlers IA/Claude. Wikipedia, vérifié directement, ne
mentionne aucun bot IA dans son `robots.txt`, son contenu est sous licence
CC-BY-SA pensée pour la réutilisation, et l'API MediaWiki est le moyen documenté
et voulu d'y accéder par programme — ce pipeline utilise cette API, pas du
scraping HTML brut.

## Ciblage des clubs : dynamique, pas une liste figée

`_discover_target_clubs()` interroge `analytics.marts` à chaque run (`dim_club`
+ `fct_transfer`) pour trouver les grands clubs (`current_elo >= 1700`, cf.
`ARCHITECTURE.md` décision 13) sans transfert Transfermarkt depuis plus de
~300 jours — le pipeline se remet à jour tout seul, pas de liste à maintenir à
la main. Nécessite que le rôle `LOADER` (habituellement RAW seulement) ait un
accès lecture seule à `analytics.marts` (voir `snowflake/setup.sql`).

Cas particulier géré explicitement : un club sans correspondance ClubElo (donc
`current_elo` nul) ne peut jamais franchir la barre `>= 1700`, peu importe son
ancienneté — c'est exactement le cas du Real Madrid (ses propres données
ClubElo n'ont toujours pas chargé, cause non résolue). Gardé dans
`ALWAYS_INCLUDE_CLUBS` plutôt que silencieusement perdu ; à retirer une fois le
problème ClubElo réellement corrigé.

## Ce qui est chargé

Pour chaque club ciblé, pour les 2 dernières saisons :

1. Table des transferts "In"/"Out" de la page `{saison} {club} season` — joueur,
   club d'origine/destination, date, type. Fiable, mais **pas standardisé** :
   5 conventions de nommage de colonnes différentes vérifiées sur de vraies pages
   ("From"/"To", "Transfer from/to", "Transferred from/to", "Moving from/to",
   "Loaned from/to" + "Returning from/to") — `_club_season_rows()` détecte par
   sous-chaîne plutôt que par nom exact, après avoir découvert qu'un check
   littéral "From"/"To" faisait silencieusement disparaître tous les transferts
   de 14 des 31 clubs ciblés (Barcelone, Inter, Juventus, Monaco compris).
2. Fee : certaines pages l'ont directement dans une colonne "Fee" structurée
   (utilisée en priorité, gratuite, plus fiable). Sinon, pour chaque transfert
   entrant plausiblement payant, la page du joueur lui-même est récupérée et son
   texte parcouru pour trouver un montant proche d'une mention du club de
   destination. **Best-effort, pas fiable à 100%** : vérifié sur des cas réels
   que la formulation varie énormément (montant présent pour certains transferts
   confirmés, absent même quand un montant existe ailleurs dans le même article ;
   une fourchette ("entre €6.2m et €10m") est réduite à sa borne basse, faute de
   moyen fiable de distinguer "LE montant" d'une fourchette en texte libre). Voir
   les commentaires de `extract_fee()` dans `pipeline.py` pour les cas réels
   rencontrés.

Charge vers Snowflake `RAW.raw_wikipedia_transfers` (`club_transfers`, `merge` sur
`(club_id, player_name, date, direction)`).

## Exécuter

```bash
uv run python -m ingestion.wikipedia_transfers.pipeline
```

Pas de secrets nécessaires (API publique, sans authentification). Respecte un délai
fixe entre requêtes (0.5s) — l'API MediaWiki n'a pas de limite documentée aussi
stricte que d'autres sources de ce projet, mais autant rester poli.
