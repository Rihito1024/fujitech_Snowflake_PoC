-- =====================================================
-- 06_users.sql
-- Tableauサービスユーザー / 営業ユーザー
-- 参照: ../構成.md #### ユーザー
-- 実行ロール: SECURITYADMIN（ユーザー作成）
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

-- PATの発行（作成後に別途実行。トークンは発行時のみ表示され再表示不可のため、
-- 発行後は安全な方法でTableau側に連携すること）
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
