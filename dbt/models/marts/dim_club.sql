with

clubs as (
    select * from {{ ref('stg_transfermarkt__clubs') }}
),

club_elo_mapping as (
    select * from {{ ref('clubelo_club_mapping') }}
),

ratings as (
    select * from {{ ref('stg_clubelo__ratings') }}
),

-- Latest known rating per club, not "as of" any particular date — used to
-- gauge current club strength (see fct_wikipedia_transfer's dynamic club
-- targeting), distinct from int_transfers__club_elo_at_transfer which picks
-- the rating as of a specific transfer_date.
latest_elo as (
    select
        club_elo_mapping.club_id,
        ratings.elo,
        row_number() over (
            partition by club_elo_mapping.club_id
            order by ratings.rating_to_date desc
        ) as rn
    from club_elo_mapping
    inner join ratings
        on
            club_elo_mapping.clubelo_club = ratings.clubelo_club
            and club_elo_mapping.clubelo_country = ratings.clubelo_country
)

select
    clubs.club_id,
    clubs.club_code,
    clubs.club_name,
    clubs.domestic_competition_id,
    clubs.coach_name,
    clubs.squad_size,
    clubs.average_age,
    clubs.foreigners_number,
    clubs.foreigners_percentage,
    clubs.national_team_players,
    clubs.stadium_name,
    clubs.stadium_seats,
    clubs.net_transfer_record,
    clubs.last_season,
    -- Null for the ~30% of clubs ClubElo doesn't cover or the mapping didn't
    -- resolve (see ARCHITECTURE.md decision 13) — not "weak club", "unknown".
    latest_elo.elo as current_elo,
    -- Transfermarkt's crest CDN is keyed directly by their own club_id, with a
    -- stable, publicly documented URL pattern — no separate crest field exists
    -- in the source tables, and no extra ingestion needed to use it.
    concat('https://tmssl.akamaized.net/images/wappen/tiny/', clubs.club_id, '.png')
        as crest_url
from clubs
left join latest_elo on clubs.club_id = latest_elo.club_id and latest_elo.rn = 1
