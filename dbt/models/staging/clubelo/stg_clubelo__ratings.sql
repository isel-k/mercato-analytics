with

source as (
    select * from {{ source('clubelo', 'ratings') }}
),

renamed as (
    select
        club as clubelo_club,
        country as clubelo_country,
        cast(level as integer) as division_level,
        cast(elo as float) as elo,
        cast(from_date as date) as rating_from_date,
        cast(to_date as date) as rating_to_date
    from source
)

select * from renamed
