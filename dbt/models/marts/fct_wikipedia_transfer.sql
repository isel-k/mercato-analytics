with

transfers as (
    select * from {{ ref('stg_wikipedia_transfers__club_transfers') }}
)

select
    club_id,
    club_name,
    season,
    direction,
    transfer_date,
    player_name,
    player_wiki_title,
    other_club_name,
    transfer_type,
    fee_amount,
    fee_currency,
    source_page
from transfers
