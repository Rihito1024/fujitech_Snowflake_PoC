{{
    config(
        cluster_by=['"商談ID"']
    )
}}

-- 商談ワイドテーブル（ファクト＋全ディメンション結合済み）- Tableau等BI抽出用
with fact as (
    select * from {{ ref('fact_opportunity') }}
),

dim_account as (
    select * from {{ ref('dim_account') }}
),

dim_user as (
    select * from {{ ref('dim_user') }}
),

dim_department as (
    select * from {{ ref('dim_department') }}
),

dim_record_type as (
    select * from {{ ref('dim_record_type') }}
),

-- クローズ日ディメンション
close_date_dim as (
    select
        date_key,
        year        as close_year,
        month       as close_month_num,
        quarter     as close_quarter_num,
        fiscal_year as close_fiscal_year,
        day_name    as close_day_of_week,
        month_name  as close_month_name,
        year_month  as close_year_month,
        year_quarter as close_year_quarter,
        is_weekend  as close_is_weekend
    from {{ ref('dim_date') }}
),

-- 受注予定日ディメンション
contract_date_dim as (
    select
        date_key    as contract_date_key,
        fiscal_year as contract_fiscal_year,
        year_month  as contract_year_month,
        year_quarter as contract_year_quarter
    from {{ ref('dim_date') }}
),

joined as (

    select
        -- === ファクトキー・メジャー ===
        fact.opportunity_id                                as "商談ID",
        fact.opportunity_name                               as "商談名",
        fact.amount                                          as "金額",
        fact.probability                                     as "確度",
        fact.expected_revenue                                as "粗利金額",
        fact.contract_expectation_amount                     as "受注予定金額",
        fact.total_quantity                                  as "数量",
        -- === 商談属性 ===
        fact.stage_name                                      as "フェーズ",
        fact.opportunity_type                                as "商談タイプ",
        fact.lead_source                                     as "リードソース",
        fact.forecast_category                               as "フォーキャストカテゴリ",
        fact.forecast_category_name                          as "フォーキャストカテゴリ名",
        fact.is_closed                                       as "クローズ済み",
        fact.is_won                                          as "受注済み",
        fact.close_date_key                                  as "クローズ日",
        fact.contract_expectation_date                       as "受注予定日",
        fact.created_date                                    as "作成日",
        fact.last_modified_date                              as "最終更新日",
        fact.last_activity_date                              as "最終活動日",
        fact.last_stage_change_date                          as "最終フェーズ変更日",
        -- === アカウント ===
        dim_account.account_name                             as "顧客名",
        dim_account.account_type                             as "顧客タイプ",
        dim_account.billing_city                             as "請求先市区町村",
        dim_account.billing_state                             as "請求先都道府県",
        dim_account.billing_country                          as "請求先国",
        -- === 商談担当者 ===
        dim_user.full_name                                   as "担当者名",
        dim_user.title                                       as "担当者役職",
        dim_user.division                                    as "担当者部門",
        -- === 部署 ===
        dim_department.department_name                       as "部署名",
        dim_department.parent_department_name                as "上位部署名",
        dim_department.area_code                             as "エリアコード",
        dim_department.mother_store_code                     as "店所コード",
        -- === レコードタイプ ===
        dim_record_type.record_type_name                     as "レコードタイプ",
        -- === クローズ日カレンダー ===
        close_date_dim.close_year                            as "クローズ年",
        close_date_dim.close_month_num                       as "クローズ月",
        close_date_dim.close_quarter_num                     as "クローズ四半期",
        close_date_dim.close_fiscal_year                     as "クローズ会計年度",
        close_date_dim.close_day_of_week                     as "クローズ曜日",
        close_date_dim.close_month_name                      as "クローズ月名",
        close_date_dim.close_year_month                      as "クローズ年月",
        close_date_dim.close_year_quarter                    as "クローズ年四半期",
        close_date_dim.close_is_weekend                      as "クローズ日週末フラグ",
        -- === 受注予定日カレンダー ===
        contract_date_dim.contract_fiscal_year                as "受注予定会計年度",
        contract_date_dim.contract_year_month                 as "受注予定年月",
        contract_date_dim.contract_year_quarter                as "受注予定年四半期"

    from fact
    left join dim_account
        on fact.account_id = dim_account.account_id
    left join dim_user
        on fact.user_id = dim_user.user_id
    left join dim_department
        on fact.department_id = dim_department.department_id
    left join dim_record_type
        on fact.record_type_id = dim_record_type.record_type_id
    left join close_date_dim
        on fact.close_date_key = close_date_dim.date_key
    left join contract_date_dim
        on fact.contract_expectation_date = contract_date_dim.contract_date_key

)

select * from joined
