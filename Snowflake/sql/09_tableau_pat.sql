-- =====================================================
-- 09_tableau_pat.sql
-- Tableau から Snowflake へ PAT（Programmatic Access Token）で接続するためのセットアップ
-- 参照:
--   https://docs.snowflake.com/en/user-guide/programmatic-access-tokens
--   https://docs.snowflake.com/en/user-guide/authentication-policies
--
-- 前提:
--   - 06_users.sql で SVC_TABLEAU（TYPE=SERVICE / DEFAULT_ROLE=SALES_USER /
--     DEFAULT_WAREHOUSE=SALES_WH）と GRANT ROLE SALES_USER TO USER SVC_TABLEAU は作成済み。
--   - データ参照権限: SALES_USER ⊃ SALES__R（03_grants.sql で SALES DB の
--     SELECT ON ALL/FUTURE TABLES|VIEWS を付与）。Tableau は
--     SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE 等へ直接接続する。
--
-- PAT の必須要件（重要）:
--   TYPE=SERVICE のユーザーが PAT を「発行」「利用」するには、次のいずれかが必要:
--     (A) ユーザー or アカウントにネットワークポリシー（ALLOWED_IP_LIST）が有効
--     (B) 認証ポリシーで PAT_POLICY = (NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED)
--   本 PoC は Tableau 側の送信元 IP を固定しづらいため (B) を既定とする。
--   固定 IP が用意できるなら (A)（06_users.sql の TABLEAU_PAT_NP）に切り替えること。
--   さらに SERVICE ユーザーの PAT には ROLE_RESTRICTION が必須。
-- =====================================================

-- ---------------------------------------------------
-- 0) 前提オブジェクトの確認（06 未実行ならここで作る。冪等）
-- ---------------------------------------------------
USE ROLE SECURITYADMIN;

CREATE USER IF NOT EXISTS SVC_TABLEAU
  TYPE = SERVICE
  DEFAULT_ROLE = SALES_USER
  DEFAULT_WAREHOUSE = SALES_WH
  COMMENT = 'Tableau接続用サービスユーザー。認証はProgrammatic Access Token(PAT)';

GRANT ROLE SALES_USER TO USER SVC_TABLEAU;

-- 参照権限の保険（03 を 07 のテーブル作成より前に流していた場合の取りこぼし対策。冪等）
GRANT SELECT ON ALL TABLES  IN SCHEMA SALES.ANALYTICS_MARTS TO ROLE SALES__R;
GRANT SELECT ON ALL VIEWS   IN SCHEMA SALES.ANALYTICS_MARTS TO ROLE SALES__R;

-- ---------------------------------------------------
-- 1) 認証ポリシー（方式B: ネットワークポリシー不要化）
--    - スキーマオブジェクト。SALES.ANALYTICS に置き USAGE で管理する。
--    - AUTHENTICATION_METHODS は既定（ALL）のまま。PAT だけに絞りたい場合は
--      AUTHENTICATION_METHODS = ('PROGRAMMATIC_ACCESS_TOKEN') を足す
--      （ただし既存の他認証を締め出すので PoC 中は広めにしておく）。
-- ---------------------------------------------------
USE ROLE ACCOUNTADMIN;   -- CREATE AUTHENTICATION POLICY はアカウントレベル権限が必要

CREATE AUTHENTICATION POLICY IF NOT EXISTS SALES.ANALYTICS.TABLEAU_PAT_POLICY
  PAT_POLICY = ( NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED )
  COMMENT = 'SVC_TABLEAU 用。PAT 認証時にネットワークポリシー必須要件を外す（PoC）';

-- SVC_TABLEAU に適用
ALTER USER SVC_TABLEAU SET AUTHENTICATION POLICY SALES.ANALYTICS.TABLEAU_PAT_POLICY;

-- 06_users.sql の方式A（ネットワークポリシー）を先に適用済みなら解除しておく
-- （方式Aと方式Bの併用は不要。方式Aを使うならこの行は実行しない）
-- ALTER USER SVC_TABLEAU UNSET NETWORK_POLICY;

-- ---------------------------------------------------
-- 2) PAT の発行
--    ★ token_secret は発行時に一度だけ表示され、再表示できない。
--      Snowsight のワークシートで実行し、結果の secret を安全に Tableau へ渡すこと
--      （このリポジトリや issue、チャットに貼らない）。
--    - ROLE_RESTRICTION: このトークンで使えるロールを1つに固定（SERVICE ユーザーは必須）。
--    - 返り値は token_name / token_secret の表。token_secret がトークン本体。
--    実行ロール: SECURITYADMIN（SVC_TABLEAU の所有者。他ロールなら
--      MODIFY PROGRAMMATIC AUTHENTICATION METHODS ON USER が必要）
-- ---------------------------------------------------
USE ROLE SECURITYADMIN;

ALTER USER IF EXISTS SVC_TABLEAU ADD PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT
  ROLE_RESTRICTION = 'SALES_USER'
  DAYS_TO_EXPIRY = 90
  COMMENT = 'Tableau Cloud/Server 接続用。90日でローテーション';

-- ローテーション（新 secret 発行、旧は指定時間後に失効）:
-- ALTER USER IF EXISTS SVC_TABLEAU ROTATE PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT
--   EXPIRE_ROTATED_TOKEN_AFTER_HOURS = 24;
-- 失効:
-- ALTER USER IF EXISTS SVC_TABLEAU REMOVE PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT;

-- ---------------------------------------------------
-- 3) Tableau 側の接続設定（参考）
--    データソース: Snowflake コネクタ
--      Server (Account URL) : SSKMHJJ-VF99886.snowflakecomputing.com
--        ※ .env の SNOWFLAKE_CONNECTIONS_FUJITECH_ACCOUNT と同一アカウント
--      Authentication        : Username / Password 方式を選び
--                              Username = SVC_TABLEAU
--                              Password = <token_secret>   ← PAT はパスワード欄にそのまま入れる
--                              （Snowflake の PAT はパスワード代替。専用 authenticator 不要）
--      Role                  : SALES_USER
--      Warehouse             : SALES_WH
--      Database / Schema      : SALES / ANALYTICS_MARTS
--    接続先テーブル例:
--      SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE（商談品目ワイド、日本語列）
--    ※ 日本語・引用符付き識別子を含むため、カスタムSQLでは列を "..." で囲む。
-- ---------------------------------------------------

-- ---------------------------------------------------
-- 4) 動作確認
-- ---------------------------------------------------
-- SHOW USER PROGRAMMATIC ACCESS TOKENS FOR USER SVC_TABLEAU;
-- SHOW AUTHENTICATION POLICIES IN SCHEMA SALES.ANALYTICS;
-- DESC AUTHENTICATION POLICY SALES.ANALYTICS.TABLEAU_PAT_POLICY;
-- SHOW GRANTS TO USER SVC_TABLEAU;          -- SALES_USER が付いているか
-- SHOW GRANTS TO ROLE SALES__R;             -- SALES マートへの SELECT があるか
--
-- CLI からトークンで疎通確認（PAT はパスワードとして渡す。<token_secret> を実値に）:
--   SNOWFLAKE_PASSWORD='<token_secret>' snow sql --temporary-connection \
--     --account SSKMHJJ-VF99886 --user SVC_TABLEAU \
--     --role SALES_USER --warehouse SALES_WH \
--     -q "select current_user(), current_role(),
--         count(*) from SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE;"
