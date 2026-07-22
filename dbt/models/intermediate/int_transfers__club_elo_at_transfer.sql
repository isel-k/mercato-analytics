-- materialized as view (not the layer default ephemeral) so unit tests on
-- fct_transfer can introspect this model's columns for their fixtures.
{{ config(materialized='view') }}

with

transfers as (
    select
        transfer_id,
        transfer_date,
        from_club_id,
        to_club_id
    from {{ ref('stg_transfermarkt__transfers') }}
),

club_elo_mapping as (
    select * from {{ ref('clubelo_club_mapping') }}
),

ratings as (
    select * from {{ ref('stg_clubelo__ratings') }}
),

-- ClubElo only covers European football (see ARCHITECTURE.md) and the name
-- mapping itself isn't 100% recall even within Europe, so both joins below are
-- necessarily partial — a transfer with no Elo on one or both sides just gets
-- null, same pattern as the existing from_club_id/to_club_id -> dim_club gap.
from_elo_candidates as (
    select
        transfers.transfer_id,
        ratings.elo,
        -- prefer the period that actually contains transfer_date; fall back to
        -- the closest period by date if the club has a gap or the transfer
        -- predates/postdates ClubElo's tracked history for it.
        row_number() over (
            partition by transfers.transfer_id
            order by
                case
                    when
                        transfers.transfer_date
                        between ratings.rating_from_date and ratings.rating_to_date
                        then 0
                    else 1
                end,
                abs(datediff(day, transfers.transfer_date, ratings.rating_from_date))
        ) as rn
    from transfers
    inner join club_elo_mapping on transfers.from_club_id = club_elo_mapping.club_id
    inner join ratings
        on
            club_elo_mapping.clubelo_club = ratings.clubelo_club
            and club_elo_mapping.clubelo_country = ratings.clubelo_country
),

to_elo_candidates as (
    select
        transfers.transfer_id,
        ratings.elo,
        row_number() over (
            partition by transfers.transfer_id
            order by
                case
                    when
                        transfers.transfer_date
                        between ratings.rating_from_date and ratings.rating_to_date
                        then 0
                    else 1
                end,
                abs(datediff(day, transfers.transfer_date, ratings.rating_from_date))
        ) as rn
    from transfers
    inner join club_elo_mapping on transfers.to_club_id = club_elo_mapping.club_id
    inner join ratings
        on
            club_elo_mapping.clubelo_club = ratings.clubelo_club
            and club_elo_mapping.clubelo_country = ratings.clubelo_country
)

select
    transfers.transfer_id,
    from_elo_candidates.elo as from_club_elo,
    to_elo_candidates.elo as to_club_elo
from transfers
left join from_elo_candidates on transfers.transfer_id = from_elo_candidates.transfer_id and from_elo_candidates.rn = 1
left join to_elo_candidates on transfers.transfer_id = to_elo_candidates.transfer_id and to_elo_candidates.rn = 1
