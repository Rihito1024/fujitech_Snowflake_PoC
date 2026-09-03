-- 商談-建物ブリッジテーブル（多対多リレーション解決用）
select
    opportunity_building_id,
    opportunity_id,
    building_id,
    building_description

from {{ ref('stg_opportunity_building') }}
