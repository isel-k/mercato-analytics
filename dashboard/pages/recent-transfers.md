---
title: Recent transfers
sidebar_position: 1
---

The current transfer window, and a fix for a gap in it: a handful of major European
clubs go unusually long without a Transfermarkt-recorded transfer even while still
competing at the top level — it's inconsistent per-club staleness in the upstream
scraper, not a season-wide gap. This page also answers the question the season-level
tables can't: for a player who just left one of those clubs, was the sale a good deal
for the *seller*?

```sql clubs
select distinct club_name
from (
    select tc.club_name
    from mercato_analytics.fct_transfer f
    join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
    union
    select tc.club_name
    from mercato_analytics.fct_wikipedia_transfer w
    join mercato_analytics.dim_club tc on tc.club_id = w.club_id
)
order by club_name
```

<Dropdown data={clubs} name=club value=club_name title="Club">
    <DropdownOption value="%" valueLabel="All clubs"/>
</Dropdown>

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
    count(tc.club_id) as with_known_club,
    sum(case when f.transfer_fee > 0 then 1 else 0 end) as fee_confirmed
from mercato_analytics.fct_transfer f
left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where f.transfer_season = '${current_window_season[0].transfer_season}'
```

```sql prior_season_fee_rate
with season_years as (
    select distinct
        transfer_season,
        case
            when left(transfer_season, 2)::int >= 50 then 1900 + left(transfer_season, 2)::int
            else 2000 + left(transfer_season, 2)::int
        end as season_start_year
    from mercato_analytics.fct_transfer
),

prior_season as (
    select transfer_season
    from season_years
    order by season_start_year desc
    limit 1 offset 1
)

select
    round(100.0 * sum(case when transfer_fee > 0 then 1 else 0 end) / count(*), 1) as pct_fee_confirmed
from mercato_analytics.fct_transfer
where transfer_season = (select transfer_season from prior_season)
```

Real transfers do get reported with a fee on Transfermarkt — but this dataset's
upstream pipeline has a parsing gap: any fee text that isn't formatted exactly as
`€X.Xm` (loan fees, "Loan"/"End of loan", non-euro amounts) silently collapses to
€0, indistinguishable from a genuine free transfer, and the raw text isn't kept
anywhere downstream to recover it. It's a real bug in the source
([`transfermarkt-datasets`](https://github.com/dcaribou/transfermarkt-datasets/blob/master/dbt/models/base/transfermarkt_api/base_transfers.sql)),
not something fixable from here — even last season
({prior_season_fee_rate[0].pct_fee_confirmed}% of transfers had a non-zero fee) shows
the same pattern. The {current_window_season[0].transfer_season} window has
{current_window_counts[0].fee_confirmed} non-zero fees so far, consistent with that
gap rather than being unusually behind; fee and financial ROI aren't shown here for
that reason. Showing the {current_window_counts[0].with_known_club} of
{current_window_counts[0].total} transfers this window with a confirmed destination
club, with each player's current market value for context instead.

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

## Big clubs Transfermarkt is missing

Real Madrid, among others, has zero transfers recorded in `fct_transfer` since July
2024. Scraping transfermarkt.com directly to fill this in was considered and
rejected: their `robots.txt` names `ClaudeBot`, `Claude-SearchBot` and `anthropic-ai`
with `Disallow: /` — not a generic bot block, a targeted one. These rows come from
Wikipedia instead (checked: no AI-crawler restriction, CC-BY-SA licensed for reuse,
accessed via the official MediaWiki API), for a curated, dynamically-refreshed list
of the biggest affected clubs. Fee is a best-effort extraction from each player's own
Wikipedia article — often missing even for a real paid transfer, so a blank fee here
means "not found in the text", not "confirmed free".

```sql wikipedia_recent_transfers
select
    w.club_name,
    tc.crest_url,
    w.player_image_url,
    w.player_name,
    w.other_club_name as from_club,
    w.transfer_date,
    w.transfer_type,
    w.fee_amount,
    w.fee_currency
from mercato_analytics.fct_wikipedia_transfer w
left join mercato_analytics.dim_club tc on tc.club_id = w.club_id
where w.direction = 'in'
    and coalesce(w.club_name, '') like '${inputs.club.value}'
order by w.transfer_date desc
limit 30
```

<DataTable data={wikipedia_recent_transfers} rows=30>
    <Column id=player_image_url title=" " contentType=image height="28px" width="28px" alt=player_name />
    <Column id=player_name title="Player"/>
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=club_name />
    <Column id=club_name title="Club"/>
    <Column id=from_club title="From"/>
    <Column id=transfer_date title="Date"/>
    <Column id=transfer_type title="Type"/>
    <Column id=fee_amount title="Fee" fmt=eur0/>
    <Column id=fee_currency title="Currency"/>
</DataTable>

## Realized ROI — recent departures

The transfers above only show arrivals, and only a fee — not whether the *selling*
club actually made a good deal. `fct_transfer` can't answer that here either: its
player-history coverage for these same big clubs has the same gap as the
season-level one above, missing entire transfer histories for well-documented
departures (Griezmann, Cucurella — verified directly, see `ARCHITECTURE.md`
decision 15 in the repo).

Instead, each departure below is priced against the player's own market-value
history at that specific club (from `player_valuations`, which — unlike the
transfer records — does cover these players): **value gained during the spell**
(value when they left minus value when they arrived, independent of the original
fee) and **fee vs. last valuation** (did the sale price beat the player's own most
recent market value?). Two separate questions, kept apart rather than blended, same
approach as [Financial ROI](/financial-roi).

```sql cucurella_example
select
    w.club_name as from_club,
    w.other_club_name as to_club,
    w.fee_amount,
    w.value_at_arrival,
    w.value_at_departure,
    w.value_gained_during_tenure,
    w.fee_vs_last_valuation
