-- =====================================================
-- 08_cowork_agents.sql
-- Snowflake CoWork（旧 Snowflake Intelligence）の権限セットアップ
-- 参照:
--   https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/deploy-agents
--   https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage
--
-- 前提知識:
--   - エージェントは「実行ユーザーのデフォルトロール」で動く（caller's rights）。
--     RBAC・マスキングポリシーはそのユーザーの権限がそのまま適用される。
--     → 業務ユーザーの DEFAULT_ROLE がデータ権限を持つロールと一致していること。
--       06_users.sql で DEFAULT_ROLE=SALES_USER / DEFAULT_WAREHOUSE=SALES_WH 設定済み。
--   - エージェントはアカウント内の任意スキーマに作成可（本PoCは SALES.ANALYTICS 想定）。
--   - 「どのエージェントを CoWork UI に出すか」はアカウントに1つの単一オブジェクト
--     SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT で管理する。
--
-- ロール継承（01_roles_and_warehouse.sql）:
--   SALES_R ⊂ SALES_USER ⊂ SALES_DEVELOPER ⊂ SALES_MANAGER ⊂ SALES_ADMIN
--   → 利用者向けの USAGE は SALES_R に寄せれば SALES_USER 以上へ自動継承される。
-- =====================================================

-- ---------------------------------------------------
-- A) CoWork オブジェクト（アカウントに1つ）
-- ---------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- Snowsight の CoWork/Intelligence 設定を開くと自動作成される。明示的に作る場合:
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- 作成権限を別ロールへ渡す場合（通常は不要。ACCOUNTADMIN が作る）
-- GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE SYSADMIN;

-- エージェントの公開/除外・設定変更（MODIFY）を管理ロールへ
GRANT MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE SALES_ADMIN;

-- CoWork UI で公開エージェントと設定を見られるように（USAGE）
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE SALES_R;
-- 参照系(DATASOURCE)ユーザーにも CoWork を見せる場合はコメント解除
-- GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE DATASOURCE_R;

-- ---------------------------------------------------
-- B) Cortex / Agents 利用のためのデータベースロール
--    既定で SNOWFLAKE.CORTEX_USER が PUBLIC に付与済み。何もしなければ全ロールが使える。
--    ここでは「エージェント利用」を明示するため CORTEX_AGENT_USER を業務ロールに付与する
--    （PUBLIC の CORTEX_USER が残っていても害はない）。
-- ---------------------------------------------------
USE ROLE SECURITYADMIN;

-- CoWork / Cortex Agents API のみを許可（最小）
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE SALES_USER;
-- GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE DATASOURCE_USER;

-- ▼ さらに絞る場合（Cortex 全機能を PUBLIC から剥がす）。影響範囲が広いので方針確定後に。
--   Cortex Analyst / AISQL / LLM関数を直接使うロールには別途 CORTEX_USER が必要。
-- REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;
-- GRANT  DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SALES_MANAGER;   -- エージェント/セマンティックビュー開発者

-- ---------------------------------------------------
-- C) エージェント等の作成権限（作成ロール = SALES_MANAGER 想定）
--    CREATE AGENT / CREATE CORTEX SEARCH SERVICE / CREATE SEMANTIC VIEW は
--    03_grants.sql で SALES_RWM に付与済み（ALL/FUTURE SCHEMAS IN DATABASE SALES）。
--    → 実際の作成は `USE ROLE SALES_MANAGER; USE WAREHOUSE SALES_WH;` で行う。
--    ※ 03 を古いバージョンで適用済みの環境では CREATE AGENT /
--      CREATE CORTEX SEARCH SERVICE が SALES.ANALYTICS に付いていないことがあるため、
--      冪等な再付与を入れておく（既に付いていれば no-op）。
-- ---------------------------------------------------
USE ROLE SECURITYADMIN;
GRANT CREATE AGENT, CREATE CORTEX SEARCH SERVICE, CREATE SEMANTIC VIEW
  ON ALL SCHEMAS IN DATABASE SALES TO ROLE SALES_RWM;
GRANT CREATE AGENT, CREATE CORTEX SEARCH SERVICE, CREATE SEMANTIC VIEW
  ON FUTURE SCHEMAS IN DATABASE SALES TO ROLE SALES_RWM;

