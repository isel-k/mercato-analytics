with

source as (
    select * from {{ source('transfermarkt', 'game_lineups') }}
),

renamed as (
    select
        game_lineups_id,
        game_id,
        cast(date as date) as game_date,
        club_id,
        player_id,
        player_name,
        type as lineup_type,
        position,
        number as shirt_number,
        cast(team_captain as boolean) as team_captain
    from source
)

select * from renamed
