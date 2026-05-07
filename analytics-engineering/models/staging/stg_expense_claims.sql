{{ config(materialized='view') }}

select
    claim_id,
    employee_id,
    supplier_id,
    cast(total_amount as numeric(20, 2)) as total_amount,
    currency,
    status,
    submitted_at,
    created_at,
    updated_at,
    _sdc_extracted_at,
    _sdc_deleted_at
from {{ ref('raw_expense_claims') }}
