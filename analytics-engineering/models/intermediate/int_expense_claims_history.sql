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
    updated_at,
    is_deleted,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to
from {{ ref('snap_expense_claims') }}
