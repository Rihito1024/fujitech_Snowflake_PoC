-- レコードタイプマスタのクレンジング済みテーブル
with source as (

    select * from {{ source('flatpad_bronze', 'recordtype') }}

),

renamed as (

    select
        Id               as record_type_id,
        Name             as record_type_name,
        DeveloperName    as developer_name,
        Description      as description,
        SobjectType      as sobject_type

    from source
    where IsActive = true

)

select * from renamed
