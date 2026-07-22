with

wiki_transfers as (
    select * from {{ ref('stg_wikipedia_transfers__club_transfers') }}
),

valuations as (
    select * from {{ ref('stg_transfermarkt__player_valuations') }}
),

-- fct_wikipedia_transfer has no player_id (Wikipedia gives only a name) — the
-- selling/buying club is known precisely (it's the page we scraped), so
-- requiring a name match AND at least one valuation recorded at that specific
-- club resolves almost every case: common-name collisions in dim_player
-- (10 players named "Eduardo", etc.) essentially never share the same club.
-- Real ambiguity (rare) is broken deterministically below, not hidden.
--
-- Matches on current_club_name, not current_club_id: checked directly and
-- current_club_id is broken in this source table — it's pinned to the
-- player's most recent club on *every* historical row, not the club they
-- were actually at on that valuation date (verified on Griezmann: a 2010
-- valuation while he played for Real Sociedad carries current_club_id = 13,
-- which is Atlético Madrid's id, his most recent club as of the last
-- scrape — current_club_name correctly says "Real Sociedad" on that same
-- row). Matching on the id would have silently attributed a player's entire
-- career value growth to whichever club they happen to play for now.
candidates as (
    select
        w.club_id,
        w.club_name,
        w.player_name,
        w.direction,
        w.transfer_date,
        p.player_id
    from wiki_transfers as w
    inner join {{ ref('dim_player') }} as p on lower(p.player_name) = lower(w.player_name)
    where
        exists (
            select 1 from valuations as pv
            where pv.player_id = p.player_id and pv.current_club_name = w.club_name
        )
    qualify row_number() over (
        partition by w.club_id, w.player_name, w.direction, w.transfer_date
        order by p.player_id
    ) = 1
),

-- Earliest and latest known valuation while at this specific club, up to the
-- transfer date — a proxy for "value when they arrived" / "value when they
-- left" that doesn't need the original acquisition transfer record at all
-- (which is missing for the large majority of these players, verified
-- directly: e.g. Marc Cucurella has zero rows in fct_transfer despite a
-- well-documented real transfer history — see ARCHITECTURE.md decision 15).
ranked_valuations as (
    select
        c.club_id,
        c.player_name,
        c.direction,
        c.transfer_date,
        c.player_id,
        pv.valuation_date,
        pv.market_value_in_eur,
        row_number() over (
            partition by c.club_id, c.player_id order by pv.valuation_date asc
        ) as rn_earliest,
        row_number() over (
            partition by c.club_id, c.player_id order by pv.valuation_date desc
        ) as rn_latest
    from candidates as c
    inner join valuations as pv
        on
            c.player_id = pv.player_id
            and c.club_name = pv.current_club_name
            and c.transfer_date >= pv.valuation_date
)

select
    club_id,
    player_name,
    direction,
    transfer_date,
    player_id,
    max(case when rn_earliest = 1 then market_value_in_eur end) as value_at_arrival,
    max(case when rn_earliest = 1 then valuation_date end) as value_at_arrival_date,
    max(case when rn_latest = 1 then market_value_in_eur end) as value_at_departure,
    max(case when rn_latest = 1 then valuation_date end) as value_at_departure_date
from ranked_valuations
group by 1, 2, 3, 4, 5
