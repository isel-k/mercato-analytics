with

source as (
    select * from {{ source('wikipedia_transfers', 'club_transfers') }}
),

renamed as (
    select
        club_id,
        club_name,
        season,
        direction,
        player_wiki_title,
        transfer_type,
        fee_text,
        source_page,
        -- footnote markers ("Monaco[a]", "Jaheim Azzouz Scafe[a]") show up in
        -- player- and club-name cells too, not just dates — same fix, same
        -- root cause, applied everywhere text comes straight from a table cell.
        regexp_replace(player_name, '\\[.*?\\]', '') as player_name,
        regexp_replace(other_club_name, '\\[.*?\\]', '') as other_club_name,
        -- Wikipedia footnote markers ("15 June 2026[c]") land in the same cell
        -- as the date and break parsing entirely — found for real on Newcastle's
        -- page (Travis Hernes). Strip any trailing bracketed note before parsing.
        try_to_date(regexp_replace(date, '\\[.*?\\]', ''), 'DD MMMM YYYY') as transfer_date,
        -- fee_text is always "million"/"m" per the extraction regex (see
        -- ingestion/wikipedia_transfers/pipeline.py FEE_PATTERN), so *1,000,000
        -- puts this in the same raw-currency-unit convention as
        -- fct_transfer.transfer_fee. No currency conversion (fee_currency
        -- stays €/£/$ as reported) — that would need an FX rate dependency
        -- this project doesn't have, and silently assuming 1:1 would
        -- misrepresent non-euro fees.
        try_to_number(regexp_replace(fee_text, '[^0-9.]', ''), 10, 2) * 1000000 as fee_amount,
        case
            when fee_text like '€%' then 'EUR'
            when fee_text like '£%' then 'GBP'
            when fee_text like '$%' then 'USD'
        end as fee_currency
    from source
),

-- Defensive dedup: the same player has been seen twice on one page (Travis
-- Hernes on Newcastle's page — likely two overlapping wikitables, e.g. a
-- general "Out" list and a separate loan-specific one). Keep the most complete
-- row per natural key rather than let a partial duplicate fail uniqueness.
deduped as (
    select *
    from renamed
    qualify row_number() over (
        partition by club_id, player_name, direction, coalesce(transfer_date, '1900-01-01')
        order by (transfer_date is not null) desc, (transfer_type != '') desc
    ) = 1
)

select * from deduped
