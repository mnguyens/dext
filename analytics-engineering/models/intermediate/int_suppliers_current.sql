{{  config(
        materialized='view'
        , unique_key='supplier_id'
    ) 
}}

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
    _sdc_deleted_at is not null as is_deleted
from {{ ref('stg_suppliers') }}
qualify row_number() over (
    partition by supplier_id
    order by _sdc_extracted_at desc, updated_at desc
) = 1