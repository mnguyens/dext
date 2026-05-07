{{  config(
        materialized='table'
        , unique_key='employee_id'
    ) 
}}

select
    employee_id,
    full_name,
    email,
    department,
    cost_centre,
    employment_status = 'terminated' as is_terminated,
    manager_id,
    created_at,
    updated_at,
    is_deleted
from {{ ref('int_employees_current') }}
