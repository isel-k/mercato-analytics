-- materialized as view (not the layer default ephemeral) so unit tests on
-- fct_transfer can introspect this model's columns for their fixtures.
{{ config(materialized='view') }}

with

scope as (
    select * from {{ ref('competition_champion_scope') }}
),

games as (
    select * from {{ ref('stg_transfermarkt__games') }}
),

club_games as (
    select * from {{ ref('stg_transfermarkt__club_games') }}
),

-- "round" has no numeric column of its own, only a string like "38. Matchday"
-- (checked across the 7 leagues in scope: always "<N>. Matchday", never a
-- differently-formatted label) — the leading integer is the matchday number.
league_games as (
    select
        games.game_id,
        games.competition_id,
        games.season,
        games.game_date,
        try_cast(regexp_substr(games.round, '^[0-9]+') as integer) as matchday_number
    from games
    inner join scope
        on games.competition_id = scope.competition_id and scope.champion_method = 'league_table'
),

last_matchday as (
    select
        competition_id,
        season,
        max(matchday_number) as matchday_number
    from league_games
    where matchday_number is not null
    group by competition_id, season
),

-- own_position on club_games already reflects the final league table once
-- joined to the season's last matchday — no need to reconstruct standings
-- ourselves. Checked: exactly one club at own_position = 1 per
-- competition/season across the scoped leagues (e.g. La Liga 2012-2025 spot
-- checked against real title history — see ARCHITECTURE.md decision 16).
league_champions as (
    select
        league_games.competition_id,
        league_games.season,
        'league' as title_type,
        club_games.club_id as champion_club_id,
        league_games.game_date as title_date
    from league_games
    inner join last_matchday
        on
            league_games.competition_id = last_matchday.competition_id
            and league_games.season = last_matchday.season
            and league_games.matchday_number = last_matchday.matchday_number
    inner join club_games
        on league_games.game_id = club_games.game_id and club_games.own_position = 1
),

-- A single match per season with round = 'Final' (verified for every
-- competition in scope with champion_method = 'cup_final' — including
-- shootout-decided finals, since Transfermarkt already folds the penalty
-- score into home/away_club_goals, e.g. the 2016 Champions League final
-- shows 6:4, not a 1:1 draw). is_win on club_games is already the
-- shootout-aware result, so no goal comparison needed here either.
cup_finals as (
    select
        games.competition_id,
        games.season,
        'cup' as title_type,
        club_games.club_id as champion_club_id,
        games.game_date as title_date
    from games
    inner join scope
        on games.competition_id = scope.competition_id and scope.champion_method = 'cup_final'
    inner join club_games
        on games.game_id = club_games.game_id and club_games.is_win = true
    where lower(games.round) = 'final'
)

select * from league_champions
union all
select * from cup_finals
