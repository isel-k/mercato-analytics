# Architecture

This document explains how Mercato Analytics fits together and, more importantly,
*why* it's built this way — the design decisions below came out of real constraints
hit while building the project, not upfront theorizing. For conventions and
day-to-day commands, see [`CLAUDE.md`](./CLAUDE.md) and each module's own README.

## System overview

```mermaid
flowchart LR
    subgraph SRC["Sources"]
        direction TB
        KG["Kaggle<br/>Transfermarkt"]
        FD["football-data.org<br/>API"]
    end

    subgraph ING["dlt — ingestion/"]
        direction TB
        P1["transfermarkt<br/>pipeline"]
        P2["footballdata<br/>pipeline"]
    end

    subgraph RAW["Snowflake · RAW<br/>role: LOADER"]
        direction TB
        R1[("raw_transfermarkt<br/>12 tables")]
        R2[("raw_footballdata<br/>3 tables")]
    end

    subgraph DBT["dbt — dbt/"]
        direction TB
        STG["staging<br/>15 models"]
        INT["intermediate<br/>3 models"]
        MRT["marts<br/>dim_player · dim_club · fct_transfer<br/>dim_team · fct_match"]
        STG --> INT --> MRT
    end

    subgraph AN["Snowflake · ANALYTICS<br/>role: TRANSFORMER"]
        MRT2[("staging / intermediate / marts")]
    end

    subgraph VIZ["Evidence — dashboard/"]
        DASH["pages/index.md<br/>Transfer ROI"]
    end

    KG --> P1 --> R1 --> STG
    FD --> P2 --> R2 --> STG
    MRT --> MRT2
    MRT2 --> DASH --> PG["GitHub Pages"]
```

Both `PIPELINE_SVC` roles (`LOADER`, `TRANSFORMER`) are the same Snowflake
**SERVICE** user — least privilege is enforced by which role is active on a given
connection, not by which user connects (see decision 2 below).

## Orchestration

