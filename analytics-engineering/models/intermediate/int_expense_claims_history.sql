{{  config(
        materialized='view'
        , unique_key=['claim_id', 'valid_from']
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
    updated_at as valid_from,
    lead(updated_at) over (partition by claim_id order by updated_at) as valid_to,
    _sdc_extracted_at,
    row_number() over (partition by claim_id order by _sdc_extracted_at) as version_number,
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_expense_claims') }}
