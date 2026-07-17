-- materialized as view (not the layer default ephemeral) so unit tests on
-- fct_transfer can introspect this model's columns for their fixtures.
{{ config(materialized='view') }}

with

spells as (
    select * from {{ ref('int_players__club_spells') }}
),

valuations as (
    select * from {{ ref('stg_transfermarkt__player_valuations') }}
),

valuations_before_cutoff as (
    select
        spells.transfer_id,
        valuations.market_value_in_eur,
        valuations.valuation_date,
        row_number() over (
            partition by spells.transfer_id
            order by valuations.valuation_date desc
        ) as valuation_rank
    from spells
    inner join valuations
        on
            spells.player_id = valuations.player_id
            and valuations.valuation_date <= coalesce(spells.spell_end_date, current_date())
)

select
    transfer_id,
    market_value_in_eur as market_value_at_spell_end,
    valuation_date as market_value_at_spell_end_date
from valuations_before_cutoff
where valuation_rank = 1