-- ---------------------------------------------------
-- C2) セマンティックビュー作成（Cortex Analyst のデータソース）
--    対象: SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE（商談品目ワイド）
--    - 1行 = 商談 × 商品明細。dbt marts の gold_opportunity_line_item_wide 相当。
--
--    ★ Cortex Analyst / CoWork は「日本語（引用符付き）識別子」を扱えない。
--      - 論理名（table/dimension/fact/metric 名）は当然 ASCII 必須。
--      - さらに、セマンティックビューが参照する【物理列名】も ASCII でないと
--        CoWork 実行時に `invalid column name "..."` で落ちる
--        （`SELECT ... FROM SEMANTIC_VIEW(...)` の直接実行は Snowflake エンジンが
--         処理するので通るが、CoWork 経由の text-to-SQL パスは通らない）。
--      → 対策: 日本語テーブルの上に「英語カラム名のビュー」を1枚かませ、
--        セマンティックビューはそのビュー（V_OPPORTUNITY_LINE_ITEM）だけを参照する。
--        日本語 → 英語の対応はこのビューの AS で1回だけ定義する。
--      → 日本語の呼び名は WITH SYNONYMS / COMMENT に入れる。
--        LLM の項目マッチはシノニム／コメントを見るので、日本語で質問しても正しくヒットする。
--
--    - FACTS   = 行レベルの数値列（メトリクスの材料）
--      DIMENSIONS = 集計軸（カテゴリ・日付）
--      METRICS = 集計式（Cortex Analyst が回答に使う指標）。式の中は論理名で参照。
--    実行ロール: SALES_MANAGER（SALES_RWM の CREATE SEMANTIC VIEW を継承）
-- ---------------------------------------------------
USE ROLE SALES_MANAGER;
USE WAREHOUSE SALES_WH;
USE SCHEMA SALES.ANALYTICS_MARTS;

-- C2-a) 英語カラム名ビュー（日本語テーブルからの薄いリネームだけ。ロジックは持たせない）
CREATE OR REPLACE VIEW SALES.ANALYTICS_MARTS.V_OPPORTUNITY_LINE_ITEM
  COMMENT = 'GOLD_OPPORTUNITY_LINE_ITEM_WIDE の英語カラム名エイリアス（Cortex Analyst 用）'
AS
SELECT
  "品目ID"                   AS line_item_id,
  "案件ID"                   AS opportunity_id,
  "案件名"                    AS opportunity_name,
  "工事番号"                  AS construction_number,
  "品目レコードタイプ"        AS line_item_record_type,
  "フェーズ"                  AS phase,
  "フォーキャストカテゴリ名"  AS forecast_category_name,
  "受注見込み・応札方針"      AS win_prospect_bid_policy,
  "クローズ済み"              AS is_closed,
  "受注済み"                  AS is_won,
  "クローズ日"                AS close_date,
  "クローズ年"                AS close_year,
  "クローズ月"                AS close_month,
  "クローズ四半期"            AS close_quarter,
  "クローズ会計年度"          AS close_fiscal_year,
  "クローズ年月"              AS close_year_month,
  "クローズ年四半期"          AS close_year_quarter,
  "受注予定日"                AS expected_order_date,
  "受注予定年度"              AS expected_order_fiscal_year,
  "受注予定年月"              AS expected_order_year_month,
  "商品コード"                AS product_code,
  "商品名"                    AS product_name,
  "商品ファミリー"            AS product_family,
  "顧客名（契約先）"          AS customer_name,
  "請求先都道府県"            AS billing_prefecture,
  "請求先市区町村"            AS billing_city,
  "設計事務所"                AS design_office,
  "建物所有者（施主）"        AS building_owner,
  "主担当者"                  AS primary_owner,
  "主担当者役職"              AS primary_owner_title,
  "主担当部署"                AS primary_department,
  "上位部署名"                AS parent_department_name,
  "受注エリア"                AS order_area,
  "受注店所"                  AS order_branch,
  "レコードタイプ名"          AS record_type_name,
  "台数"                      AS qty,
  "合計金額"                  AS total_amount,
  "見積金額"                  AS quote_amount,
  "提示金額"                  AS proposed_amount,
  "利益"                      AS profit,
  "利益率"                    AS profit_rate,
  "小計"                      AS subtotal,
  "定価"                      AS list_price
