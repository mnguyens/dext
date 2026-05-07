{{  config(
        materialized='table'
        , unique_key='supplier_id'
    ) 
}}

select
    supplier_id,
    supplier_name,
    category as supplier_category,
    country,
    is_active,
    vat_number,
    created_at,
    updated_at,
    is_deleted
from {{ ref('int_suppliers_current') }}
