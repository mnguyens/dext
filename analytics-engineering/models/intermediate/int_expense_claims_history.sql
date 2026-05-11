{{ config(
        materialized='incremental',
        unique_key=['claim_id', 'valid_from']
    )
}}

select
    claim_id,
    employee_id,
    supplier_id,
    total_amount,
    currency,
    status,
    submitted_at,
    created_at,
    updated_at,
    _sdc_extracted_at as valid_from,
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_expense_claims') }}

{% if is_incremental() %}
    where _sdc_extracted_at > (select max(valid_from) from {{ this }})
{% endif %}
