-- 商談-建物の関連テーブル（削除済みレコード除外）
with source as (

    select * from {{ source('salesforce', 'OPPORTUNITYBUILDING__C') }}

),

renamed as (

    select
        Id                  as opportunity_building_id,
        Opportunity__c       as opportunity_id,
        Building__c           as building_id,
        Building_Exp__c       as building_description,
        Name                  as name

    from source
    where IsDeleted = false

)

select * from renamed
