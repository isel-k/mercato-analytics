with

teams as (
    select * from {{ ref('stg_footballdata__teams') }}
)

select
    team_id,
    team_name,
    team_short_name,
    team_code,
    stadium_name,
    area_name,
    coach_name,
    coach_nationality,
    founded_year
from teams
