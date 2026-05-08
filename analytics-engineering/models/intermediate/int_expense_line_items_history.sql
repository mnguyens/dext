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
    updated_at as valid_from,
    lead(updated_at) over (partition by line_item_id order by updated_at) as valid_to,
    _sdc_extracted_at,
    row_number() over (partition by line_item_id order by _sdc_extracted_at) as version_number,
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_expense_line_items') }}
