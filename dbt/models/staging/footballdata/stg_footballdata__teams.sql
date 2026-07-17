with

source as (
    select * from {{ source('footballdata', 'teams') }}
),

renamed as (
    select
        id as team_id,
        name as team_name,
        short_name as team_short_name,
        tla as team_code,
        address,
        website,
        cast(founded as integer) as founded_year,
        club_colors,
        venue as stadium_name,
        area__id as area_id,
        area__name as area_name,
        coach__id as coach_id,
        coach__name as coach_name,
        coach__nationality as coach_nationality,
        cast(coach__contract__start as date) as coach_contract_start,
        cast(coach__contract__until as date) as coach_contract_until
    from source
)

select * from renamed
