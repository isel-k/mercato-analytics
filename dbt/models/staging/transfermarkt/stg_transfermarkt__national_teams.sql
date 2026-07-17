with

source as (
    select * from {{ source('transfermarkt', 'national_teams') }}
),

renamed as (
    select
        national_team_id,
        name as national_team_name,
        team_code,
        country_id,
        country_name,
        country_code,
        confederation,
        team_image_url,
        cast(squad_size as integer) as squad_size,
        average_age,
        cast(foreigners_number as integer) as foreigners_number,
        foreigners_percentage,
        total_market_value,
        cast(fifa_ranking as integer) as fifa_ranking,
        cast(last_season as integer) as last_season,
        url
    from source
)

select * from renamed
