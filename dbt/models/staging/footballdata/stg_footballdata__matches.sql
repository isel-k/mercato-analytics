with

source as (
    select * from {{ source('footballdata', 'matches') }}
),

renamed as (
    select
        id as match_id,
        utc_date as match_utc_timestamp,
        status as match_status,
        cast(matchday as integer) as matchday,
        stage,
        competition__id as competition_id,
        competition__name as competition_name,
        competition__code as competition_code,
        season__id as season_id,
        cast(season__start_date as date) as season_start_date,
        cast(season__end_date as date) as season_end_date,
        home_team__id as home_team_id,
        home_team__name as home_team_name,
        away_team__id as away_team_id,
        away_team__name as away_team_name,
        score__winner as winner,
        cast(score__half_time__home as integer) as half_time_home_goals,
        cast(score__half_time__away as integer) as half_time_away_goals,
        cast(score__full_time__home as integer) as full_time_home_goals,
        cast(score__full_time__away as integer) as full_time_away_goals,
        cast(score__extra_time__home as integer) as extra_time_home_goals,
        cast(score__extra_time__away as integer) as extra_time_away_goals,
        cast(score__penalties__home as integer) as penalties_home_goals,
        cast(score__penalties__away as integer) as penalties_away_goals
    from source
)

select * from renamed
