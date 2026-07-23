with

value_trajectory as (
    select * from {{ ref('int_wikipedia_transfers__value_trajectory') }}
),

champions as (
    select * from {{ ref('int_competitions__season_champions') }}
),

-- Only "out" rows have a real tenure to count titles over — an "in" row's
-- spell hasn't started yet (same restriction as value_gained_during_tenure /
-- fee_vs_last_valuation on fct_wikipedia_transfer).
--
-- value_at_arrival_date is itself an approximation of the real signing date
-- (the earliest known market valuation snapshot at this club, not the actual
-- transfer date — see int_wikipedia_transfers__value_trajectory), so a title
-- won in the months between the real signing and that first valuation
-- snapshot would be missed here. Inherited limitation, not a new one — see
-- ARCHITECTURE.md decision 16.
titles_during_tenure as (
    select
        value_trajectory.club_id,
        value_trajectory.player_name,
        value_trajectory.direction,
        value_trajectory.transfer_date,
        champions.title_type
    from value_trajectory
    inner join champions
        on
            value_trajectory.club_id = champions.champion_club_id
            and value_trajectory.value_at_arrival_date <= champions.title_date
            and value_trajectory.transfer_date > champions.title_date
    where
        value_trajectory.direction = 'out'
        and value_trajectory.value_at_arrival_date is not null
)

select
    club_id,
    player_name,
    direction,
    transfer_date,
    count_if(title_type = 'league') as league_titles_during_tenure,
    count_if(title_type = 'cup') as cup_titles_during_tenure
from titles_during_tenure
group by club_id, player_name, direction, transfer_date
