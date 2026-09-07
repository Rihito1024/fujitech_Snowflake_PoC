-- =====================================================
-- 04_storage_integration_and_stage.sql
-- S3用Storage Integration（Datasource.COMMON）と外部ステージ（Datasource.SALESFORCE）
-- 参照: ../構成.md #### データ取り込み
--   S3用Storage Integration（IAMロール・外部ID）→ Datasource/commonに一旦置く
--   外部ステージのファイルフォーマット定義 → 実ファイルを見て作成（下記は暫定CSV）
--   自動取り込み方式 → 一旦COPY INTO
--
-- 前提:
--   S3バケット名: snowflake-fujitec-storage / AWSアカウントID: 117047811671（確定）
--   IAMロール名: snowflake-s3-inbound-role / プレフィックス: inbound/
-- 実行ロール: STORAGE INTEGRATION作成は ACCOUNTADMIN、FILE FORMAT/STAGE作成は DATASOURCE_MANAGER
-- =====================================================

USE ROLE ACCOUNTADMIN;

CREATE STORAGE INTEGRATION IF NOT EXISTS SALESFORCE_S3_INT
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::117047811671:role/snowflake-s3-inbound-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://snowflake-fujitec-storage/inbound/');

-- 作成後、以下で確認できる値を先方のIAMロール信頼ポリシーに追記依頼する
-- DESC STORAGE INTEGRATION SALESFORCE_S3_INT;
--   STORAGE_AWS_IAM_USER_ARN -> Snowflake側の外部IAMユーザー
--   STORAGE_AWS_EXTERNAL_ID  -> 外部ID

GRANT USAGE ON INTEGRATION SALESFORCE_S3_INT TO ROLE DATASOURCE_RWM;

-- ---------------------------------------------------
-- ファイルフォーマット・外部ステージ
-- 実ファイルの形式が未確認のため、暫定でCSVを仮置き。確認後に要修正
-- ---------------------------------------------------
-- 以降はファンクショナルロールで実行（DATASOURCE_RWM を継承し、DATASOURCE_WH の USAGE を持つ）
USE ROLE DATASOURCE_MANAGER;
USE WAREHOUSE DATASOURCE_WH;

CREATE FILE FORMAT IF NOT EXISTS DATASOURCE.COMMON.CSV_DEFAULT
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE
  COMMENT = '暫定。実ファイル確認後に見直すこと';

CREATE STAGE IF NOT EXISTS DATASOURCE.SALESFORCE.EXT_STAGE
  STORAGE_INTEGRATION = SALESFORCE_S3_INT
  URL = 's3://snowflake-fujitec-storage/inbound/'
  FILE_FORMAT = DATASOURCE.COMMON.CSV_DEFAULT
  COMMENT = 'Salesforceエクスポート（S3経由）取り込み用外部ステージ';

-- 取り込みは一旦COPY INTOで実施（実行例）
-- COPY INTO DATASOURCE.SALESFORCE.<対象テーブル>
--   FROM @DATASOURCE.SALESFORCE.EXT_STAGE/<対象ファイル or プレフィックス>
--   FILE_FORMAT = (FORMAT_NAME = DATASOURCE.COMMON.CSV_DEFAULT)
--   ON_ERROR = 'ABORT_STATEMENT';
