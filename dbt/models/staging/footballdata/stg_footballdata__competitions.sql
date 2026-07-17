with

source as (
    select * from {{ source('footballdata', 'competitions') }}
),

renamed as (
    select
        id as competition_id,
        name as competition_name,
        code as competition_code,
        type as competition_type,
        plan,
        cast(number_of_available_seasons as integer) as number_of_available_seasons,
        area__id as area_id,
        area__name as area_name,
        area__code as area_code,
        current_season__id as current_season_id,
        cast(current_season__start_date as date) as current_season_start_date,
        cast(current_season__end_date as date) as current_season_end_date,
        cast(current_season__current_matchday as integer) as current_season_matchday
    from source
)

select * from renamed
