{{
    config(
        cluster_by=['opportunity_id']
    )
}}

-- 商談品目ファクトテーブル（ヘッダ: stg_opportunity × 明細: stg_opportunity_line_item）
with header as (

    select * from {{ ref('stg_opportunity') }}

),

detail as (

    select * from {{ ref('stg_opportunity_line_item') }}

),

joined as (

    select
        -- === キー ===
        header.opportunity_id,
        detail.line_item_id,
        -- === ヘッダ属性（stg_opportunity） ===
        header.account_id,
        header.record_type_id,
        header.owner_id,
        header.department_id,
        header.design_id,
        header.building_owner_id,
        header.opportunity_name,
        header.stage_name,
        header.opportunity_type,
        header.lead_source,
        header.forecast_category,
        header.forecast_category_name,
        header.contract_forecast,
        header.is_closed,
        header.is_won,
        header.close_date,
        header.contract_expectation_date,
        header.construction_start_date,
        header.main_construction_start_date,
        header.installation_period,
        header.contract_delivery_date,
        header.last_activity_date,
        header.last_stage_change_date,
        -- === 明細属性（stg_opportunity_line_item） ===
        detail.product_id,
        detail.pricebook_entry_id,
        detail.product_code,
        detail.product_name,
        detail.description,
        detail.work_number,
        detail.building,
        detail.building_id,
        detail.opportunity_building,
        detail.delivery_model_name,
        detail.bpr_model,
        detail.opportunity_record_type,
        detail.business_sheet_code,
        detail.sort_order,
        detail.service_date,
        -- === メジャー（全て stg_opportunity_line_item から） ===
        detail.quantity,
        detail.discount,
        detail.unit_price,
        detail.list_price,
        detail.subtotal,
        detail.total_price,
        detail.current_contract_amount,
        detail.bpr_estimated_amount as ml_amount,
        detail.offered_amount,
        detail.estimated_amount,
        detail.profit,
        detail.profit_ratio,
        detail.ml_ratio,
        detail.quotation_ratio,
        detail.increase_decrease,
        -- === 監査 ===
        detail.created_date as line_item_created_date,
        detail.last_modified_date as line_item_last_modified_date

    from header
    left join detail on header.opportunity_id = detail.opportunity_id

)

select * from joined
