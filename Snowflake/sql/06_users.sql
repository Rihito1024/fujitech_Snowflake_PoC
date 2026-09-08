-- =====================================================
-- 06_users.sql
-- Tableauサービスユーザー / 営業ユーザー
-- 参照: ../構成.md #### ユーザー
-- 実行ロール: SECURITYADMIN（ユーザー作成 + ネットワークポリシー作成）
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
--   （Tableau Cloud の公開IPレンジ / Tableau Server の NAT・Egress IP）。
-- ---------------------------------------------------
CREATE NETWORK POLICY IF NOT EXISTS TABLEAU_PAT_NP
  ALLOWED_IP_LIST = ('<TODO: TableauのグローバルIP/CIDR>')
  COMMENT = 'SVC_TABLEAU の PAT 認証用。Tableau からのアクセス元IPに限定';

ALTER USER SVC_TABLEAU SET NETWORK_POLICY = TABLEAU_PAT_NP;

-- 代替案: IP制限を掛けたくない場合は認証ポリシーで要件自体を外す
-- （認証ポリシーはスキーマオブジェクト。任意のDB/スキーマに作成し USAGE 管理する）
-- CREATE AUTHENTICATION POLICY IF NOT EXISTS SALES.ANALYTICS.PAT_NO_NP
--   PAT_POLICY = (NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED);
-- ALTER USER SVC_TABLEAU SET AUTHENTICATION POLICY SALES.ANALYTICS.PAT_NO_NP;

-- PATの発行（作成後に別途実行。トークンは発行時のみ表示され再表示不可のため、
-- 発行後は安全な方法でTableau側に連携すること）
-- SERVICE ユーザーは ROLE_RESTRICTION 必須。発行には対象ユーザーへの OWNERSHIP または
-- MODIFY PROGRAMMATIC AUTHENTICATION METHODS 権限が必要（SECURITYADMIN は所有者なので可）。
-- ALTER USER SVC_TABLEAU ADD PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT
--   ROLE_RESTRICTION = SALES_USER
--   DAYS_TO_EXPIRY = 90;

-- ---------------------------------------------------
-- Openflow → Snowflake 書き込み用サービスユーザー
-- Openflow の Salesforce コネクタが Snowflake へ書き込む際の接続ユーザー。
-- ロールは DATASOURCE_OPENFLOW（05_salesforce_external_access.sql (D) で作成）。
--   → ランタイム実行ロールと同じにして権限を1本化。書き込み先権限は
--     03_grants.sql の DATASOURCE__RWM（DATASOURCE.SALESFORCE への CREATE TABLE / DML）で充足。
-- 認証は RSA キーペア。TYPE=SERVICE + キーペアはネットワークポリシー不要（PAT と異なる）。
-- 秘密鍵は Openflow(SPCS) の Snowflake Private Key Service パラメータにのみ保持し手元に残さない。
-- ---------------------------------------------------
CREATE USER IF NOT EXISTS SVC_OPENFLOW
  TYPE = SERVICE
  DEFAULT_ROLE = DATASOURCE_OPENFLOW
  DEFAULT_WAREHOUSE = OPENFLOW_WH
  COMMENT = 'Openflow Salesforceコネクタの Snowflake 書き込み用。キーペア認証';

GRANT ROLE DATASOURCE_OPENFLOW TO USER SVC_OPENFLOW;

-- 公開鍵を登録（BEGIN/END 行と改行を除いた base64 本体のみ）。
--   生成例:
--     openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out sf_openflow.p8
--     openssl pkey -in sf_openflow.p8 -pubout -out sf_openflow.pub
--   秘密鍵 sf_openflow.p8 全文 → Openflow の Snowflake Private Key
--   パスフレーズ            → Openflow の Snowflake Private Key Password
-- ALTER USER SVC_OPENFLOW SET RSA_PUBLIC_KEY = '<sf_openflow.pub の中身>';
-- 確認: DESC USER SVC_OPENFLOW;  → RSA_PUBLIC_KEY_FP が入っていればOK

-- 無停止ローテーション: 新鍵を _2 側に入れて Openflow を切替→旧鍵を除去
-- ALTER USER SVC_OPENFLOW SET RSA_PUBLIC_KEY_2 = '<新しい公開鍵>';
-- ALTER USER SVC_OPENFLOW UNSET RSA_PUBLIC_KEY;   -- 切替確認後

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
