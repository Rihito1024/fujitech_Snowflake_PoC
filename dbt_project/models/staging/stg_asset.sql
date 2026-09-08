-- 資産（納入号機）データのクレンジング済みテーブル（削除済みレコード除外）
with source as (

    select * from {{ source('salesforce', 'asset') }}

),

renamed as (

    select
        Id                      as asset_id,
        Name                    as asset_name,
        AccountId               as account_id,
        SerialNumber            as serial_number,
        Status                  as status,
        ProductCode             as product_code,
        ProductFamily           as product_family,
        ProductName__c          as product_name,
        InstallDate             as install_date,
        ManufactureDate         as manufacture_date,
        PurchaseDate            as purchase_date,
        UsageEndDate            as usage_end_date,
        IsCompetitorProduct     as is_competitor_product,
        CreatedDate             as created_date,
        LastModifiedDate        as last_modified_date

    from source
    where IsDeleted = false

)

select * from renamed