FROM SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE;

-- 利用者ロールからも参照できるように（セマンティックビューは実行ユーザー権限で下層を読む）
GRANT SELECT ON VIEW SALES.ANALYTICS_MARTS.V_OPPORTUNITY_LINE_ITEM TO ROLE SALES__R;

-- C2-b) セマンティックビュー（参照先は英語ビューのみ。日本語識別子はゼロ）
CREATE OR REPLACE SEMANTIC VIEW SALES.ANALYTICS_MARTS.SV_OPPORTUNITY_LINE_ITEM
  TABLES (
    OLI AS SALES.ANALYTICS_MARTS.V_OPPORTUNITY_LINE_ITEM
      PRIMARY KEY (line_item_id)
      WITH SYNONYMS = ('商談品目', '案件品目', '受注明細', 'opportunity line item')
      COMMENT = '商談品目ワイド。1行=商談×商品明細。'
  )
  FACTS (
    OLI.qty              AS qty              COMMENT = '明細の台数（号機数）。日本語名: 台数',
    OLI.total_amount     AS total_amount     COMMENT = '明細の合計金額（円）。日本語名: 合計金額',
    OLI.quote_amount     AS quote_amount     COMMENT = '明細の見積金額（円）。日本語名: 見積金額',
    OLI.proposed_amount  AS proposed_amount  COMMENT = '顧客への提示金額（円）。日本語名: 提示金額',
    OLI.profit           AS profit           COMMENT = '明細の利益額（円）。日本語名: 利益',
    OLI.profit_rate      AS profit_rate      COMMENT = '利益率（元データの比率値。単位は要確認）。日本語名: 利益率',
    OLI.subtotal         AS subtotal         COMMENT = '明細の小計（円）。日本語名: 小計',
    OLI.list_price       AS list_price       COMMENT = '定価（円）。日本語名: 定価'
  )
  DIMENSIONS (
    OLI.line_item_id             AS line_item_id
      WITH SYNONYMS = ('品目ID', '明細ID') COMMENT = '品目（明細）を一意に識別するID',
    OLI.opportunity_id           AS opportunity_id
      WITH SYNONYMS = ('案件ID', '商談ID') COMMENT = '商談（案件）を一意に識別するID',
    OLI.opportunity_name         AS opportunity_name
      WITH SYNONYMS = ('案件名', '商談名', 'オポチュニティ名') COMMENT = '商談（案件）の名称',
    OLI.construction_number      AS construction_number
      WITH SYNONYMS = ('工事番号') COMMENT = '工事番号',
    OLI.line_item_record_type    AS line_item_record_type
      WITH SYNONYMS = ('品目レコードタイプ') COMMENT = '品目のレコードタイプ',
    OLI.phase                    AS phase
      WITH SYNONYMS = ('フェーズ', 'ステージ', '商談ステージ', 'stage') COMMENT = '商談のフェーズ（ステージ）',
    OLI.forecast_category_name   AS forecast_category_name
      WITH SYNONYMS = ('フォーキャストカテゴリ名', 'フォーキャストカテゴリ') COMMENT = 'フォーキャストカテゴリ名',
    OLI.win_prospect_bid_policy  AS win_prospect_bid_policy
      WITH SYNONYMS = ('受注見込み・応札方針', '応札方針') COMMENT = '受注見込み・応札方針',
    OLI.is_closed                AS is_closed
      WITH SYNONYMS = ('クローズ済み', 'クローズ') COMMENT = '商談がクローズ済みか（TRUE/FALSE）',
    OLI.is_won                   AS is_won
      WITH SYNONYMS = ('受注済み', '受注', '成約', 'Won') COMMENT = '受注（成約）済みか（TRUE/FALSE）',
    OLI.close_date               AS close_date
      WITH SYNONYMS = ('クローズ日') COMMENT = '商談のクローズ日',
    OLI.close_year               AS close_year
      WITH SYNONYMS = ('クローズ年') COMMENT = 'クローズ日の年',
    OLI.close_month              AS close_month
      WITH SYNONYMS = ('クローズ月') COMMENT = 'クローズ日の月（1〜12）',
    OLI.close_quarter            AS close_quarter
      WITH SYNONYMS = ('クローズ四半期') COMMENT = 'クローズ日の四半期（1〜4）',
    OLI.close_fiscal_year        AS close_fiscal_year
      WITH SYNONYMS = ('クローズ会計年度', '会計年度', '年度') COMMENT = 'クローズ日の会計年度',
    OLI.close_year_month         AS close_year_month
      WITH SYNONYMS = ('クローズ年月') COMMENT = 'クローズ年月（例: 2025-12）',
    OLI.close_year_quarter       AS close_year_quarter
      WITH SYNONYMS = ('クローズ年四半期') COMMENT = 'クローズ年四半期（例: 2025-Q3）',
    OLI.expected_order_date      AS expected_order_date
      WITH SYNONYMS = ('受注予定日') COMMENT = '受注予定日',
    OLI.expected_order_fiscal_year AS expected_order_fiscal_year
      WITH SYNONYMS = ('受注予定年度') COMMENT = '受注予定日の会計年度',
    OLI.expected_order_year_month AS expected_order_year_month
      WITH SYNONYMS = ('受注予定年月') COMMENT = '受注予定年月（例: 2024-02）',
    OLI.product_code             AS product_code
      WITH SYNONYMS = ('商品コード') COMMENT = '商品コード',
    OLI.product_name             AS product_name
      WITH SYNONYMS = ('商品名', '製品名', 'プロダクト名') COMMENT = '商品名',
    OLI.product_family           AS product_family
      WITH SYNONYMS = ('商品ファミリー', '商品カテゴリ') COMMENT = '商品ファミリー（カテゴリ）',
    OLI.customer_name            AS customer_name
      WITH SYNONYMS = ('顧客名', '取引先', 'アカウント', '契約先', 'customer') COMMENT = '顧客名（契約先アカウント）',
    OLI.billing_prefecture       AS billing_prefecture
      WITH SYNONYMS = ('請求先都道府県', '都道府県') COMMENT = '請求先の都道府県',
    OLI.billing_city             AS billing_city
      WITH SYNONYMS = ('請求先市区町村', '市区町村') COMMENT = '請求先の市区町村',
    OLI.design_office            AS design_office
      WITH SYNONYMS = ('設計事務所') COMMENT = '設計事務所名',
    OLI.building_owner           AS building_owner
      WITH SYNONYMS = ('建物所有者', '施主') COMMENT = '建物所有者（施主）名',
    OLI.primary_owner            AS primary_owner
      WITH SYNONYMS = ('主担当者', '営業担当', '担当者', 'オーナー') COMMENT = '商談の主担当者',
    OLI.primary_owner_title      AS primary_owner_title
      WITH SYNONYMS = ('主担当者役職', '役職') COMMENT = '主担当者の役職',
    OLI.primary_department       AS primary_department
      WITH SYNONYMS = ('主担当部署', '部署', '営業部署') COMMENT = '主担当者の部署',
    OLI.parent_department_name   AS parent_department_name
      WITH SYNONYMS = ('上位部署名', '上位部署') COMMENT = '主担当部署の上位部署',
    OLI.order_area               AS order_area
      WITH SYNONYMS = ('受注エリア', 'エリア', '地域') COMMENT = '受注エリア',
    OLI.order_branch             AS order_branch
      WITH SYNONYMS = ('受注店所', '店所', '支店') COMMENT = '受注店所',
    OLI.record_type_name         AS record_type_name
      WITH SYNONYMS = ('レコードタイプ名') COMMENT = '商談のレコードタイプ名'
  )
  METRICS (
    OLI.line_item_count      AS COUNT(OLI.line_item_id)
      WITH SYNONYMS = ('品目件数', '明細件数') COMMENT = '明細（品目）の件数',
    OLI.opportunity_count    AS COUNT(DISTINCT OLI.opportunity_id)
      WITH SYNONYMS = ('案件数', '商談数') COMMENT = '商談（案件）のユニーク件数',
    OLI.total_amount_sum     AS SUM(OLI.total_amount)
      WITH SYNONYMS = ('合計金額合計', '合計金額', '売上') COMMENT = '合計金額の総和（円）',
    OLI.quote_amount_sum     AS SUM(OLI.quote_amount)
      WITH SYNONYMS = ('見積金額合計', '見積金額') COMMENT = '見積金額の総和（円）',
    OLI.proposed_amount_sum  AS SUM(OLI.proposed_amount)
      WITH SYNONYMS = ('提示金額合計', '提示金額') COMMENT = '提示金額の総和（円）',
    OLI.profit_sum           AS SUM(OLI.profit)
      WITH SYNONYMS = ('利益合計', '利益') COMMENT = '利益額の総和（円）',
    OLI.qty_sum              AS SUM(OLI.qty)
      WITH SYNONYMS = ('台数合計', '台数') COMMENT = '台数の総和',
    OLI.avg_profit_rate      AS AVG(OLI.profit_rate)
      WITH SYNONYMS = ('平均利益率', '利益率') COMMENT = '利益率の平均（元データの比率値の単純平均）',
    OLI.won_opportunity_count AS COUNT(DISTINCT CASE WHEN OLI.is_won THEN OLI.opportunity_id END)
      WITH SYNONYMS = ('受注案件数', '受注件数', '成約件数') COMMENT = '受注済み商談のユニーク件数',
    OLI.won_amount_sum       AS SUM(CASE WHEN OLI.is_won THEN OLI.total_amount END)
      WITH SYNONYMS = ('受注金額合計', '受注金額', '受注高') COMMENT = '受注済み明細の合計金額の総和（円）'
  )
  COMMENT = 'フジテック営業パイプライン: 商談品目の分析用セマンティックビュー（Cortex Analyst / CoWork 用）';

