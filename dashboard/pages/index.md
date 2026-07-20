---
title: Transfer ROI
---

Was a transfer profitable given the player's sporting performance, relative to its
acquisition cost and market value? Two indicators, deliberately kept separate rather
than merged into a single score: **financial ROI** (market value gain during the
spell at the club, relative to the fee paid) and **cost per contribution** (fee paid
relative to goals + assists). For players still at the club, "value at spell end" is
their most recently known market value, not necessarily today's — Transfermarkt
doesn't re-value every player often, so each table below shows a **Valuation as of**
date alongside it.

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
[Best free transfers](#best-free-transfers) below for those, evaluated on absolute
value gained instead.*

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

## Current transfer window

```sql current_window_season
select
    transfer_season,
    case
        when left(transfer_season, 2)::int >= 50 then 1900 + left(transfer_season, 2)::int
        else 2000 + left(transfer_season, 2)::int
    end as season_start_year
from mercato_analytics.fct_transfer
order by season_start_year desc
limit 1
```

```sql current_window_counts
select
    count(*) as total,
    count(tc.club_id) as with_known_club
from mercato_analytics.fct_transfer f
left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where f.transfer_season = '${current_window_season[0].transfer_season}'
```

No transfer in the {current_window_season[0].transfer_season} window has a confirmed
fee yet in the source data — deals are typically reported as unknown or €0 for weeks
after being announced — so fee and financial ROI aren't shown here; they'll appear in
the rankings below once the data catches up. Showing the
{current_window_counts[0].with_known_club} of {current_window_counts[0].total}
transfers this window with a confirmed destination club, with each player's current
market value for context.

```sql current_window
select
    p.player_name,
    p.image_url,
    tc.club_name as to_club,
    tc.crest_url,
    p.current_market_value_in_eur,
    f.transfer_date
from mercato_analytics.fct_transfer f
join mercato_analytics.dim_player p on p.player_id = f.player_id
join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where f.transfer_season = '${current_window_season[0].transfer_season}'
    and coalesce(tc.club_name, '') like '${inputs.club.value}'
order by f.transfer_date desc
limit 20
```

<DataTable data={current_window} rows=20>
    <Column id=image_url title=" " contentType=image height="32px" width="32px" alt=player_name />
    <Column id=player_name title="Player"/>
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="Club"/>
    <Column id=current_market_value_in_eur title="Current value" fmt=eur0/>
    <Column id=transfer_date title="Date"/>
</DataTable>

## Financial ROI — best & worst

Transfers (fee ≥ €1M): the 6 biggest gains and the 6 biggest losses in market value
during the spell at the club, relative to the acquisition cost.

```sql roi_spectrum
with best as (
    select
        p.player_name,
        p.image_url,
        f.transfer_date,
        tc.club_name as to_club,
        tc.crest_url,
        f.transfer_fee,
        f.market_value_at_transfer,
        f.market_value_at_spell_end,
        f.market_value_at_spell_end_date,
        f.roi_financier,
        f.goals_during_spell,
        f.assists_during_spell
    from mercato_analytics.fct_transfer f
    join mercato_analytics.dim_player p on p.player_id = f.player_id
    left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
    where f.roi_financier is not null and f.transfer_fee >= 1000000
        and f.transfer_season like '${inputs.season.value}'
        and coalesce(tc.club_name, '') like '${inputs.club.value}'
    order by f.roi_financier desc
    limit 6
),

worst as (
    select
        p.player_name,
        p.image_url,
        f.transfer_date,
        tc.club_name as to_club,
        tc.crest_url,
        f.transfer_fee,
        f.market_value_at_transfer,
        f.market_value_at_spell_end,
        f.market_value_at_spell_end_date,
        f.roi_financier,
        f.goals_during_spell,
        f.assists_during_spell
    from mercato_analytics.fct_transfer f
    join mercato_analytics.dim_player p on p.player_id = f.player_id
    left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
    where f.roi_financier is not null and f.transfer_fee >= 1000000
        and f.transfer_season like '${inputs.season.value}'
        and coalesce(tc.club_name, '') like '${inputs.club.value}'
    order by f.roi_financier asc
    limit 6
),

combined as (
    select * from best
    union all
    select * from worst
)

select
    *,
    case when roi_financier >= 0 then 'Gained value' else 'Lost value' end as roi_direction
from combined
order by roi_financier desc
```

<BarChart
    data={roi_spectrum}
    title="Financial ROI — best & worst"
    x=player_name
    y=roi_financier
    series=roi_direction
    seriesColors={{'Gained value': 'positive', 'Lost value': 'negative'}}
    swapXY=true
    fmt=pct1
/>

<DataTable data={roi_spectrum} rows=12>
    <Column id=image_url title=" " contentType=image height="32px" width="32px" alt=player_name />
    <Column id=player_name title="Player"/>
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="Club"/>
    <Column id=roi_financier title="Financial ROI" fmt=pct1
        contentType=colorscale colorScale={['#dc2626', '#f3f4f6', '#16a34a']}
        colorMid={0} colorMin={-1} colorMax={1} />
    <Column id=transfer_fee title="Fee" fmt=eur0/>
    <Column id=transfer_date title="Transfer date"/>
    <Column id=market_value_at_transfer title="Value at acquisition" fmt=eur0/>
    <Column id=market_value_at_spell_end title="Value at spell end" fmt=eur0/>
    <Column id=market_value_at_spell_end_date title="Valuation as of"/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
</DataTable>

## Best cost-to-performance ratio

Transfers (fee ≥ €1M, at least one goal or assist during the spell) at the lowest
cost per goal + assist.

```sql cost_efficiency
select
    p.player_name,
    p.image_url,
    f.transfer_date,
    tc.club_name as to_club,
    tc.crest_url,
    f.transfer_fee,
    f.goals_during_spell,
    f.assists_during_spell,
    f.cost_per_goal_contribution
from mercato_analytics.fct_transfer f
join mercato_analytics.dim_player p on p.player_id = f.player_id
left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where f.cost_per_goal_contribution is not null and f.transfer_fee >= 1000000
    and f.transfer_season like '${inputs.season.value}'
    and coalesce(tc.club_name, '') like '${inputs.club.value}'
order by f.cost_per_goal_contribution asc
limit 12
```

<DataTable data={cost_efficiency} rows=12>
    <Column id=image_url title=" " contentType=image height="32px" width="32px" alt=player_name />
    <Column id=player_name title="Player"/>
    <Column id=transfer_date title="Transfer date"/>
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="Club"/>
    <Column id=transfer_fee title="Fee" fmt=eur0/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
    <Column id=cost_per_goal_contribution title="Cost / contribution" fmt=eur0/>
</DataTable>

## Best free transfers

Confirmed free transfers (fee = €0, not just an unrecorded fee — the source data
distinguishes the two) ranked by absolute market value gained during the spell.
`roi_financier` can't express this (dividing by a €0 cost isn't meaningful), so
this uses `value_gained_absolute` instead — the same value creation, in euros
rather than as a ratio.

