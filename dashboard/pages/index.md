---
title: Transfer ROI
---

Was a transfer profitable given the player's sporting performance, relative to its
acquisition cost and market value? Two indicators, deliberately kept separate rather
than merged into a single score: **financial ROI** (market value gain during the
spell at the club, relative to the fee paid) and **cost per contribution** (fee paid
relative to goals + assists).

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

## Best financial ROI

Transfers (fee ≥ €1M) where market value grew the most during the spell at the
club, relative to the acquisition cost.

```sql top_roi
select
    p.player_name,
    f.transfer_date,
    tc.club_name as to_club,
    f.transfer_fee,
    f.market_value_at_transfer,
    f.market_value_at_spell_end,
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
limit 12
```

<BarChart
    data={top_roi}
    title="Top 12 — Financial ROI"
    x=player_name
    y=roi_financier
    swapXY=true
    fmt=pct1
/>

<DataTable data={top_roi} rows=12>
    <Column id=player_name title="Player"/>
    <Column id=transfer_date title="Transfer date"/>
    <Column id=to_club title="Club"/>
    <Column id=transfer_fee title="Fee" fmt=eur0/>
    <Column id=market_value_at_transfer title="Value at acquisition" fmt=eur0/>
    <Column id=market_value_at_spell_end title="Value at spell end" fmt=eur0/>
    <Column id=roi_financier title="Financial ROI" fmt=pct1/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
</DataTable>

## Worst financial ROI

Same fee threshold, at the other end of the ranking.

```sql worst_roi
select
    p.player_name,
    f.transfer_date,
    tc.club_name as to_club,
    f.transfer_fee,
    f.market_value_at_transfer,
    f.market_value_at_spell_end,
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
limit 12
```

<BarChart
    data={worst_roi}
    title="Bottom 12 — Financial ROI"
    x=player_name
    y=roi_financier
    swapXY=true
    fmt=pct1
/>

<DataTable data={worst_roi} rows=12>
    <Column id=player_name title="Player"/>
    <Column id=transfer_date title="Transfer date"/>
    <Column id=to_club title="Club"/>
    <Column id=transfer_fee title="Fee" fmt=eur0/>
    <Column id=market_value_at_transfer title="Value at acquisition" fmt=eur0/>
    <Column id=market_value_at_spell_end title="Value at spell end" fmt=eur0/>
    <Column id=roi_financier title="Financial ROI" fmt=pct1/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
</DataTable>

## Best cost-to-performance ratio

Transfers (fee ≥ €1M, at least one goal or assist during the spell) at the lowest
cost per goal + assist.

```sql cost_efficiency
select
    p.player_name,
    f.transfer_date,
    tc.club_name as to_club,
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
    <Column id=player_name title="Player"/>
    <Column id=transfer_date title="Transfer date"/>
    <Column id=to_club title="Club"/>
    <Column id=transfer_fee title="Fee" fmt=eur0/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
    <Column id=cost_per_goal_contribution title="Cost / contribution" fmt=eur0/>
</DataTable>
