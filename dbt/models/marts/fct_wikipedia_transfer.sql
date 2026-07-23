with

transfers as (
    select * from {{ ref('stg_wikipedia_transfers__club_transfers') }}
),

value_trajectory as (
    select * from {{ ref('int_wikipedia_transfers__value_trajectory') }}
),

titles as (
    select * from {{ ref('int_wikipedia_transfers__titles_during_tenure') }}
),

joined as (
    select
        transfers.club_id,
        transfers.club_name,
        transfers.season,
        transfers.direction,
        transfers.transfer_date,
        transfers.player_name,
        transfers.player_wiki_title,
        transfers.other_club_name,
        transfers.transfer_type,
        transfers.fee_amount,
        transfers.fee_currency,
        transfers.source_page,
        players.image_url as player_image_url,
        value_trajectory.value_at_arrival,
        value_trajectory.value_at_arrival_date,
        value_trajectory.value_at_departure,
        value_trajectory.value_at_departure_date,
        titles.league_titles_during_tenure,
        titles.cup_titles_during_tenure
    from transfers
    left join value_trajectory
        on
            transfers.club_id = value_trajectory.club_id
            and transfers.player_name = value_trajectory.player_name
            and transfers.direction = value_trajectory.direction
            and transfers.transfer_date = value_trajectory.transfer_date
    left join {{ ref('dim_player') }} as players on value_trajectory.player_id = players.player_id
    left join titles
        on
            transfers.club_id = titles.club_id
            and transfers.player_name = titles.player_name
            and transfers.direction = titles.direction
            and transfers.transfer_date = titles.transfer_date
)

select
    *,
    -- how much the player's value grew (or shrank) while at this specific
    -- club, independent of what the club originally paid for them (missing
    -- for the large majority of these players — see ARCHITECTURE.md decision
    -- 15). Only meaningful for "out" rows: an "in" row's tenure hasn't
    -- happened yet, so value_at_arrival and value_at_departure would both
    -- just reflect the moment of arrival.
    case
        when direction = 'out' then value_at_departure - value_at_arrival
    end as value_gained_during_tenure,
    -- did the selling club get more or less than the player's own last known
    -- valuation? Only defined when both a sale fee (best-effort, often
    -- missing) and a prior valuation at this club exist.
    case
        when direction = 'out' then fee_amount - value_at_departure
    end as fee_vs_last_valuation
from joined
