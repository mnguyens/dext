{{  config(
        materialized='view'
        , unique_key='employee_id'
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
    updated_at,
    _sdc_extracted_at,
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_employees') }}
qualify row_number() over (
    partition by employee_id
    order by _sdc_extracted_at desc, updated_at desc
) = 1

