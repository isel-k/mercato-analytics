with

matches as (
    select * from {{ ref('stg_footballdata__matches') }}
)

select
    match_id,
    match_utc_timestamp,
    match_status,
    matchday,
    stage,
    competition_id,
    competition_name,
    season_id,
    home_team_id,
    away_team_id,
    winner,
    half_time_home_goals,
    half_time_away_goals,
    full_time_home_goals,
    full_time_away_goals
from matches
