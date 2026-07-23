-- materialized as view (not the layer default ephemeral) so unit tests on
-- fct_transfer can introspect this model's columns for their fixtures.
{{ config(materialized='view') }}

with

spells as (
    select * from {{ ref('int_players__club_spells') }}
),

champions as (
    select * from {{ ref('int_competitions__season_champions') }}
),

-- A title counts if the deciding match/matchday falls inside the spell's
-- open interval [spell_start_date, spell_end_date) — same interval logic as
-- int_transfers__performance_during_spell. This does not require the player
-- to have actually played that specific season (a squad player injured all
-- year still gets the medal in real life); see ARCHITECTURE.md decision 16.
titles_during_spell as (
    select
        spells.transfer_id,
        champions.title_type
    from spells
    inner join champions
        on
            spells.club_id = champions.champion_club_id
            and spells.spell_start_date <= champions.title_date
            and (
                spells.spell_end_date is null
                or spells.spell_end_date > champions.title_date
            )
)

select
    transfer_id,
    count_if(title_type = 'league') as league_titles_during_spell,
    count_if(title_type = 'cup') as cup_titles_during_spell
from titles_during_spell
group by transfer_id