-- 動作確認（SEMANTIC_VIEW 構文で直接クエリできる。論理名は ASCII）:
-- SELECT * FROM SEMANTIC_VIEW(
--   SALES.ANALYTICS_MARTS.SV_OPPORTUNITY_LINE_ITEM
--   METRICS opportunity_count, total_amount_sum, won_amount_sum, line_item_count
--   DIMENSIONS close_fiscal_year
-- ) ORDER BY 1;

-- ---------------------------------------------------
-- C3) エージェント本体の作成（Cortex Agent）
--    配置: SALES.ANALYTICS.SALES_PIPELINE_AGENT
--    - C2 のセマンティックビューを cortex_analyst_text_to_sql ツールとして参照。
--    - FROM SPECIFICATION の JSON がエージェント定義（Snowsight の GUI 編集内容と等価）。
--    - "models".orchestration は "auto"（Snowflake が最適モデルを選択）。
--    - tool_resources のキー名は tools[].tool_spec.name と一致させる。
--    - execution_environment で Cortex Analyst のクエリ実行 WH を指定。
--    実行ロール: SALES_MANAGER（C の CREATE AGENT を継承）
-- ---------------------------------------------------
USE ROLE SALES_MANAGER;
USE WAREHOUSE SALES_WH;
USE SCHEMA SALES.ANALYTICS;

