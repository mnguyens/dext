{{  config(
        materialized='view'
        , unique_key=['employee_id', 'valid_from']
    ) 
}}

select
    employee_id,
    full_name,
    email,
    department,
    cost_centre,
    employment_status,
    manager_id,
    created_at,
    updated_at as valid_from,
    lead(updated_at) over (partition by employee_id order by updated_at) as valid_to,
    _sdc_extracted_at,
    row_number() over (partition by employee_id order by _sdc_extracted_at) as version_number,
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_employees') }}
