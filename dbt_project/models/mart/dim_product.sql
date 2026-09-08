-- 商品ディメンション（商品コード・名称・ファミリー・有効状態等）
select
    product_id,
    product_name,
    product_code,
    description,
    is_active,
    family,
    is_archived,
    created_date,
    last_modified_date

from {{ ref('stg_product') }}
