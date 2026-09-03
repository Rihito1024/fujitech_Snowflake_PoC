-- 部門マスタデータのクレンジング済みテーブル（削除済みレコード除外）
with source as (

    select * from {{ source('flatpad_bronze', 'departmentmst__c') }}

),

renamed as (

    select
        Id                    as department_id,
        Name                  as department_name,
        DepartmentName__c     as department_full_name,
        DepartmentCode__c     as department_code,
        ParentDepartment__c   as parent_department_id,
        ParentName__c         as parent_department_name,
        ParentCode__c         as parent_department_code,
        cast(Level__c as int) as hierarchy_level,
        MotherStoreCode__c    as mother_store_code,
        AreaCode__c           as area_code

    from source
    where IsDeleted = false

)

select * from renamed
