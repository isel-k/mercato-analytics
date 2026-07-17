with

source as (
    select * from {{ source('transfermarkt', 'club_games') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(['club_id', 'game_id']) }} as club_game_id,
        game_id,
        club_id,
        cast(own_goals as integer) as own_goals,
        cast(own_position as integer) as own_position,
        own_manager_name,
        opponent_id,
        cast(opponent_goals as integer) as opponent_goals,
        cast(opponent_position as integer) as opponent_position,
        opponent_manager_name,
        hosting,
        cast(is_win as boolean) as is_win
    from source
)

select * from renamed
