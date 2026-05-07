{{  config(
        materialized='view'
        , unique_key='line_item_id'
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
    _sdc_extracted_at,
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_expense_line_items') }}
qualify row_number() over (
    partition by line_item_id
    order by _sdc_extracted_at desc, updated_at desc
) = 1
