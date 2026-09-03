-- 商談データのクレンジング済みテーブル（削除済みレコード除外）
with source as (

    select * from {{ source('flatpad_bronze', 'opportunity') }}

),

renamed as (

    select
        Id                                                    as opportunity_id,
        AccountId                                              as account_id,
        RecordTypeId                                           as record_type_id,
        OwnerId                                                as owner_id,
        MainCompanyDepartmentCharge__c                         as department_id,
        Design__c                                              as design_id,
        BuidingOwner__c                                        as building_owner_id,
        Name                                                   as opportunity_name,
        StageName                                              as stage_name,
        cast(Amount as decimal(18,2))                          as amount,
        Probability                                            as probability,
        cast(ExpectedRevenue as decimal(18,2))                 as expected_revenue,
        cast(ContractExpectationAmount__c as decimal(18,2))    as contract_expectation_amount,
        TotalOpportunityQuantity                               as total_quantity,
        CloseDate                                              as close_date,
        ContractExpectationDate__c                             as contract_expectation_date,
        ConstructionStartDate__c                               as construction_start_date,
        MainConstructionStartDate__c                           as main_construction_start_date,
        InstallationPeriod__c                                  as installation_period,
        ContractDeliveryDate__c                                as contract_delivery_date,
        Type                                                   as opportunity_type,
        LeadSource                                              as lead_source,
        ForecastCategory                                        as forecast_category,
        ForecastCategoryName                                    as forecast_category_name,
        ContractForecast__c                                     as contract_forecast,
        IsClosed                                                as is_closed,
        IsWon                                                   as is_won,
        CreatedDate                                             as created_date,
        LastModifiedDate                                        as last_modified_date,
        LastActivityDate                                        as last_activity_date,
        LastStageChangeDate                                     as last_stage_change_date

    from source
    where IsDeleted = false

)

select * from renamed
