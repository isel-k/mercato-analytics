with

source as (
    select * from {{ source('transfermarkt', 'games') }}
),

renamed as (
    select
        game_id,
        competition_id,
        competition_type,
        cast(season as integer) as season,
        round,
        cast(date as date) as game_date,
        home_club_id,
        home_club_name,
        home_club_manager_name,
        home_club_formation,
        cast(home_club_goals as integer) as home_club_goals,
        cast(home_club_position as integer) as home_club_position,
        away_club_id,
        away_club_name,
        away_club_manager_name,
        away_club_formation,
        cast(away_club_goals as integer) as away_club_goals,
        cast(away_club_position as integer) as away_club_position,
        aggregate,
        stadium,
        cast(attendance as integer) as attendance,
        referee,
        url
    from source
)

select * from renamed