from mercato_analytics.fct_wikipedia_transfer w
where w.direction = 'out' and lower(w.player_name) like '%cucurella%'
order by w.transfer_date desc
limit 1
```

{#if cucurella_example.length}
Take Marc Cucurella's move from {cucurella_example[0].from_club} to
{cucurella_example[0].to_club}: {cucurella_example[0].from_club} sold him for
<Value data={cucurella_example} column=fee_amount fmt=eur0 />, which is
<Value data={cucurella_example} column=fee_vs_last_valuation fmt=eur0 /> versus his
last known market value of
<Value data={cucurella_example} column=value_at_departure fmt=eur0 /> — even though
that valuation had fallen
<Value data={cucurella_example} column=value_gained_during_tenure fmt=eur0 /> since
he arrived. A small win on the sale price itself, against a player whose value had
been sliding: **positive `fee_vs_last_valuation`, negative `value_gained_during_tenure`**
— exactly why the two are shown separately instead of merged into one number. Look up
any other player on the [Player lookup](/players) page.
{/if}

```sql wiki_departures_roi
with best as (
    select
        w.player_name,
        w.player_image_url,
        w.transfer_date,
        w.club_name as sold_by,
        tc.crest_url,
        w.other_club_name as sold_to,
        w.value_at_arrival,
        w.value_at_arrival_date,
        w.value_at_departure,
        w.value_at_departure_date,
        w.value_gained_during_tenure,
        w.fee_amount,
        w.fee_vs_last_valuation
    from mercato_analytics.fct_wikipedia_transfer w
    left join mercato_analytics.dim_club tc on tc.club_id = w.club_id
    where w.direction = 'out' and w.value_gained_during_tenure is not null
        and coalesce(w.club_name, '') like '${inputs.club.value}'
    order by w.value_gained_during_tenure desc
    limit 6
),

worst as (
    select
        w.player_name,
        w.player_image_url,
        w.transfer_date,
        w.club_name as sold_by,
        tc.crest_url,
        w.other_club_name as sold_to,
        w.value_at_arrival,
        w.value_at_arrival_date,
        w.value_at_departure,
        w.value_at_departure_date,
        w.value_gained_during_tenure,
        w.fee_amount,
        w.fee_vs_last_valuation
    from mercato_analytics.fct_wikipedia_transfer w
    left join mercato_analytics.dim_club tc on tc.club_id = w.club_id
    where w.direction = 'out' and w.value_gained_during_tenure is not null
        and coalesce(w.club_name, '') like '${inputs.club.value}'
    order by w.value_gained_during_tenure asc
    limit 6
),

combined as (
    select * from best
    union all
    select * from worst
)

select
    *,
    case when value_gained_during_tenure >= 0 then 'Gained value' else 'Lost value' end as roi_direction
from combined
order by value_gained_during_tenure desc
```

<BarChart
    data={wiki_departures_roi}
    title="Value gained or lost during the spell — recent departures"
    x=player_name
    y=value_gained_during_tenure
    series=roi_direction
    seriesColors={{'Gained value': 'positive', 'Lost value': 'negative'}}
    swapXY=true
    fmt=eur0
/>

<DataTable data={wiki_departures_roi} rows=12>
    <Column id=player_image_url title=" " contentType=image height="32px" width="32px" alt=player_name />
    <Column id=player_name title="Player"/>
    <Column id=crest_url title=" " contentType=image height="20px" width="20px" alt=sold_by />
    <Column id=sold_by title="Sold by"/>
    <Column id=sold_to title="To"/>
    <Column id=transfer_date title="Date"/>
    <Column id=value_at_arrival title="Value at arrival" fmt=eur0/>
    <Column id=value_at_arrival_date title="as of"/>
    <Column id=value_at_departure title="Value at departure" fmt=eur0/>
    <Column id=value_at_departure_date title="as of"/>
    <Column id=value_gained_during_tenure title="Value gained during spell" fmt=eur0
        contentType=colorscale colorScale={['#dc2626', '#f3f4f6', '#16a34a']}
        colorMid={0} colorMin={-70000000} colorMax={70000000} />
    <Column id=fee_amount title="Sale fee" fmt=eur0/>
    <Column id=fee_vs_last_valuation title="Fee vs last valuation" fmt=eur0
        contentType=colorscale colorScale={['#dc2626', '#f3f4f6', '#16a34a']}
        colorMid={0} colorMin={-70000000} colorMax={70000000} />
</DataTable>