Three Airflow DAGs (Astronomer, `orchestration/dags/`), scheduled with
[Asset](https://airflow.apache.org/docs/apache-airflow/stable/authoring-and-scheduling/assets.html)-based
data-awareness rather than fixed times chained together:

```mermaid
flowchart LR
    A["ingest_daily<br/>(dlt, @daily)"] -->|Asset: raw_transfermarkt<br/>Asset: raw_footballdata| B["transform<br/>(dbt via Cosmos)"]
    C["full_refresh_monthly<br/>(dbt --full-refresh, @monthly)"]
```

`transform`'s task graph is generated entirely from the dbt project's
`ref()`/`source()` lineage by Cosmos — no hand-written task ordering.
`full_refresh_monthly` exists for when a mart eventually goes `incremental`; nothing
currently needs it.

## CI/CD

- **`.github/workflows/ci.yml`** — on every PR: `sqlfluff lint` then `dbt build
  --target ci`, both against live Snowflake (as `PIPELINE_SVC`).
- **`.github/workflows/deploy-dashboard.yml`** — on push to `main` touching
  `dashboard/**`: rebuilds the Evidence site against live data and publishes to
  GitHub Pages.

## Key design decisions

### 1. ROI transfert: separate indicators, not one score

`fct_transfer` exposes `roi_financier` (market-value gain during the spell,
relative to the fee paid), `value_gained_absolute` (the same gain in euros,
unconditional on fee), and `cost_per_goal_contribution` (fee paid relative to
goals + assists) as **separate columns**, not blended into one weighted score.

**Why:** merging money and sporting performance into a single number needs an
arbitrary weighting scheme (why 60/40 and not 50/50?) that's hard to justify and
impossible to unit-test meaningfully. Independent numbers stay individually
interpretable, and each has a precise, testable formula — see the dbt unit tests
in `dbt/models/marts/_marts__unit_tests.yml`.

`value_gained_absolute` exists because `roi_financier` is a *ratio*, and a ratio
is undefined at zero cost — it was silently excluding every confirmed free
transfer (fee = €0) from any financial view, real "great free transfer" stories
included (Toni Kroos to Bayern Munich, Jan Vertonghen to Ajax). The
transfermarkt-datasets source docs are explicit that `transfer_fee` is "null if
unknown, 0 if free transfer" — 0 is a real, confirmed signal, not missing data,
and treating it like null just because a ratio can't be built from it was
throwing away real signal. `value_gained_absolute` is a subtraction, not a ratio,
so it stays defined at fee = 0; see the dashboard's *Best free transfers* section.

### 2. Snowflake auth: key-pair + a dedicated SERVICE user

Every pipeline (dlt, dbt, Airflow, Evidence) authenticates as `PIPELINE_SVC`
(`TYPE = SERVICE`, RSA key only — Snowflake doesn't allow a password on a SERVICE
user at all), never as the personal account.

**Why:** the Snowflake trial enforces MFA on password logins, which blocks
password-based automation outright. Key-pair auth was the fix — but it was
initially attached to the personal person account, which Snowflake's own Trust
Center later flagged as a "person user, password-only auth" risk (the real
problem: mixing a human identity with an automation identity). A dedicated SERVICE
user is Snowflake's documented pattern for exactly this, and structurally can't
regress into password auth. See `snowflake/setup.sql`.

### 3. dbt orchestrated via Cosmos-in-Airflow, not dbt Cloud

dbt runs locally (interactive dev) and via
[Cosmos](https://astronomer.github.io/astronomer-cosmos/) inside self-hosted
Airflow — no dbt Cloud account.

**Why:** portfolio scope. dbt Cloud is a fine choice generally, but adding a second
managed SaaS here wouldn't demonstrate anything Cosmos doesn't already cover, and
building the Cosmos integration directly is more instructive for a project meant to
show modern-data-stack orchestration, not just consume it.

### 4. Freshness on dlt sources without a `loaded_at` column

Every source's freshness check uses
`loaded_at_field: to_timestamp_ntz(_dlt_load_id::number(38,0))` instead of a
dedicated timestamp column.

**Why:** dlt stores its internal load id as a stringified Unix epoch
(`_dlt_load_id`), not a human timestamp column, and none of the source tables carry
their own `loaded_at`. Casting the load id directly gives correct freshness checks
without adding a redundant column anywhere. See any `_*__sources.yml` under
`dbt/models/staging/`.

### 5. No identity resolution between Transfermarkt and football-data.org

`dim_club` (Transfermarkt) and `dim_team` (football-data.org) are two separate,
unlinked referentials for what are sometimes the same real-world clubs.

**Why:** fuzzy-matching club (and eventually player) names across sources
correctly is a project of its own — normalizing "Bayern Munich" vs "FC Bayern
München" vs "Bayern München" reliably needs real work, and a half-done match would
silently corrupt joins rather than just being absent. Neither source blocks the
other for the current ROI use case, so this is deliberately deferred rather than
rushed.

### 6. FBref abandoned

There's no `ingestion/fbref/pipeline.py`, despite FBref being in the original
source list.

**Why:** FBref serves an interactive Cloudflare challenge (Turnstile) to every
automated request — confirmed independent of network/IP (tested from a residential
IP, not a datacenter range). Defeating it would mean deliberately circumventing an
active anti-bot measure on a site whose terms of service explicitly forbid
scraping. See `ingestion/fbref/README.md`.

### 7. Evidence: extract-then-cache, and a base-path gotcha

Each mart table the dashboard uses needs its own extraction file
(`dashboard/sources/mercato_analytics/<table>.sql`, e.g. `select * from
fct_transfer`). `npm run sources`/`build` runs these against live Snowflake and
caches the result as local parquet; **page queries run against that cache**, not
Snowflake directly at page-load time. Separately, `dashboard/evidence.config.yaml`
sets `deployment.basePath: /mercato-analytics`.

**Why:** this is simply how Evidence works (extract at build time, query the cache
client-side via DuckDB-wasm) — but it's not obvious from a page's markdown alone,
and skipping either piece fails silently and confusingly: no extraction file means
every page query 404s against an empty local DuckDB catalog; no base path means
GitHub Pages (which serves the site under `/mercato-analytics/`, not the domain
root) loads an unstyled page stuck on "Loading..." because every asset URL is
missing its prefix. Both were hit for real, not anticipated in advance.

The base-path fix has its own sharp edge: it works by a preprocessor doing a naive
text regex over every `href=`/`src=` in a page's raw markdown, *before* Svelte
evaluates any `{expression}` — so a hand-written `<img src={someUrl}>` gets its
literal, unevaluated `{someUrl}` text prefixed with `/mercato-analytics/`, breaking
even fully-external URLs at runtime (`/mercato-analytics/https://...`). Evidence's
own `<Image url={someUrl}>` component sidesteps this because `url` isn't a name the
regex matches, and its internal `<img src>` lives inside a compiled `.svelte` file
the preprocessor never touches (it only runs on `+page.md`). Rule of thumb: use
`<Image>` for any dynamic/external image in a page, never a raw `<img src>`.

### 9. Club crests derived from `club_id`, no new source needed

`dim_club.crest_url` is `https://tmssl.akamaized.net/images/wappen/tiny/{club_id}.png`
— Transfermarkt's own crest CDN, keyed directly by the `club_id` already in every
transfermarkt table.

**Why:** there's no crest/logo field anywhere in the Kaggle dataset's tables, and
resolving club identity against football-data.org's `dim_team` (which does have a
`crest` field) would mean doing the cross-source identity resolution decision 5
explicitly avoids. The CDN pattern is undocumented but stable and public — verified
against real `club_id`s (Sevilla FC, PSG) before relying on it, same bar as any
other external dependency here.

### 10. Commercial value is out of scope, on purpose

`fct_transfer` has no column for shirt sales, sponsorship, or social-media reach —
a player's commercial pull is a real part of why some transfers happen, but it
isn't in this model at all.

**Why:** none of this project's sources publish player-level commercial figures
(Transfermarkt and football-data.org are both sporting/transfer data). The
platforms that do model this — FootballTransfers/SciSports (ETV), CIES Football
Observatory — are enterprise or paid-subscription only, no self-serve API, checked
directly before ruling them out rather than assumed. Inventing a proxy metric with
no real data behind it would be worse than being explicit about the gap, so the
dashboard says so in its intro rather than pretending `roi_financier` is a complete
picture.

### 8. Each CI job needs its own `dbt deps`

Both the `sqlfluff` and `dbt-build` jobs in `ci.yml` run `dbt deps`, even though
that looks redundant.

**Why:** each GitHub Actions job runs on its own fresh runner — packages
(`dbt_utils`) installed in one job's `dbt_packages/` don't exist in the other's.
Found by actually running the pipeline in a real PR (`dbt build` failed with "dbt
expects 1 package(s) ... found only 0"), not by inspection.

### 11. `dbt` schema isolation is enforced by target name, not convention

`dbt/macros/generate_schema_name.sql` only gives a model the bare
staging/intermediate/marts schema when `target.name == 'prod'`. Every other target
(local `dev`, CI's `ci`) gets its models built into a target-prefixed schema instead
(`dbt_marts`, `ci_marts`, ...). Local `~/.dbt/profiles.yml` defaults to `dev`;
`.github/dbt_profiles/profiles.yml` is pinned to `ci`; `orchestration/include/dbt_profiles/profiles.yml`
(used by Cosmos/Airflow) is pinned to `prod`, since the scheduled `transform` DAG is
the intended long-term owner of the production schema.

**Why:** found by inspection that local `dev` runs, CI's `dbt build` (on every PR,
before merge), and the Airflow profile were all writing into the exact same
`ANALYTICS.marts` schema the live Evidence dashboard reads from — there was no
environment separation at all, despite `CLAUDE.md` already stating CI should run
"on a dev environment." A bad local `dbt run` or an untrusted PR's CI check could
silently overwrite what the public dashboard shows. Until the Airflow `transform`
DAG is actually deployed to Astronomer, publishing a dbt change to production is a
deliberate `dbt build --target prod` run — not automatic. This matches how most
teams keep CI/dev from touching prod without owning a second Snowflake account or
database: same warehouse and role, isolated by schema and by which target name is
allowed to resolve to the bare schema.

### 12. `transfer_fee` is structurally sparse — not a freshness problem

Checked directly against the underlying Kaggle CSV rather than assumed: even fully
concluded seasons only have a fee on a small minority of transfers (25/26: 4.7%,
24/25: 5.9%, 23/24: 6.3%) — most transfers in this dataset are recorded with no fee
at all, permanently, not just while a deal is pending. The dashboard's "Current
transfer window" section originally implied unconfirmed fees would "catch up" once
the data refreshed; that's not what the data shows.

**Why this matters:** `dashboard/pages/index.md`'s "Current transfer window" section
now states the actual historical confirmation rate instead of promising the gap will
close, and filters that raw list to transfers with a known destination club rather
than showing mostly-blank rows. Confirmed independently that Snowflake already has
the latest published Kaggle version (dataset version 673, published 2026-07-11, and
our last pipeline run was 2026-07-17) — so this isn't a stale-pipeline bug either;
it's an honest characteristic of the source to document, not fix.

## Tech stack

| Layer | Tool | Notes |
|---|---|---|
| Ingestion | [dlt](https://dlthub.com/) | Python, `merge` write disposition |
| Warehouse | [Snowflake](https://www.snowflake.com/) | `RAW` + `ANALYTICS` databases, XS warehouse |
| Transformation | [dbt](https://www.getdbt.com/) | staging → intermediate → marts |
| Orchestration | [Airflow](https://airflow.apache.org/) via [Astronomer](https://www.astronomer.io/) | + [Cosmos](https://astronomer.github.io/astronomer-cosmos/) for dbt |
| Dashboard | [Evidence](https://evidence.dev/) | SvelteKit + DuckDB-wasm under the hood |
| CI/CD | GitHub Actions | sqlfluff, dbt build, Pages deploy |
| Auth | RSA key-pair, Snowflake SERVICE user | no passwords in any automated path |
