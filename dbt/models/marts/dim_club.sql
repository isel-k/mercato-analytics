with

clubs as (
    select * from {{ ref('stg_transfermarkt__clubs') }}
)

select
    club_id,
    club_code,
    club_name,
    domestic_competition_id,
    coach_name,
    squad_size,
    average_age,
    foreigners_number,
    foreigners_percentage,
    national_team_players,
    stadium_name,
    stadium_seats,
    net_transfer_record,
    last_season
from clubs
