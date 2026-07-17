with

source as (
    select * from {{ source('transfermarkt', 'game_events') }}
),

renamed as (
    select
        game_event_id,
        game_id,
        cast(date as date) as event_date,
        cast(minute as integer) as minute,
        type as event_type,
        club_id,
        club_name,
        player_id,
        cast(player_assist_id as integer) as player_assist_id,
        cast(player_in_id as integer) as player_in_id,
        description
    from source
)

select * from renamed
