# ingestion/transfermarkt

Pipeline dlt pour la source Kaggle Transfermarkt (`davidcariboo/player-scores`).

Charge vers Snowflake `RAW.raw_transfermarkt`, en `merge` incrémental sur les clés naturelles (`player_id`, `transfer_id`, …).
