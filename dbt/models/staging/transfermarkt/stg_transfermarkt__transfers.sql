with

source as (
    select * from {{ source('transfermarkt', 'transfers') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(
            ['player_id', 'transfer_date', 'from_club_id', 'to_club_id']
        ) }} as transfer_id,
        player_id,
        player_name,
        cast(transfer_date as date) as transfer_date,
        transfer_season,
        from_club_id,
        from_club_name,
        to_club_id,
        to_club_name,
        transfer_fee,
        market_value_in_eur
    from source
)

select * from renamed
