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
    last_season,
    -- Transfermarkt's crest CDN is keyed directly by their own club_id, with a
    -- stable, publicly documented URL pattern — no separate crest field exists
    -- in the source tables, and no extra ingestion needed to use it.
    concat('https://tmssl.akamaized.net/images/wappen/tiny/', club_id, '.png')
        as crest_url
from clubs
