{{
    config(
        cluster_by=['"案件ID"']
    )
}}

-- 商談品目ワイドテーブル（ファクト＋全ディメンション結合済み）- BI抽出用
with fact as (
    select * from {{ ref('fact_opportunity_line_item') }}
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

dim_building as (
    select * from {{ ref('dim_building') }}
),

-- 商品ディメンション（列名衝突を避けるため競合列を事前alias）
dim_product_renamed as (
    select
        product_id,
        product_code as dp_product_code,
        product_name as dp_product_name,
        family       as product_family,
        is_active    as product_is_active,
        is_archived  as product_is_archived
    from {{ ref('dim_product') }}
),

-- 設計事務所ディメンション（dim_accountを別名で再利用）
dim_design as (
    select
        account_id   as design_account_id,
        account_name as design_name
    from dim_account
),

-- 建物所有者ディメンション（dim_accountを別名で再利用）
dim_building_owner as (
    select
        account_id   as building_owner_account_id,
        account_name as building_owner_name
    from dim_account
),

-- bridge_opportunity_buildingを介して商談に紐づく建物を配列型で集約
-- opportunity_id単位で複数建物の所在地をarray_agg(distinct)（重複排除。collect_setに相当）
buildings_by_opportunity as (

    select
        bridge.opportunity_id,
        array_agg(distinct dim_building.address_state)  as building_states,
        array_agg(distinct dim_building.address_city)   as building_cities,
        array_agg(distinct dim_building.address_street) as building_streets
    from {{ ref('bridge_opportunity_building') }} as bridge
    left join dim_building
        on bridge.building_id = dim_building.building_id
    group by bridge.opportunity_id

),

-- クローズ日ディメンション
close_date_dim as (
    select
        date_key,
        year         as close_year,
        month        as close_month_num,
        quarter      as close_quarter_num,
        fiscal_year  as close_fiscal_year,
        day_name     as close_day_of_week,
        month_name   as close_month_name,
        year_month   as close_year_month,
        year_quarter as close_year_quarter,
        is_weekend   as close_is_weekend
    from {{ ref('dim_date') }}
),

-- 受注予定日ディメンション
contract_date_dim as (
    select
        date_key     as contract_date_key,
        year         as contract_year,
        month        as contract_month_num,
        fiscal_year  as contract_fiscal_year,
        year_month   as contract_year_month,
        year_quarter as contract_year_quarter
    from {{ ref('dim_date') }}
),

-- サービス日ディメンション
service_date_dim as (
    select
        date_key     as service_date_key,
        year         as service_year,
        month        as service_month_num,
        fiscal_year  as service_fiscal_year,
        year_month   as service_year_month,
        year_quarter as service_year_quarter
    from {{ ref('dim_date') }}
),

joined as (

    select
        -- === ファクトキー ===
        fact.line_item_id                                    as "品目ID",
        fact.opportunity_id                                  as "案件ID",
        fact.opportunity_name                                as "案件名",
        -- === 明細属性 ===
        fact.work_number                                     as "工事番号",
        fact.building                                        as "ビル",
        fact.building_id                                     as "ビルID",
        fact.opportunity_building                            as "商談ビル",
        fact.delivery_model_name                             as "配送モデル",
        fact.bpr_model                                       as "BPRモデル",
        fact.opportunity_record_type                         as "品目レコードタイプ",
        fact.business_sheet_code                             as "業務シートコード",
        fact.sort_order                                      as "表示順",
        fact.service_date                                    as "サービス日",
        -- === メジャー ===
        fact.quantity                                        as "台数",
        fact.discount                                        as "割引率",
        fact.unit_price                                      as "受注予定額",
        fact.list_price                                      as "定価",
        fact.subtotal                                        as "小計",
        fact.total_price                                     as "合計金額",
        fact.current_contract_amount                         as "現契約金額",
        fact.ml_amount                                       as "ML",
        fact.offered_amount                                  as "提示金額",
        fact.estimated_amount                                as "見積金額",
        fact.profit                                          as "利益",
        fact.profit_ratio                                    as "利益率",
        fact.ml_ratio                                        as "ML比率",
        fact.quotation_ratio                                 as "見積比率",
        fact.increase_decrease                               as "増減額",
        -- === 商談属性 ===
        fact.stage_name                                      as "フェーズ",
        fact.opportunity_type                                as "商談タイプ",
        fact.lead_source                                     as "リードソース",
        fact.forecast_category                               as "フォーキャストカテゴリ",
        fact.forecast_category_name                          as "フォーキャストカテゴリ名",
        fact.contract_forecast                               as "受注見込み・応札方針",
        fact.is_closed                                       as "クローズ済み",
        fact.is_won                                          as "受注済み",
        fact.close_date                                      as "クローズ日",
        fact.contract_expectation_date                       as "受注予定日",
        fact.construction_start_date                         as "建築着工日",
        fact.main_construction_start_date                    as "本体着工日",
        fact.installation_period                             as "据付工期",
        fact.contract_delivery_date                          as "契約納期",
        fact.last_activity_date                              as "最終活動日",
        fact.last_stage_change_date                          as "最終フェーズ変更日",
        -- === 商品属性 ===
        dim_product_renamed.dp_product_code                  as "商品コード",
        dim_product_renamed.dp_product_name                  as "商品名",
        fact.description                                     as "商品説明",
        dim_product_renamed.product_family                   as "商品ファミリー",
        dim_product_renamed.product_is_active                as "商品有効フラグ",
        dim_product_renamed.product_is_archived               as "商品アーカイブフラグ",
        -- === アカウント ===
        dim_account.account_name                             as "顧客名（契約先）",
        dim_account.account_type                             as "顧客タイプ（契約先）",
        dim_account.billing_city                             as "請求先市区町村",
        dim_account.billing_state                             as "請求先都道府県",
        dim_account.billing_country                          as "請求先国",
        -- === 設計事務所 ===
        dim_design.design_name                               as "設計事務所",
        -- === 建物所有者 ===
        dim_building_owner.building_owner_name                as "建物所有者（施主）",
        -- === 建物所在地（array型: bridge_opportunity_buildingで紐づく複数建物）===
        buildings_by_opportunity.building_states               as "建物都道府県",
        buildings_by_opportunity.building_cities               as "建物市区町村",
        buildings_by_opportunity.building_streets               as "建物住所",
        -- === 商談担当者 ===
        dim_user.full_name                                   as "主担当者",
        dim_user.title                                       as "主担当者役職",
        dim_user.division                                    as "主担当者部門",
        -- === 部署 ===
        dim_department.department_name                       as "主担当部署",
        dim_department.parent_department_name                as "上位部署名",
        dim_department.area_code                             as "受注エリア",
        dim_department.mother_store_code                     as "受注店所",
        -- === レコードタイプ ===
        dim_record_type.record_type_name                     as "レコードタイプ名",
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
        contract_date_dim.contract_year                      as "受注予定/年",
        contract_date_dim.contract_month_num                 as "受注予定/月",
        contract_date_dim.contract_fiscal_year                as "受注予定年度",
        contract_date_dim.contract_year_month                as "受注予定年月",
        contract_date_dim.contract_year_quarter               as "受注予定年四半期",
        -- === サービス日カレンダー ===
        service_date_dim.service_year                        as "サービス年",
        service_date_dim.service_month_num                   as "サービス月",
        service_date_dim.service_fiscal_year                  as "サービス会計年度",
        service_date_dim.service_year_month                   as "サービス年月",
        service_date_dim.service_year_quarter                 as "サービス年四半期",
        -- === 監査 ===
        fact.line_item_created_date                          as "品目作成日",
        fact.line_item_last_modified_date                    as "品目最終更新日"

    from fact
    left join dim_account
        on fact.account_id = dim_account.account_id
    left join dim_design
        on fact.design_id = dim_design.design_account_id
    left join dim_building_owner
        on fact.building_owner_id = dim_building_owner.building_owner_account_id
    left join buildings_by_opportunity
        on fact.opportunity_id = buildings_by_opportunity.opportunity_id
    left join dim_product_renamed
        on fact.product_id = dim_product_renamed.product_id
    left join dim_user
        on fact.owner_id = dim_user.user_id
    left join dim_department
        on fact.department_id = dim_department.department_id
    left join dim_record_type
        on fact.record_type_id = dim_record_type.record_type_id
    left join close_date_dim
        on fact.close_date = close_date_dim.date_key
    left join contract_date_dim
        on fact.contract_expectation_date = contract_date_dim.contract_date_key
    left join service_date_dim
        on fact.service_date = service_date_dim.service_date_key

)

select * from joined
