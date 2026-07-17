with

source as (
    select * from {{ source('transfermarkt', 'countries') }}
),

renamed as (
    select
        country_id,
        country_name,
        country_code,
        confederation,
        cast(total_clubs as integer) as total_clubs,
        cast(total_players as integer) as total_players,
        average_age,
        url
    from source
)

select * from renamed
