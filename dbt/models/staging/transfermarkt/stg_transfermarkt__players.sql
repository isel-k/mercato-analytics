with

source as (
    select * from {{ source('transfermarkt', 'players') }}
),

renamed as (
    select
        player_id,
        player_code,
        first_name,
        last_name,
        name as player_name,
        cast(date_of_birth as date) as date_of_birth,
        country_of_birth,
        city_of_birth,
        country_of_citizenship,
        position,
        sub_position,
        foot,
        height_in_cm,
        agent_name,
        current_club_id,
        current_club_name,
        current_club_domestic_competition_id,
        current_national_team_id,
        cast(international_caps as integer) as international_caps,
        cast(international_goals as integer) as international_goals,
        cast(last_season as integer) as last_season,
        cast(contract_expiration_date as date) as contract_expiration_date,
        market_value_in_eur,
        highest_market_value_in_eur,
        image_url,
        url
    from source
)

select * from renamed
