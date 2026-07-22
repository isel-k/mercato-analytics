---
title: Player lookup
sidebar_position: 2
---

Pick any player who appears in a transfer here — this page pulls together every ROI
signal this project can compute for them, combining `fct_transfer` (full financial +
performance ROI, when Transfermarkt recorded the deal) and `fct_wikipedia_transfer`
(realized ROI on recent departures for big clubs Transfermarkt's dataset has fallen
behind on — see [Recent transfers](/recent-transfers)). Defaults to Marc Cucurella,
the case that motivated building this page.

```sql player_list
select distinct player_name
from (
    select p.player_name
    from mercato_analytics.fct_transfer f
    join mercato_analytics.dim_player p on p.player_id = f.player_id
    union
    select w.player_name
    from mercato_analytics.fct_wikipedia_transfer w
    where w.direction = 'out' and w.value_gained_during_tenure is not null
)
order by player_name
```

<Dropdown data={player_list} name=player value=player_name title="Player" defaultValue="Marc Cucurella"/>

```sql player_profile
select
    p.player_name,
    p.image_url,
    p.position,
    p.country_of_citizenship,
    p.current_club_name,
    p.current_market_value_in_eur
from mercato_analytics.dim_player p
where p.player_name = '${inputs.player.value}'
order by p.current_market_value_in_eur desc nulls last
limit 1
```

{#if player_profile.length}
<div class="flex items-center gap-4 my-6 flex-wrap">
    <Image url={player_profile[0].image_url} width="80px" height="80px" description={player_profile[0].player_name} class="rounded-full object-cover" />
    <div>
        <div class="text-2xl font-bold">{player_profile[0].player_name}</div>
        <div class="opacity-60">{player_profile[0].position} · {player_profile[0].country_of_citizenship}</div>
        <div class="opacity-60">Current club: {player_profile[0].current_club_name}</div>
    </div>
    <BigValue data={player_profile} value=current_market_value_in_eur title="Current market value" fmt=eur0 />
</div>
{/if}

## Transfermarkt-recorded history

```sql player_transfers
select
    fc.club_name as from_club,
    fc.crest_url as from_crest,
    tc.club_name as to_club,
    tc.crest_url as to_crest,
    f.transfer_date,
    f.transfer_fee,
    f.market_value_at_transfer,
    f.market_value_at_spell_end,
    f.market_value_at_spell_end_date,
    f.roi_financier,
    f.value_gained_absolute,
    f.goals_during_spell,
    f.assists_during_spell
from mercato_analytics.fct_transfer f
join mercato_analytics.dim_player p on p.player_id = f.player_id
left join mercato_analytics.dim_club fc on fc.club_id = f.from_club_id
left join mercato_analytics.dim_club tc on tc.club_id = f.to_club_id
where p.player_name = '${inputs.player.value}'
order by f.transfer_date desc
```

{#if player_transfers.length}
<DataTable data={player_transfers} rows=10>
    <Column id=from_crest title=" " contentType=image height="20px" width="20px" alt=from_club />
    <Column id=from_club title="From"/>
    <Column id=to_crest title=" " contentType=image height="20px" width="20px" alt=to_club />
    <Column id=to_club title="To"/>
    <Column id=transfer_date title="Date"/>
    <Column id=transfer_fee title="Fee" fmt=eur0/>
    <Column id=market_value_at_transfer title="Value at signing" fmt=eur0/>
    <Column id=market_value_at_spell_end title="Value at spell end" fmt=eur0/>
    <Column id=market_value_at_spell_end_date title="Valuation as of"/>
    <Column id=roi_financier title="Financial ROI" fmt=pct1
        contentType=colorscale colorScale={['#dc2626', '#f3f4f6', '#16a34a']}
        colorMid={0} colorMin={-1} colorMax={1} />
    <Column id=goals_during_spell title="Goals"/>
    <Column id=assists_during_spell title="Assists"/>
</DataTable>
{:else}
No transfer recorded for this player in `fct_transfer` — either a genuinely early
career, or one of the gaps documented in `ARCHITECTURE.md` (decisions 14 & 15). Check
the Wikipedia-sourced section below.
{/if}

## Wikipedia-sourced recent moves

Only populated for players who moved in or out of the specific big clubs targeted by
the Wikipedia pipeline (see [Recent transfers](/recent-transfers)) — not a general
transfer database.

```sql player_wiki_transfers
select
    w.club_name,
    tc.crest_url,
    w.other_club_name,
    w.direction,
    w.transfer_date,
    w.fee_amount,
    w.value_at_arrival,
    w.value_at_departure,
    w.value_gained_during_tenure,
    w.fee_vs_last_valuation
from mercato_analytics.fct_wikipedia_transfer w
left join mercato_analytics.dim_club tc on tc.club_id = w.club_id
where w.player_name = '${inputs.player.value}'
order by w.transfer_date desc
```

{#if player_wiki_transfers.length}
<div class="grid grid-cols-1 sm:grid-cols-2 gap-4 my-6">
{#each player_wiki_transfers as t}
<div class="rounded-lg border border-base-300 p-4">
    <div class="flex items-center gap-2 font-semibold">
        <Image url={t.crest_url} width="20px" height="20px" description={t.club_name} />
        {t.club_name}
        {t.direction === 'out' ? '→' : '←'}
        {t.other_club_name}
        <span class="opacity-60 font-normal text-sm ml-auto">{fmt(t.transfer_date, 'YYYY-MM-DD')}</span>
    </div>
    {#if t.fee_amount}
    <div class="mt-2">Fee: {fmt(t.fee_amount, 'eur0')}</div>
    {/if}
    {#if t.direction === 'out' && t.value_gained_during_tenure !== null}
    <div>
        Value gained during spell:
        <span class="font-semibold" class:text-positive={t.value_gained_during_tenure >= 0} class:text-negative={t.value_gained_during_tenure < 0}>
            {fmt(t.value_gained_during_tenure, 'eur0')}
        </span>
    </div>
    {/if}
    {#if t.direction === 'out' && t.fee_vs_last_valuation !== null}
    <div>
        Fee vs last valuation:
        <span class="font-semibold" class:text-positive={t.fee_vs_last_valuation >= 0} class:text-negative={t.fee_vs_last_valuation < 0}>
            {fmt(t.fee_vs_last_valuation, 'eur0')}
        </span>
    </div>
    {/if}
</div>
{/each}
</div>
{:else}
No Wikipedia-sourced move recorded for this player.
{/if}
