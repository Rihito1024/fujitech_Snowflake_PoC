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
