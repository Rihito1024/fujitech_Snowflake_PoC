-- 商談ファクトテーブル（ディメンションキー＋メジャー）
select
    -- サロゲートキー
    opportunity_id,
    -- ディメンション外部キー
    account_id,
    owner_id as user_id,
    record_type_id,
    department_id,
    close_date as close_date_key,
    -- メジャー（数値）
    amount,
    probability,
    expected_revenue,
    contract_expectation_amount,
    total_quantity,
    -- デジェネレートディメンション（分析用属性）
    opportunity_name,
    stage_name,
    opportunity_type,
    lead_source,
    forecast_category,
    forecast_category_name,
    is_closed,
    is_won,
    contract_expectation_date,
    created_date,
    last_modified_date,
    last_activity_date,
    last_stage_change_date

from {{ ref('stg_opportunity') }}
