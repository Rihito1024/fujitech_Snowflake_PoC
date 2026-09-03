-- 商談-資産の関連テーブル（削除済みレコード除外）
with source as (

    select * from {{ source('flatpad_bronze', 'opportunity_asset__c') }}

),

renamed as (

    select
        Id                        as opportunity_asset_id,
        Opportunity__c             as opportunity_id,
        Asset__c                   as asset_id,
        CarryOver__c                as is_carry_over,
        OpportunityAssetCode__c     as opportunity_asset_code,
        Name                        as name

    from source
    where IsDeleted = false

)

select * from renamed
