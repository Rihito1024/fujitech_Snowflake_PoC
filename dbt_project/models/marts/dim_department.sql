-- 部門ディメンション（階層構造・エリア情報を含む）
select
    department_id,
    department_name,
    department_full_name,
    department_code,
    parent_department_id,
    parent_department_name,
    parent_department_code,
    hierarchy_level,
    mother_store_code,
    area_code

from {{ ref('stg_department') }}