CREATE OR REPLACE AGENT SALES.ANALYTICS.SALES_PIPELINE_AGENT
  WITH PROFILE='{"display_name": "営業パイプライン アシスタント"}'
  COMMENT='フジテック営業パイプライン分析エージェント（PoC）'
  FROM SPECIFICATION $$
{
  "models": { "orchestration": "auto" },
  "instructions": {
    "response": "回答は日本語で簡潔に。金額は円単位で3桁区切り。可能なら数値の根拠（期間・絞り込み条件）を明記する。",
    "orchestration": "商談・受注・見積・利益に関する質問は必ず query_opportunity_line_item ツールを使う。データに無い項目は推測せず不明と答える。",
    "sample_questions": [
      { "question": "今会計年度の受注金額合計は？" },
      { "question": "受注エリア別の案件数と受注金額を教えて" },
      { "question": "商品ファミリー別の平均利益率は？" },
      { "question": "フェーズ別の見積金額合計を多い順に" }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "query_opportunity_line_item",
        "description": "商談品目（商談×商品明細）の分析。案件数・受注金額・見積金額・利益率などを、エリア・部署・商品・クローズ年度などの軸で集計する。"
      }
    }
  ],
  "tool_resources": {
    "query_opportunity_line_item": {
      "semantic_view": "SALES.ANALYTICS_MARTS.SV_OPPORTUNITY_LINE_ITEM",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH"
      }
    }
  }
}
$$;

