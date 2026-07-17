# ingestion/fbref

Pipeline dlt pour [FBref](https://fbref.com/), via la librairie [`soccerdata`](https://github.com/probberechts/soccerdata).

Charge vers Snowflake `RAW.raw_fbref`.

## Statut : bloqué (2026-07-17)

FBref sert un challenge Cloudflare interactif (Turnstile, `cf-mitigated: challenge`)
sur toutes les requêtes automatisées, y compris via `cloudscraper` (déjà utilisé en
interne par `soccerdata`) et un User-Agent de navigateur. Ce n'est pas un problème de
réseau/IP local (vérifié : IP résidentielle, pas un range datacenter) — c'est un vrai
blocage anti-bot actif côté FBref.

Le contourner nécessiterait un navigateur headless capable de résoudre le challenge,
ce qui reviendrait à contourner délibérément une protection anti-scraping active — les
CGU de Sports Reference/FBref interdisent explicitement le scraping automatisé.
Décision : abandon de cette source pour l'instant plutôt que de chercher à forcer le
passage. À retester si `soccerdata` ou les protections FBref évoluent, ou à remplacer
par une autre source de stats avancées (xG/xA) si besoin.
