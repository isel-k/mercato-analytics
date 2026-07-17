with

source as (
    select * from {{ source('transfermarkt', 'appearances') }}
),

renamed as (
    select
        appearance_id,
        game_id,
        player_id,
        player_name,
        player_club_id,
        player_current_club_id,
        competition_id,
        cast(date as date) as appearance_date,
        cast(goals as integer) as goals,
        cast(assists as integer) as assists,
        cast(minutes_played as integer) as minutes_played,
        cast(yellow_cards as integer) as yellow_cards,
        cast(red_cards as integer) as red_cards
    from source
)

select * from renamed
