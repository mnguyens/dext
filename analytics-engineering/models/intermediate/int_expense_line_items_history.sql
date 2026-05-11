{{ config(
        materialized='incremental',
        unique_key=['line_item_id', 'valid_from']
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
    _sdc_extracted_at as valid_from,
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_expense_line_items') }}

{% if is_incremental() %}
    where _sdc_extracted_at > (select max(valid_from) from {{ this }})
{% endif %}
