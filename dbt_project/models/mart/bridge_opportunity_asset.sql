-- 商談-資産ブリッジテーブル（多対多リレーション解決用）
select
    opportunity_asset_id,
    opportunity_id,
    asset_id,
    is_carry_over,
    opportunity_asset_code

from {{ ref('stg_opportunity_asset') }}
