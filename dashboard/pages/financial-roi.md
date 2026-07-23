---
title: Financial ROI
sidebar_position: 3
---

Two indicators, deliberately kept separate rather than merged into a single score:
**financial ROI** (market value gain during the spell at the club, relative to the
fee paid) and **cost per contribution** (fee paid relative to goals + assists). Each
list below is deliberately kept to the headline numbers — fee, ROI, performance —
rather than every raw valuation; look up any player on [Player lookup](/players)
for the full underlying detail (value at signing, value at spell end, and the date
of that valuation, which isn't always recent — Transfermarkt doesn't re-value every
player often).

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
    <Column id=to_club title="Club" width="140px" wrap=true/>
    <Column id=roi_financier title="Financial ROI" fmt=pct1
        contentType=colorscale colorScale={['#dc2626', '#f3f4f6', '#16a34a']}
        colorMid={0} colorMin={-1} colorMax={1} />
    <Column id=transfer_fee title="Fee" fmt=eur0/>
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
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="Club" width="140px" wrap=true/>
    <Column id=transfer_fee title="Fee" fmt=eur0/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
    <Column id=cost_per_goal_contribution title="Cost / contribution" fmt=eur0/>
</DataTable>

## Best free transfers

Transfers recorded at fee = €0 — mostly genuine free transfers, but the source's
upstream parser also collapses loans and a few unparsed fee formats into the same
€0, so treat this as "no confirmed fee" rather than a guaranteed-free list — ranked
by absolute market value gained during the spell. `roi_financier` can't express this
(dividing by a €0 cost isn't meaningful), so this uses `value_gained_absolute`
instead — the same value creation, in euros rather than as a ratio.

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
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="Club" width="140px" wrap=true/>
    <Column id=value_gained_absolute title="Value gained" fmt=eur0/>
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
</DataTable>
