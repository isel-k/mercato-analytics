with

source as (
    select * from {{ source('transfermarkt', 'player_valuations') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(['player_id', 'date']) }} as player_valuation_id,
        player_id,
        cast(date as date) as valuation_date,
        market_value_in_eur,
        current_club_id,
        current_club_name,
        player_club_domestic_competition_id
    from source
)

select * from renamed
