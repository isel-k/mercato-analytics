---
title: ROI Transfert
---

Un transfert a-t-il été rentable au regard des performances sportives du joueur,
comparées à son coût d'acquisition et à sa valeur marchande ? Deux indicateurs,
volontairement distincts plutôt que fusionnés en un score unique : **ROI financier**
(plus-value de valeur marchande pendant le passage au club, rapportée au montant payé)
et **coût par contribution** (montant payé rapporté aux buts + passes décisives).

```sql kpi_summary
select
    count(*) as transfers_analyzed,
    avg(roi_financier) as avg_roi_financier,
    median(cost_per_goal_contribution) as median_cost_per_goal
from mercato_analytics.fct_transfer
where roi_financier is not null
```

<BigValue
    data={kpi_summary}
    value=transfers_analyzed
    title="Transferts analysés"
    fmt="#,##0"
/>
<BigValue
    data={kpi_summary}
    value=avg_roi_financier
    title="ROI financier moyen"
    fmt="pct1"
/>
<BigValue
    data={kpi_summary}
    value=median_cost_per_goal
    title="Coût médian par contribution (but + passe)"
    fmt="eur0"
/>

## Meilleurs ROI financiers

Transferts (montant ≥ 1M€) où la valeur marchande a le plus progressé pendant le
passage au club, rapportée au coût d'acquisition.

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
order by f.roi_financier desc
limit 12
```

<BarChart
    data={top_roi}
    title="Top 12 — ROI financier"
    x=player_name
    y=roi_financier
    swapXY=true
    fmt=pct1
/>

<DataTable data={top_roi} rows=12>
    <Column id=player_name title="Joueur"/>
    <Column id=transfer_date title="Transfert"/>
    <Column id=to_club title="Club"/>
    <Column id=transfer_fee title="Montant" fmt=eur0/>
    <Column id=market_value_at_transfer title="Valeur à l'achat" fmt=eur0/>
    <Column id=market_value_at_spell_end title="Valeur en fin de spell" fmt=eur0/>
    <Column id=roi_financier title="ROI financier" fmt=pct1/>
    <Column id=goals_during_spell title="Buts"/>
    <Column id=assists_during_spell title="Passes"/>
</DataTable>

## Pires ROI financiers

Même critère de montant, à l'autre extrémité du classement.

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
order by f.roi_financier asc
limit 12
```

<BarChart
    data={worst_roi}
    title="Bottom 12 — ROI financier"
    x=player_name
    y=roi_financier
    swapXY=true
    fmt=pct1
/>

<DataTable data={worst_roi} rows=12>
    <Column id=player_name title="Joueur"/>
    <Column id=transfer_date title="Transfert"/>
    <Column id=to_club title="Club"/>
    <Column id=transfer_fee title="Montant" fmt=eur0/>
    <Column id=market_value_at_transfer title="Valeur à l'achat" fmt=eur0/>
    <Column id=market_value_at_spell_end title="Valeur en fin de spell" fmt=eur0/>
    <Column id=roi_financier title="ROI financier" fmt=pct1/>
    <Column id=goals_during_spell title="Buts"/>
    <Column id=assists_during_spell title="Passes"/>
</DataTable>

## Meilleur rapport coût / contribution sportive

Transferts (montant ≥ 1M€, au moins un but ou une passe pendant le spell) au
moindre coût par but + passe décisive.

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
order by f.cost_per_goal_contribution asc
limit 12
```

<DataTable data={cost_efficiency} rows=12>
    <Column id=player_name title="Joueur"/>
    <Column id=transfer_date title="Transfert"/>
    <Column id=to_club title="Club"/>
    <Column id=transfer_fee title="Montant" fmt=eur0/>
    <Column id=goals_during_spell title="Buts"/>
    <Column id=assists_during_spell title="Passes"/>
    <Column id=cost_per_goal_contribution title="Coût / contribution" fmt=eur0/>
</DataTable>
