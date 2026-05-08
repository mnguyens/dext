{{  config(
        materialized='view'
        , unique_key=['line_item_id', 'valid_from']
    )
}}

select
    line_item_id,
    claim_id,
    description,
    amount,
    currency,
    category,
    receipt_url,
    created_at,
    updated_at,
    is_deleted,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to
from {{ ref('snap_expense_line_items') }}
