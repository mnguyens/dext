# Implementation Notes

## Overview
2 approaches:
- in `main`: model that works for this exercise as the data is from seeds which already contain all the historical edits and status journeys that can address the business questions correctly; 
- in `snapshot-model`: another modelling approach using snapshot for CDC in live production environment.

## Modeling approach
### Three layers (`main`):
- **`staging/`** (views) — one model per raw seed. Contains every CDC version per entity. No filtering, no dedup.
- **`intermediate/`** (views) — two shapes per CDC entity:
  - `int_<entity>_current`: latest version per natural key. Deleted records are retained and flagged via `is_deleted` so downstream marts can choose whether to filter them. 
  - `int_<entity>_history` (claims, line items): every version with `valid_from` / `valid_to`.
- **`marts/`** (tables) — `dim_employees`, `dim_suppliers`, `fct_expense_claims` (claim level grain), `fct_expense_claim_audit_log` (one row for each claim/line_item change per claim). 

Note: I skipped a fact table for line_items because none of the listed business questions require line item grain — Q1, Q2, Q3 and Q5 are claim-level, and Q4 which may need line-level changes are available in the audit log table.

### Scaling with snapshots for CDC in production (`snapshot-model`)

The `_history` views re-derive history from raw CDC versions on every `dbt run`. Fine on this seed; doesn't scale. Converting to dbt snapshots changes the lineage shape:

- In `main` **history derived from raw:**
```
seeds/raw_expense_claims.csv
  └→ stg_expense_claims (view)
       ├→ int_expense_claims_current (view: dedup latest per claim)
       │    └→ fct_expense_claims (table)
       └→ int_expense_claims_history (view: lead() window over raw)
            └→ fct_expense_claim_audit_log (table)
```

- In `snapshot-model` **with dbt snapshots:**
```
source: singer.raw_* 
  └→ stg_*                       (view: cast/clean only)
       ├→ snap_*                 (SCD2 table; dedupes inline to one row per natural key)
       │    └→ int_*_history     (view wrapping the snapshot)
       │         └→ fct_expense_claim_audit_log  (incremental)
       └→ int_*_current          (view: dedup latest per claim)
            ├→ dim_*             (table)
            └→ fct_expense_claims (table)
```

> **Known issue:** on this branch `dbt snapshot` only captures current state per run, so the seed's CDC history is lost. In production it would accumulate over time; for this take-home exercise with seeds, `main` answers Q4/Q5 more correctly.

## CDC handling
**Latest version per entity** for `int_<entity>_current` tables
- Uses window function to get the latest update per key `qualify row_number() over (partition by <entity_key> order by _sdc_extracted_at desc) = 1`.
- Deleted records are kept with `is_deleted = true`

**History versions** in `int_<entity>_history`
- In `main`
     - Uses updated_at and lead(updated_at) partitioned by key for `valid_from` and `valid_to` for each version update.
     - Has version_number for each update
     - Deleted records are kept with `is_deleted = true`
- In `snapshot-model`: downstream from snap_*
 
**Audit log generation**:
- Log changes for each tracked attribute (status, total_amount on claims; amount, category, description, receipt_url on line items), a UNION ALL query emits one row per version-to-version change using `LAG()`.

### Edge cases observed in the seed

- **Missing data**: claim_id **CLM-006** doesn't exist in `raw_expense_claims` while shows up in `raw_expense_line_items` with line_item_id **LI-007** and **LI-008**. A test should be able to address these cases.

- **Changes after claim is approved** e.g. **CLM-001** total amount edited 142.50 → 189.00, with corresponding LI-001 amount edit. The audit log table is able to capture this kind of change, flagged with `changed_after_first_approval AND NOT is_approved_to_paid`.

- **Missing/Removed data in new events** - an update incorrectly removes existing available data e.g. `LI-003` receipt_url exists at first but NULL in latest record.

- **Duplication** due to updated/extracted timestamp ties, this is NOT a current issue present in the seed, but they're possible from source, implementing a reliable tie-breaker would be helpful (e.g. LSN)

## Assumptions
- **Employee change department**: in case employee changes department, their historical claims should be linked to previous department as time of approval. However, current model does not address this as it is not an issue in existing data and the listed questions don't ask for it explicitly, however make sense to add in the model to get the correct department as-of approval time.
- **Claims deleted in source**: Keeping deleted claims in reporting layers with a flag `is_deleted = true` in case business want to see those and can decide whether to include/exclude them.
- **Changes after approval**: Change in status `approved → paid` is the one status change that happens after first approval but is not a compliance concern — it's the expected next lifecycle step. Other changes should be flagged.
- **Capturing all changes is one of the business requirements** for auditing / compliance, the audit log is tracking changes regarding `status`, `total_amount` on claims; `amount`, `category`, `description`, `receipt_url` on line items.
- **Multiple approval cycles** (e.g. `submitted → approved (day0) → submitted → approved (day+1)`): current `approved_at` uses the earliest approval date.
- **Deleted events**: `is_deleted` is set per CDC version, not retroactively — earlier versions stay `is_deleted = false` since the record genuinely existed then. Could be a question for compliance if they want to flag it in full history.
- Claim's total_amount in `raw_expense_claims` should reconcile with the sum of its line items in `raw_expense_line_items`.


## What I would do with more time
- Add additional dimenstion tables (e.g. dim_date, dim_fx_rate to handle different currencies if it's a case, etc.)
- Add tests:
    - Generic tests
    - If an update incorrectly removes existing available data (e.g. receipt, etc.)
    - If any claim exists in line item table but not in claim table, and vice versa.
    - If any claim's total_amount doesn't reconcile with the sum of its line items.


### Appendix

Run below queries to check answers for business questions:

**Q1 — Total approved and paid spend by employee department this month:**
```sql
select
    updated_at as date,
    employee_department,
    sum(case when latest_status = 'approved' then total_amount end) as approved_amount,
    max(case when latest_status = 'approved' then approved_at end) as approved_at,
    sum(case when latest_status = 'paid'     then total_amount end) as paid_amount,
    max(case when latest_status = 'paid'     then paid_at end) as paid_at
from marts.fct_expense_claims
where
    latest_status in ('approved', 'paid')
    -- and date_trunc('month', updated_at) = date_trunc('month', current_date)
group by all;
```

**Q2 — Claims awaiting payment:**
```sql
select
    claim_id,
    latest_status,
    total_amount,
    is_awaiting_payment
from dext.marts.fct_expense_claims
where is_awaiting_payment;
```

**Q3 — Spend breakdown by supplier category:**
```sql
select
    supplier_category,
    sum(total_amount) as spend,
    is_awaiting_payment
from dext.marts.fct_expense_claims
where latest_status in ('approved','paid')
group by all
order by 1;
```

**Q4 — Claims modified after first approval, and what changed:**
```sql
select
    claim_id,
    entity_type,
    changed_field,
    current_value,
    previous_value,
    first_approved_at,
    valid_from,
    changed_after_first_approval
from dext.marts.fct_expense_claim_audit_log
where changed_after_first_approval
    and not is_approved_to_paid;
```

**Q5 — Full status history for a given claim:**
```sql
select
    claim_id,
    changed_field,
    current_value,
    valid_from
from marts.fct_expense_claim_audit_log
where claim_id = 'CLM-003'
    and changed_field = 'status'
order by valid_from desc;
```
