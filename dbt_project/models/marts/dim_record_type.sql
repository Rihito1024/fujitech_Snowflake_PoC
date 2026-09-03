-- レコードタイプディメンション（商談カテゴリ分類）
select
    record_type_id,
    record_type_name,
    developer_name,
    description,
    sobject_type

from {{ ref('stg_record_type') }}
