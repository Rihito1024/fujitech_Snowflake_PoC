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
--    ここでは追加付与なし（03 未適用ならこのブロックは 03 を流し直すこと）。
-- ---------------------------------------------------

-- ---------------------------------------------------
-- D) オブジェクト作成後の利用者向け USAGE 付与テンプレート
--    セマンティックビュー / Search サービス / エージェント / カスタムツールを
--    作成したら、名前を埋めて実行する。付与先は SALES_R（SALES_USER が継承）。
-- ---------------------------------------------------
USE ROLE SALES_MANAGER;   -- 各オブジェクトのオーナー想定

-- セマンティックビュー（Cortex Analyst のデータソース）
-- GRANT USAGE ON SEMANTIC VIEW SALES.ANALYTICS_MARTS.<セマンティックビュー名> TO ROLE SALES_R;

-- Cortex Search サービス
-- GRANT USAGE ON CORTEX SEARCH SERVICE SALES.ANALYTICS.<サーチサービス名> TO ROLE SALES_R;

-- エージェント本体
-- GRANT USAGE ON AGENT SALES.ANALYTICS.<エージェント名> TO ROLE SALES_R;

-- カスタムツール（ストアドプロシージャ / UDF）を使う場合
-- GRANT USAGE ON PROCEDURE SALES.ANALYTICS.<proc名>(<引数型,...>) TO ROLE SALES_R;

-- 元テーブルの SELECT・スキーマ USAGE は 03_grants.sql の SALES_R 付与で充足済み。
-- ツールのどれか1つでも権限不足だと、そのリクエストは 4XX で拒否される点に注意。

-- ---------------------------------------------------
-- E) エージェントを CoWork UI に公開
-- ---------------------------------------------------
USE ROLE SALES_ADMIN;   -- MODIFY 権限保有
-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
--   ADD AGENT SALES.ANALYTICS.<エージェント名>;

-- 公開解除:
-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
--   DROP AGENT SALES.ANALYTICS.<エージェント名>;

-- ---------------------------------------------------
-- F) 動作確認
-- ---------------------------------------------------
-- SHOW SNOWFLAKE INTELLIGENCE;
-- DESC SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
-- SHOW AGENTS IN SCHEMA SALES.ANALYTICS;
-- SHOW GRANTS TO ROLE SALES_USER;   -- CORTEX_AGENT_USER と各 USAGE が付いているか
-- → Snowsight 左メニューの CoWork を SALES_USER で開き、公開エージェントに質問できるか確認。
