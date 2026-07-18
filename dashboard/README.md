# dashboard

Projet [Evidence](https://evidence.dev/), publié sur GitHub Pages. Consomme les marts
dbt (`ANALYTICS.marts`) pour restituer le ROI transfert.

## Développement local

```bash
npm install
npm run sources   # teste la connexion Snowflake et introspecte le schéma
npm run dev       # http://localhost:3000
```

## Connexion Snowflake

- Champs non secrets : `sources/mercato_analytics/connection.yaml` (committé).
- Secrets (username, clé privée, passphrase) : `.env` (gitignoré, copier
  `.env.example`), auth par clé RSA — même clé que `.dlt/`/`orchestration/`, rôle
  `TRANSFORMER` (lecture seule sur `ANALYTICS.marts`, moindre privilège).

## Pages

- `pages/index.md` : vue d'ensemble ROI transfert — KPIs, meilleurs/pires ROI
  financiers, meilleur rapport coût/contribution sportive.
