-- One row per change for claims and their line items.

{{ config(
        materialized='table',
        unique_key=['claim_id', 'entity_type', 'entity_id', 'changed_field', 'valid_from']
    ) 
}}

with claim_history as (
   select
        claim_id,
        valid_from,
        status,
        total_amount,
        is_deleted,
        lag(status) over w as prev_status,
        lag(total_amount) over w as prev_total_amount,
        lag(is_deleted) over w as prev_is_deleted,
        lag(valid_from) over w as prev_valid_from
   from {{ ref('int_expense_claims_history') }}
   window w as (partition by claim_id order by valid_from)
),

line_history as (
   select
        line_item_id,
        claim_id,
        valid_from,
        amount,
        category,
        description,
        receipt_url,
        is_deleted,
        lag(amount) over w as prev_amount,
        lag(category) over w as prev_category,
        lag(description) over w as prev_description,
        lag(receipt_url) over w as prev_receipt_url,
        lag(is_deleted) over w as prev_is_deleted,
        lag(valid_from) over w as prev_valid_from
   from {{ ref('int_expense_line_items_history') }}
   window w as (partition by line_item_id order by valid_from)
),

claim_first_approved as (
   select
        claim_id,
        min(case when status = 'approved' and not is_deleted then valid_from end) as first_approved_at
   from {{ ref('int_expense_claims_history') }}
   group by 1
),

claim_changes as (
   select
        claim_id,
        'claim' as entity_type,
        claim_id as entity_id,
        'status' as changed_field,
        prev_status as previous_value,
        status as current_value,
        valid_from
   from claim_history
   where prev_valid_from is not null
      and status is distinct from prev_status

   union all

   select
        claim_id,
        'claim',
        claim_id,
        'total_amount',
        cast(prev_total_amount as varchar),
        cast(total_amount as varchar),
        valid_from
   from claim_history
   where prev_valid_from is not null
      and total_amount is distinct from prev_total_amount

   union all

   select
        claim_id,
        'line_item',
        claim_id,
        'added', 
        null, 
        null,
        valid_from
   from line_history
   where prev_valid_from is null

   union all

   select
        claim_id,
        'claim',
        claim_id,
        'deleted', 
        null, 
        null,
        valid_from
   from claim_history
   where is_deleted and not coalesce(prev_is_deleted, false)
),

line_changes as (
   select
        claim_id,
        'line_item' as entity_type,
        line_item_id as entity_id,
        'amount' as changed_field,
        cast(prev_amount as varchar) as previous_value,
        cast(amount as varchar) as current_value,
        valid_from
   from line_history
   where prev_valid_from is not null
      and amount is distinct from prev_amount

   union all

   select
        claim_id,
        'line_item',
        line_item_id,
        'category',
        prev_category,
        category,
        valid_from
   from line_history
   where prev_valid_from is not null
      and category is distinct from prev_category

   union all

   select
        claim_id,
        'line_item',
        line_item_id,
        'description',
        prev_description,
        description,
        valid_from
   from line_history
   where prev_valid_from is not null
      and description is distinct from prev_description

   union all

   select
        claim_id,
        'line_item',
        line_item_id,
        'receipt_url',
        prev_receipt_url,
        receipt_url,
        valid_from
   from line_history
   where prev_valid_from is not null
      and receipt_url is distinct from prev_receipt_url
   
   union all

   select
        claim_id,
        'line_item',
        line_item_id,
        'added', null, 
        null,
        valid_from
   from line_history
   where prev_valid_from is null

   union all

   select
        claim_id,
        'line_item',
        line_item_id,
        'deleted', 
        null, 
        null,
        valid_from
   from line_history
   where is_deleted and not coalesce(prev_is_deleted, false)
),

all_changes as (
    select * from claim_changes

    union all
    
    select * from line_changes
)

select
    c.claim_id,
    c.entity_type,
    c.entity_id,
    c.changed_field,
    c.previous_value,
    c.current_value,
    c.valid_from,
    a.first_approved_at,
    a.first_approved_at is not null and c.valid_from > a.first_approved_at as changed_after_first_approval,
    -- The only status change after approval that is *not* a compliance signal
    -- is the approved -> paid transition. Everything else (amount edits, line
    -- changes, status regressions) counts as a material change for Q4.
    c.changed_field = 'status'
        and c.previous_value = 'approved'
        and c.current_value = 'paid' as is_approved_to_paid
from all_changes c
left join claim_first_approved a using (claim_id)
