with

transfers as (
    select * from {{ ref('stg_transfermarkt__transfers') }}
),

spells as (
    select * from {{ ref('int_players__club_spells') }}
),

performance as (
    select * from {{ ref('int_transfers__performance_during_spell') }}
),

market_value_at_spell_end as (
    select * from {{ ref('int_transfers__market_value_at_spell_end') }}
),

joined as (
    select
        transfers.transfer_id,
        transfers.player_id,
        transfers.from_club_id,
        transfers.to_club_id,
        transfers.transfer_date,
        transfers.transfer_season,
        transfers.transfer_fee,
        transfers.market_value_in_eur as market_value_at_transfer,
        spells.spell_end_date,
        spells.is_current_spell,
        market_value_at_spell_end.market_value_at_spell_end,
        market_value_at_spell_end.market_value_at_spell_end_date,
        performance.matches_played as matches_played_during_spell,
        performance.goals as goals_during_spell,
        performance.assists as assists_during_spell,
        performance.minutes_played as minutes_played_during_spell,
        performance.yellow_cards as yellow_cards_during_spell,
        performance.red_cards as red_cards_during_spell
    from transfers
    inner join spells on transfers.transfer_id = spells.transfer_id
    left join performance on transfers.transfer_id = performance.transfer_id
    left join market_value_at_spell_end on transfers.transfer_id = market_value_at_spell_end.transfer_id
),

final as (
    select
        *,
        (market_value_at_spell_end - market_value_at_transfer - transfer_fee)
        / nullif(transfer_fee, 0) as roi_financier,
        -- unlike roi_financier, this is a subtraction (not a ratio), so it stays
        -- defined even at transfer_fee = 0 (a confirmed free transfer per the
        -- source data's own convention — null means unknown fee, 0 means free).
        market_value_at_spell_end - market_value_at_transfer - transfer_fee
            as value_gained_absolute,
        transfer_fee
        / nullif(goals_during_spell + assists_during_spell, 0) as cost_per_goal_contribution
    from joined
)

select * from final
