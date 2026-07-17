-- Un montant de transfert ne peut pas être négatif (nul = prêt ou transfert libre, accepté).
select *
from {{ ref('stg_transfermarkt__transfers') }}
where transfer_fee < 0
