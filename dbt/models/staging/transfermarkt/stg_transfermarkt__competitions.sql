with

source as (
    select * from {{ source('transfermarkt', 'competitions') }}
),

renamed as (
    select
        competition_id,
        competition_code,
        name as competition_name,
        type as competition_type,
        sub_type as competition_sub_type,
        country_id,
        country_name,
        domestic_league_code,
        confederation,
        cast(total_clubs as integer) as total_clubs,
        url
    from source
)

select * from renamed
