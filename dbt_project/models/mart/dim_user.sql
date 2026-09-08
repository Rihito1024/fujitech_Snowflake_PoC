-- ユーザーディメンション（商談担当者情報）
select
    user_id,
    username,
    full_name,
    first_name,
    last_name,
    company_name,
    division,
    department,
    title,
    city,
    state,
    postal_code

from {{ ref('stg_user') }}
