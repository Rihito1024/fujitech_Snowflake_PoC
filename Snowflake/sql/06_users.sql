-- =====================================================
-- 06_users.sql
-- Tableauサービスユーザー / dbtサービスユーザー / 営業ユーザー
-- 参照: ../構成.md #### ユーザー、../docs/tableau_cloud_connection_setup.md
-- 実行ロール: SECURITYADMIN（ユーザー・ネットワークポリシー作成）
--   PAT の発行だけは Snowsight で手動実行（下記「▼ 手動実行」参照）
-- =====================================================

USE ROLE SECURITYADMIN;

-- ---------------------------------------------------
-- Tableauサービスユーザー（認証: PAT）
-- ---------------------------------------------------
CREATE USER IF NOT EXISTS SVC_TABLEAU
  TYPE = SERVICE
  DEFAULT_ROLE = SALES_USER
  DEFAULT_WAREHOUSE = SALES_WH
  COMMENT = 'Tableau接続用サービスユーザー。認証はProgrammatic Access Token(PAT)';

GRANT ROLE SALES_USER TO USER SVC_TABLEAU;

-- ---------------------------------------------------
-- dbt実行用サービスユーザー
-- ロールは SALES_TRANSFORMER（01_roles_and_warehouse.sql で作成）。
-- 認証はキーペア推奨。PoCで簡易にPATを使う場合は SVC_TABLEAU と同様に
-- ネットワークポリシー（TYPE=SERVICE は PAT にNP必須）と
-- ADD PROGRAMMATIC ACCESS TOKEN ... ROLE_RESTRICTION = SALES_TRANSFORMER が必要。
-- ---------------------------------------------------
CREATE USER IF NOT EXISTS SVC_DBT
  TYPE = SERVICE
  DEFAULT_ROLE = SALES_TRANSFORMER
  DEFAULT_WAREHOUSE = SALES_WH
  COMMENT = 'dbt(build/run/test)実行用サービスユーザー。認証はキーペア推奨';

GRANT ROLE SALES_TRANSFORMER TO USER SVC_DBT;

-- ---------------------------------------------------
-- ネットワークポリシー（PATの必須要件）
-- TYPE=SERVICE のユーザーは PAT の「発行」も「利用」もネットワークポリシー必須。
-- 未設定だと ALTER USER ... ADD PROGRAMMATIC ACCESS TOKEN が失敗する。
-- ※ MINS_TO_BYPASS_NETWORK_POLICY_REQUIREMENT は PERSON 専用でSERVICEには効かない。
-- ALLOWED_IP_LIST には Tableau 側の送信元グローバルIP を入れる
--   Tableau Cloud: Pod（デプロイ先リージョン）ごとの Egress IP レンジを Tableau が公開。
--     先方に Tableau Cloud サイトの Pod を確認し、該当 IP/CIDR を列挙する。
--   Tableau Server: NAT / Egress IP を先方から提供してもらう。
-- ---------------------------------------------------
CREATE NETWORK POLICY IF NOT EXISTS TABLEAU_PAT_NP
  ALLOWED_IP_LIST = ('<TODO: TableauのグローバルIP/CIDR>')
  COMMENT = 'SVC_TABLEAU の PAT 認証用。Tableau からのアクセス元IPに限定';

ALTER USER SVC_TABLEAU SET NETWORK_POLICY = TABLEAU_PAT_NP;

-- 代替案: IP制限を掛けたくない場合は認証ポリシーで要件自体を外す
-- （認証ポリシーはスキーマオブジェクト。任意のDB/スキーマに作成し USAGE 管理する）
-- USE ROLE ACCOUNTADMIN;
-- CREATE AUTHENTICATION POLICY IF NOT EXISTS SALES.ANALYTICS.PAT_NO_NP
--   PAT_POLICY = (NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED);
-- ALTER USER SVC_TABLEAU SET AUTHENTICATION POLICY SALES.ANALYTICS.PAT_NO_NP;
-- USE ROLE SECURITYADMIN;

-- ---------------------------------------------------
-- ▼ 手動実行: PAT の発行（Snowsight のワークシートで実行すること）
--   - token_secret は発行時に一度だけ表示され、再表示できない。
--     `snow sql -f` で流すとログに残るため、必ず Snowsight で実行し、
--     結果の secret を安全な経路で先方へ受け渡す（リポジトリ・chat・issue に貼らない）。
--   - SERVICE ユーザーは ROLE_RESTRICTION 必須。
--   - 実行ロール: SECURITYADMIN（SVC_TABLEAU の所有者）
--   - 詳細な受け渡し手順と Tableau 側設定は Snowflake/docs/tableau_cloud_connection_setup.md
-- ---------------------------------------------------
-- USE ROLE SECURITYADMIN;
-- ALTER USER IF EXISTS SVC_TABLEAU ADD PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT
--   ROLE_RESTRICTION = 'SALES_USER'
--   DAYS_TO_EXPIRY = 90
--   COMMENT = 'Tableau Cloud 接続用。90日でローテーション';
--
-- ローテーション（新 secret 発行、旧トークンは指定時間後に失効）:
-- ALTER USER IF EXISTS SVC_TABLEAU ROTATE PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT
--   EXPIRE_ROTATED_TOKEN_AFTER_HOURS = 24;
-- 失効:
-- ALTER USER IF EXISTS SVC_TABLEAU REMOVE PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT;
-- 一覧:
-- SHOW USER PROGRAMMATIC ACCESS TOKENS FOR USER SVC_TABLEAU;

-- ---------------------------------------------------
-- 営業ユーザー（人）
-- 実際の氏名・メールアドレス・ログイン名に置き換えて作成すること
-- 複数名いる場合は本ブロックを人数分複製する
-- ---------------------------------------------------
-- CREATE USER IF NOT EXISTS <TODO: ユーザー名>
--   LOGIN_NAME = '<TODO: ログイン名>'
--   EMAIL = '<TODO: email>'
--   DEFAULT_ROLE = SALES_USER
--   DEFAULT_WAREHOUSE = SALES_WH
--   MUST_CHANGE_PASSWORD = TRUE;
-- GRANT ROLE SALES_USER TO USER <TODO: ユーザー名>;
