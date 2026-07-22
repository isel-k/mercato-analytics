---
title: Club-level moves
sidebar_position: 4
---

Was the destination club stronger or weaker than the one left, by [ClubElo](http://clubelo.com/)
rating at the time of the transfer? Positive = a step up, negative = a step down.
ClubElo only tracks European football, and the club-name matching behind this
column doesn't reach full coverage even within Europe (~70% of clubs) — restricted
here to transfers with a confirmed fee ≥ €1M, where coverage is closer to 73%.

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

```sql elo_spectrum
with best as (
    select
        p.player_name,
        p.image_url,
        f.transfer_date,
        fc.club_name as from_club,
        tc.club_name as to_club,
        tc.crest_url,
        f.club_elo_delta
    from mercato_analytics.fct_transfer f
    join mercato_analytics.dim_player p on p.player_id = f.player_id
    left join mercato_analytics.dim_club fc on fc.club_id = f.from_club_id
    left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
    where f.club_elo_delta is not null and f.transfer_fee >= 1000000
        and f.transfer_season like '${inputs.season.value}'
        and coalesce(tc.club_name, '') like '${inputs.club.value}'
    order by f.club_elo_delta desc
    limit 6
),

worst as (
    select
        p.player_name,
        p.image_url,
        f.transfer_date,
        fc.club_name as from_club,
        tc.club_name as to_club,
        tc.crest_url,
        f.club_elo_delta
    from mercato_analytics.fct_transfer f
    join mercato_analytics.dim_player p on p.player_id = f.player_id
    left join mercato_analytics.dim_club fc on fc.club_id = f.from_club_id
    left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
    where f.club_elo_delta is not null and f.transfer_fee >= 1000000
        and f.transfer_season like '${inputs.season.value}'
        and coalesce(tc.club_name, '') like '${inputs.club.value}'
    order by f.club_elo_delta asc
    limit 6
),

combined as (
    select * from best
    union all
    select * from worst
)

select
    *,
    case when club_elo_delta >= 0 then 'Stepped up' else 'Stepped down' end as elo_direction
from combined
order by club_elo_delta desc
```

<BarChart
    data={elo_spectrum}
    title="Biggest club-level moves"
    x=player_name
    y=club_elo_delta
    series=elo_direction
    seriesColors={{'Stepped up': 'positive', 'Stepped down': 'negative'}}
    swapXY=true
/>

<DataTable data={elo_spectrum} rows=12>
    <Column id=image_url title=" " contentType=image height="32px" width="32px" alt=player_name />
    <Column id=player_name title="Player"/>
    <Column id=from_club title="From"/>
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="To"/>
    <Column id=transfer_date title="Transfer date"/>
    <Column id=club_elo_delta title="Elo change"
        contentType=colorscale colorScale={['#dc2626', '#f3f4f6', '#16a34a']}
        colorMid={0} colorMin={-500} colorMax={500} />
</DataTable>
