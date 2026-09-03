-- 資産ディメンション（エレベーター・エスカレーター等の納入号機情報）
select
    asset_id,
    asset_name,
    serial_number,
    status,
    product_code,
    product_family,
    product_name,
    install_date,
    manufacture_date,
    purchase_date,
    usage_end_date,
    is_competitor_product,
    account_id

from {{ ref('stg_asset') }}
