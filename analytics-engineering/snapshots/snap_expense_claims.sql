{% snapshot snap_expense_claims %}
{{
    config(
      unique_key='claim_id',
      strategy='timestamp',
      updated_at='effective_at'
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
    _sdc_deleted_at is not null as is_deleted,
    greatest(coalesce(updated_at, _sdc_extracted_at), _sdc_deleted_at) as effective_at
from {{ ref('stg_expense_claims') }}
qualify row_number() over (
    partition by claim_id
    order by coalesce(_sdc_deleted_at, _sdc_extracted_at) desc, updated_at desc
) = 1

{% endsnapshot %}
