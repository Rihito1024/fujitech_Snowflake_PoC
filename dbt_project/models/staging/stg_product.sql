-- 商品マスタのクレンジング済みテーブル（削除済みレコード除外・列名標準化）
with source as (

    select * from {{ source('flatpad_bronze', 'product2') }}

),

renamed as (

    select
        Id                  as product_id,
        Name                as product_name,
        ProductCode         as product_code,
        Description         as description,
        IsActive            as is_active,
        Family              as family,
        IsArchived          as is_archived,
        CreatedDate         as created_date,
        LastModifiedDate    as last_modified_date

    from source
    where IsDeleted = false

)

select * from renamed
