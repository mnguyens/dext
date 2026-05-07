{{ config(materialized='view') }}

select
    supplier_id,
    supplier_name,
    category,
    country,
    is_active,
    vat_number,
    created_at,
    updated_at,
    _sdc_extracted_at,
    _sdc_deleted_at
from {{ ref('raw_suppliers') }}
