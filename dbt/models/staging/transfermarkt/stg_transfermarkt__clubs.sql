with

source as (
    select * from {{ source('transfermarkt', 'clubs') }}
),

renamed as (
    select
        club_id,
        club_code,
        name as club_name,
        domestic_competition_id,
        coach_name,
        cast(squad_size as integer) as squad_size,
        average_age,
        cast(foreigners_number as integer) as foreigners_number,
        foreigners_percentage,
        cast(national_team_players as integer) as national_team_players,
        stadium_name,
        cast(stadium_seats as integer) as stadium_seats,
        net_transfer_record,
        cast(last_season as integer) as last_season,
        url
    from source
)

select * from renamed
