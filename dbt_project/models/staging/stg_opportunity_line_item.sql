-- 商談品目データのクレンジング済みテーブル（削除済みレコード除外）
with source as (

    select * from {{ source('flatpad_bronze', 'opportunitylineitem') }}

),

renamed as (

    select
        Id                                                   as line_item_id,
        OpportunityId                                         as opportunity_id,
        Product2Id                                            as product_id,
        PricebookEntryId                                      as pricebook_entry_id,
        ProductCode                                           as product_code,
        Name                                                  as product_name,
        Description                                           as description,
        -- Quantity                                           as quantity,  -- 元コードでコメントアウト。Quantity__c を使用
        Discount                                              as discount,
        cast(UnitPrice as decimal(18,2))                      as unit_price,
        cast(ListPrice as decimal(18,2))                      as list_price,
        cast(Subtotal as decimal(18,2))                       as subtotal,
        cast(TotalPrice as decimal(18,2))                     as total_price,
        cast(CurrentContractAmount__c as decimal(18,2))       as current_contract_amount,
        cast(BPREstimatedAmount__c as decimal(18,2))          as bpr_estimated_amount,
        cast(OfferedAmount__c as decimal(18,2))                as offered_amount,
        cast(EstimatedAmount__c as decimal(18,2))              as estimated_amount,
        cast(Profit__c as decimal(18,2))                       as profit,
        ProfitRatio__c                                         as profit_ratio,
        MLRatio__c                                              as ml_ratio,
        QuotationRatio__c                                       as quotation_ratio,
        cast(IncreaseDecrease__c as decimal(18,2))              as increase_decrease,
        Quantity__c                                             as quantity,
        WorkNumber__c                                           as work_number,
        Building__c                                             as building,
        BuildingID__c                                           as building_id,
        Opportunity_Building__c                                 as opportunity_building,
        DeliveryModelName__c                                    as delivery_model_name,
        BPRModel1__c                                            as bpr_model,
        OpportunityRecordTypedev__c                             as opportunity_record_type,
        BusinessSheetCode__c                                    as business_sheet_code,
        SortOrder                                               as sort_order,
        ServiceDate                                             as service_date,
        CreatedDate                                             as created_date,
        LastModifiedDate                                        as last_modified_date

    from source
    where IsDeleted = false
    -- and ProfitRatio__c > 0  -- 元コードでコメントアウト

)

select * from renamed
