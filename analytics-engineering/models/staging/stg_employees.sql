{{ config(materialized='view') }}

select
    employee_id,
    full_name,
    email,
    department,
    cost_centre,
    employment_status,
    manager_id,
    created_at,
    updated_at,
    _sdc_extracted_at,
    _sdc_deleted_at
from {{ ref('raw_employees') }}