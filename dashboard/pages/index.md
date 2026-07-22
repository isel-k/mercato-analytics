---
title: Overview
sidebar_position: 0
---

Was a transfer profitable, given the price paid and the player's sporting
performance? This project tracks **transfer ROI** from four separate angles —
deliberately kept apart rather than merged into one score, since each answers a
different question:

- **[Financial ROI](/financial-roi)** — market value gained during the spell at the
  club, relative to the fee paid, plus cost per goal + assist.
- **[Recent transfers](/recent-transfers)** — the current transfer window, big clubs
  Transfermarkt's dataset has fallen behind on, and realized ROI for recent
  departures (e.g. was selling Cucurella to Real Madrid a good deal for Chelsea?).
- **[Club-level moves](/club-moves)** — did the player join a club stronger or
  weaker than the one they left, by [ClubElo](http://clubelo.com/) rating?
- **[Player lookup](/players)** — search any player and see their full transfer
  history and ROI, combined across every source in this project.

*Out of scope: commercial value (shirt sales, sponsorship, social reach) isn't in
this ROI — none of the sources behind this project publish player-level commercial
figures, and a made-up proxy would be worse than not having one.*

```sql seasons
select distinct
    transfer_season,
    case
        when left(transfer_season, 2)::int >= 50 then 1900 + left(transfer_season, 2)::int
        else 2000 + left(transfer_season, 2)::int
    end as season_start_year
from mercato_analytics.fct_transfer
order by season_start_year desc
```

```sql clubs
select distinct tc.club_name
from mercato_analytics.fct_transfer f
join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
order by tc.club_name
```

<Dropdown data={seasons} name=season value=transfer_season title="Season">
    <DropdownOption value="%" valueLabel="All seasons"/>
</Dropdown>

<Dropdown data={clubs} name=club value=club_name title="Club (acquiring)">
    <DropdownOption value="%" valueLabel="All clubs"/>
</Dropdown>

```sql kpi_summary
select
    count(*) as transfers_analyzed,
    avg(f.roi_financier) as avg_roi_financier,
    median(f.cost_per_goal_contribution) as median_cost_per_goal
from mercato_analytics.fct_transfer f
left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where f.roi_financier is not null
    and f.transfer_season like '${inputs.season.value}'
    and coalesce(tc.club_name, '') like '${inputs.club.value}'
```

<BigValue
    data={kpi_summary}
    value=transfers_analyzed
    title="Transfers analyzed"
    fmt="#,##0"
/>
<BigValue
    data={kpi_summary}
    value=avg_roi_financier
    title="Average financial ROI"
    fmt="pct1"
/>
<BigValue
    data={kpi_summary}
    value=median_cost_per_goal
    title="Median cost per contribution (goal + assist)"
    fmt="eur0"
/>

*`roi_financier` is a ratio, undefined for free transfers (fee = €0) — see
[Best free transfers](/financial-roi#best-free-transfers) for those, evaluated on
absolute value gained instead.*

```sql hero_players
select
    p.player_name,
    p.image_url,
    tc.club_name as to_club,
    tc.crest_url,
    f.roi_financier
from mercato_analytics.fct_transfer f
join mercato_analytics.dim_player p on p.player_id = f.player_id
left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where f.roi_financier is not null and f.transfer_fee >= 1000000
    and f.transfer_season like '${inputs.season.value}'
    and coalesce(tc.club_name, '') like '${inputs.club.value}'
order by f.roi_financier desc
limit 6
```

<div class="grid grid-cols-2 sm:grid-cols-3 gap-4 my-6">
{#each hero_players as p}
<div class="rounded-lg border border-base-300 p-4 flex flex-col items-center text-center gap-1">
    <Image url={p.image_url} width="64px" height="64px" description={p.player_name} class="rounded-full object-cover" />
    <div class="font-semibold mt-1">{p.player_name}</div>
    <div class="flex items-center gap-1 text-sm opacity-60">
        <Image url={p.crest_url} width="16px" height="16px" description={p.to_club} />
        {p.to_club}
    </div>
    <div class="text-2xl font-bold" class:text-positive={p.roi_financier >= 0} class:text-negative={p.roi_financier < 0}>
        {fmt(p.roi_financier, 'pct1')}
    </div>
</div>
{/each}
</div>
