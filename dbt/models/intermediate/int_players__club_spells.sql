-- materialized as view (not the layer default ephemeral) so unit tests on
-- fct_transfer can introspect this model's columns for their fixtures.
{{ config(materialized='view') }}

with

transfers as (
    select * from {{ ref('stg_transfermarkt__transfers') }}
),

spells as (
    select
        transfer_id,
        player_id,
        to_club_id as club_id,
        transfer_date as spell_start_date,
        lead(transfer_date) over (
            partition by player_id order by transfer_date, transfer_id
        ) as spell_end_date
    from transfers
)

select
    transfer_id,
    player_id,
    club_id,
    spell_start_date,
    spell_end_date,
    spell_end_date is null as is_current_spell
from spells
