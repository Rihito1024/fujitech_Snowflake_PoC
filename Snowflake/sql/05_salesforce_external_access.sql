-- =====================================================
-- 05_salesforce_external_access.sql
-- OpenflowからSalesforce APIへ疎通するためのNetwork Rule / External Access Integration
-- 参照: ../構成.md #### データ取り込み
--   OpenflowのSalesforce API疎通用External Access Integration / Network Rule
--   → Datasource/Salesforceに作成
--
-- 前提: 先方のSalesforceサービスユーザー払い出し待ち（未確定・要置換）
-- 実行ロール: ACCOUNTADMIN（EXTERNAL ACCESS INTEGRATION作成に必要）
-- SPCSコンピュートプール（Openflowランタイム）はGUIで作成する方針のため対象外
-- =====================================================

USE ROLE ACCOUNTADMIN;

CREATE NETWORK RULE IF NOT EXISTS DATASOURCE.SALESFORCE.SALESFORCE_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = (
    '<TODO: 対象組織のmy.salesforce.comドメイン>:443',
    'login.salesforce.com:443'
  );

-- Salesforce認証情報（先方から払い出されるサービスユーザーの資格情報）
-- 値が揃い次第、コメントアウトを解除して作成する
-- CREATE SECRET IF NOT EXISTS DATASOURCE.SALESFORCE.SALESFORCE_CREDENTIALS
--   TYPE = PASSWORD
--   USERNAME = '<TODO: Salesforceサービスユーザー>'
--   PASSWORD = '<TODO: パスワード or セキュリティトークン>';

CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS SALESFORCE_ACCESS_INT
  ALLOWED_NETWORK_RULES = (DATASOURCE.SALESFORCE.SALESFORCE_API_RULE)
  -- ALLOWED_AUTHENTICATION_SECRETS = (DATASOURCE.SALESFORCE.SALESFORCE_CREDENTIALS)
  ENABLED = TRUE;

-- オーナーシップはDatasource/SalesforceのオブジェクトとしてDATASOURCE_ADMINへ集約する方針
GRANT USAGE ON INTEGRATION SALESFORCE_ACCESS_INT TO ROLE DATASOURCE_ADMIN;