```sql best_free_transfers
select
    p.player_name,
    p.image_url,
    f.transfer_date,
    tc.club_name as to_club,
    tc.crest_url,
    f.market_value_at_transfer,
    f.market_value_at_spell_end,
    f.market_value_at_spell_end_date,
    f.value_gained_absolute,
    f.goals_during_spell,
    f.assists_during_spell
from mercato_analytics.fct_transfer f
join mercato_analytics.dim_player p on p.player_id = f.player_id
left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where f.transfer_fee = 0 and f.value_gained_absolute is not null
    and f.transfer_season like '${inputs.season.value}'
    and coalesce(tc.club_name, '') like '${inputs.club.value}'
order by f.value_gained_absolute desc
limit 12
```

<BarChart
    data={best_free_transfers}
    title="Top 12 — Value gained on free transfers"
    x=player_name
    y=value_gained_absolute
    swapXY=true
    fmt=eur0
/>

<DataTable data={best_free_transfers} rows=12>
    <Column id=image_url title=" " contentType=image height="32px" width="32px" alt=player_name />
    <Column id=player_name title="Player"/>
    <Column id=transfer_date title="Transfer date"/>
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="Club"/>
    <Column id=market_value_at_transfer title="Value at signing" fmt=eur0/>
    <Column id=market_value_at_spell_end title="Value at spell end" fmt=eur0/>
    <Column id=market_value_at_spell_end_date title="Valuation as of"/>
    <Column id=value_gained_absolute title="Value gained" fmt=eur0/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
</DataTable>
