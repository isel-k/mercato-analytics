-- Une valeur marchande ne peut pas être négative, quelle que soit la table source.
select
    player_id,
    market_value_in_eur,
    'player_valuations' as source_model
from {{ ref('stg_transfermarkt__player_valuations') }}
where market_value_in_eur < 0

union all

select
    player_id,
    market_value_in_eur,
    'players' as source_model
from {{ ref('stg_transfermarkt__players') }}
where market_value_in_eur < 0

union all

select
    player_id,
    highest_market_value_in_eur as market_value_in_eur,
    'players_highest' as source_model
from {{ ref('stg_transfermarkt__players') }}
where highest_market_value_in_eur < 0

union all

select
    player_id,
    market_value_in_eur,
    'transfers' as source_model
from {{ ref('stg_transfermarkt__transfers') }}
where market_value_in_eur < 0
