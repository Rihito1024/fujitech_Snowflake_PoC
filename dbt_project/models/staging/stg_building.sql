-- 建物マスタデータのクレンジング済みテーブル（削除済みレコード除外）
with source as (

    select * from {{ source('salesforce', 'BUILDING__C') }}

),

renamed as (

    select
        Id                                          as building_id,
        Name                                        as building_name,
        BuildingControlNumber__c                    as building_control_number,
        cast(NumberOfFloors__c as int)               as number_of_floors,
        cast(TotalNumberUnits__c as int)             as total_number_units,
        AddressState__c                              as address_state,
        BuildingAddress__Street__s                   as address_street,
        BuildingAddress__City__s                     as address_city,
        BuildingAddress__PostalCode__s                as address_postal_code,
        BuildingAddress__StateCode__s                 as address_state_code,
        BuildingAddress__CountryCode__s               as address_country_code,
        BuildingAddress__Latitude__s                  as latitude,
        BuildingAddress__Longitude__s                 as longitude,
        BuildingOwnerName_ForFlow__c                  as building_owner_name,
        DesignOfiiceName_ForFlow__c                   as design_office_name,
        GCName_ForFlow__c                             as general_contractor_name,
        BranchInCharge__c                             as branch_in_charge,
        ResponsibleArea__c                            as responsible_area,
        NewlyEstablishedFormerConstruction__c         as newly_established_former_construction

    from source
    where IsDeleted = false

)

select * from renamed
