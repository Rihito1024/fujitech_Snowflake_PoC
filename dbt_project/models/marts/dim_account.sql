-- 顧客アカウントディメンション
select
    account_id,
    account_name,
    account_type,
    parent_account_id,
    billing_city,
    billing_state,
    billing_postal_code,
    billing_country,
    shipping_city,
    shipping_state,
    shipping_postal_code,
    shipping_country

from {{ ref('stg_account') }}
