-- materialized as view (not the layer default ephemeral) so unit tests on
-- fct_transfer can introspect this model's columns for their fixtures.
{{ config(materialized='view') }}

with

spells as (
    select * from {{ ref('int_players__club_spells') }}
),

appearances as (
    select * from {{ ref('stg_transfermarkt__appearances') }}
),

games as (
    select * from {{ ref('stg_transfermarkt__games') }}
),

appearances_during_spell as (
    select
        spells.transfer_id,
        appearances.appearance_id,
        appearances.goals,
        appearances.assists,
        appearances.minutes_played,
        appearances.yellow_cards,
        appearances.red_cards,
        games.season
    from spells
    left join appearances
        on
            spells.player_id = appearances.player_id
            and spells.club_id = appearances.player_club_id
            and spells.spell_start_date <= appearances.appearance_date
            and (
                spells.spell_end_date is null
                or spells.spell_end_date > appearances.appearance_date
            )
    left join games on appearances.game_id = games.game_id
),

aggregated as (
    select
        transfer_id,
        count(appearance_id) as matches_played,
        -- seasons_played, not just matches_played: a long-tenured, non-scoring
        -- player (a holding midfielder, say) reads as a poor signing by
        -- roi_financier (market value declines with age) and by
        -- cost_per_goal_contribution (few goals/assists) alike — neither
        -- captures "stayed 10+ seasons and was clearly worth keeping".
        count(distinct season) as seasons_played,
        coalesce(sum(goals), 0) as goals,
        coalesce(sum(assists), 0) as assists,
        coalesce(sum(minutes_played), 0) as minutes_played,
        coalesce(sum(yellow_cards), 0) as yellow_cards,
        coalesce(sum(red_cards), 0) as red_cards
    from appearances_during_spell
    group by transfer_id
)

select * from aggregated
