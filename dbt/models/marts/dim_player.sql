with

players as (
    select * from {{ ref('stg_transfermarkt__players') }}
)

select
    player_id,
    player_code,
    first_name,
    last_name,
    player_name,
    image_url,
    date_of_birth,
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
    international_caps,
    international_goals,
    last_season,
    contract_expiration_date,
    market_value_in_eur as current_market_value_in_eur,
    highest_market_value_in_eur
from players
