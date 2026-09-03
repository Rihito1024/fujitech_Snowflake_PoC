-- 顧客アカウントデータのクレンジング済みテーブル（削除済みレコード除外）
with source as (

    select * from {{ source('flatpad_bronze', 'account') }}

),

renamed as (

    select
        Id                  as account_id,
        Name                as account_name,
        Type                as account_type,
        RecordTypeId        as record_type_id,
        ParentId            as parent_account_id,
        BillingCity         as billing_city,
        BillingState        as billing_state,
        BillingPostalCode   as billing_postal_code,
        BillingCountry      as billing_country,
        ShippingCity        as shipping_city,
        ShippingState       as shipping_state,
        ShippingPostalCode  as shipping_postal_code,
        ShippingCountry     as shipping_country

    from source
    where IsDeleted = false

)

select * from renamed