-- 確認:
-- SHOW AGENTS IN SCHEMA SALES.ANALYTICS;
-- DESC AGENT SALES.ANALYTICS.SALES_PIPELINE_AGENT;

-- ---------------------------------------------------
-- D) オブジェクト作成後の利用者向け USAGE 付与テンプレート
--    Search サービス / エージェント / カスタムツールを
--    作成したら、名前を埋めて実行する。付与先は SALES_R（SALES_USER が継承）。
-- ---------------------------------------------------
USE ROLE SALES_MANAGER;   -- 各オブジェクトのオーナー想定

-- セマンティックビュー（C2 で作成済み。SALES_USER 以下から Cortex Analyst / SEMANTIC_VIEW() で参照可能に）
-- ※ セマンティックビューの参照権限は USAGE ではなく SELECT。
GRANT SELECT ON SEMANTIC VIEW SALES.ANALYTICS_MARTS.SV_OPPORTUNITY_LINE_ITEM TO ROLE SALES__R;

-- Cortex Search サービス
-- GRANT USAGE ON CORTEX SEARCH SERVICE SALES.ANALYTICS.<サーチサービス名> TO ROLE SALES__R;

-- エージェント本体（C3 で作成済み）
GRANT USAGE ON AGENT SALES.ANALYTICS.SALES_PIPELINE_AGENT TO ROLE SALES__R;

-- カスタムツール（ストアドプロシージャ / UDF）を使う場合
-- GRANT USAGE ON PROCEDURE SALES.ANALYTICS.<proc名>(<引数型,...>) TO ROLE SALES__R;

-- 元テーブルの SELECT・スキーマ USAGE は 03_grants.sql の SALES_R 付与で充足済み。
-- ツールのどれか1つでも権限不足だと、そのリクエストは 4XX で拒否される点に注意。

-- ---------------------------------------------------
-- E) エージェントを CoWork UI に公開
-- ---------------------------------------------------
USE ROLE SALES_ADMIN;   -- MODIFY 権限保有

-- ADD AGENT は冪等でない（既に公開済みだと 400203）。再実行できるよう例外を握りつぶす。
EXECUTE IMMEDIATE $$
BEGIN
  ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    ADD AGENT SALES.ANALYTICS.SALES_PIPELINE_AGENT;
  RETURN 'added';
EXCEPTION
  WHEN OTHER THEN
    IF (SQLCODE = 400203) THEN
      RETURN 'already present - skipped';
    ELSE
      RAISE;
    END IF;
END;
$$;

-- 公開解除:
-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
--   DROP AGENT SALES.ANALYTICS.SALES_PIPELINE_AGENT;

-- ---------------------------------------------------
-- F) 動作確認
-- ---------------------------------------------------
-- SHOW SNOWFLAKE INTELLIGENCES;   -- ※ SHOW は複数形。単数形 SHOW SNOWFLAKE INTELLIGENCE は構文エラー
-- DESC SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;   -- DESC/ALTER/CREATE は単数形
-- SHOW SEMANTIC VIEWS IN SCHEMA SALES.ANALYTICS_MARTS;
-- DESC SEMANTIC VIEW SALES.ANALYTICS_MARTS.SV_OPPORTUNITY_LINE_ITEM;
-- SHOW AGENTS IN SCHEMA SALES.ANALYTICS;
-- DESC AGENT SALES.ANALYTICS.SALES_PIPELINE_AGENT;
-- SHOW GRANTS TO ROLE SALES_USER;   -- CORTEX_AGENT_USER と各 USAGE が付いているか
-- → Snowsight 左メニューの CoWork を SALES_USER で開き、公開エージェントに質問できるか確認。
