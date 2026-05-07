{{ config(materialized='view') }}

select
    line_item_id,
    claim_id,
    description,
    cast(amount as numeric(20, 2)) as amount,
    currency,
    category,
    receipt_url,
    created_at,
    updated_at,
    _sdc_extracted_at,
    _sdc_deleted_at
from {{ ref('raw_expense_line_items') }}
