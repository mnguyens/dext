{{  config(
        materialized='table'
        , unique_key='claim_id'
    )
}}

with claims as (
    select
        claim_id,
        employee_id,
        supplier_id,
        total_amount,
        currency,
        status,
        submitted_at,
        updated_at,
        is_deleted
    from {{ ref('int_expense_claims_current') }}
),

milestones as (
    select
        claim_id,
        min(case when status = 'approved' and not is_deleted then valid_from end) as approved_at,
        min(case when status = 'paid' and not is_deleted then valid_from end) as paid_at
    from {{ ref('int_expense_claims_history') }}
    group by 1
)

select
    c.claim_id,
    c.employee_id,
    e.full_name as employee_name,
    e.department as employee_department,
    c.supplier_id,
    s.supplier_name,
    s.supplier_category,
    c.total_amount,
    c.currency,
    c.status as latest_status,
    c.submitted_at,
    c.updated_at,
    m.approved_at,
    m.paid_at,
    c.status = 'approved' and m.paid_at is null as is_awaiting_payment,
    c.is_deleted
from claims c
left join {{ ref('dim_employees') }} e using (employee_id)
left join {{ ref('dim_suppliers') }} s using (supplier_id)
left join milestones m using (claim_id)
