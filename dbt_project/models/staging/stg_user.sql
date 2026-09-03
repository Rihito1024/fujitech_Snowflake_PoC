-- ユーザーデータのクレンジング済みテーブル
with source as (

    select * from {{ source('flatpad_bronze', 'user') }}

),

renamed as (

    select
        Id             as user_id,
        Username       as username,
        Name           as full_name,
        FirstName      as first_name,
        LastName       as last_name,
        CompanyName    as company_name,
        Division       as division,
        Department     as department,
        Title          as title,
        City           as city,
        State          as state,
        PostalCode     as postal_code

    from source

)

select * from renamed
