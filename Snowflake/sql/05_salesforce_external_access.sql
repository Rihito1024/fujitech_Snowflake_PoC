-- =====================================================
-- 05_salesforce_external_access.sql
-- Openflow 関連の Snowflake 側セットアップ:
--   (A) Salesforce API 疎通用の Network Rule / Secret / External Access Integration
--   (B) Openflow の 管理 / 運用（人間）権限を 既存の DATASOURCE ロール階層に寄せて付与
--         - DATASOURCE_ADMIN   … デプロイメント作成/アップグレード等の構築系（アカウントレベル権限）
--         - DATASOURCE_MANAGER … 日常運用（コネクタ操作・キャンバス編集・ログ確認）＋ UI ログイン
--       ※ 専用の OPENFLOW_* ロールは作らない。
--   (C) 取り込み専用ウェアハウス OPENFLOW_WH + リソースモニター OPENFLOW_RM
--   (D) Openflow ランタイム実行ロール DATASOURCE_OPENFLOW
--         … ランタイム作成時に「実行ロール」として指定する専用ロール。ランタイムのプロセスが
--           このロールでデータ操作（EAI 利用・DATASOURCE.SALESFORCE 書込）を行う。人間はログインに使わない。
--           dbt 側の SALES_TRANSFORMER と対。
-- 参照:
--   ../構成.md #### データ取り込み（Openflow 直接接続）, #### タスク/監視
--   https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow
--   https://docs.snowflake.com/en/user-guide/data-integration/openflow/connectors/salesforce/setup
--
-- 前提:
--   - 01_roles_and_warehouse.sql … DATASOURCE 系ロール階層
--       （DATASOURCE_MANAGER ⊃ DATASOURCE__RWM ⊃ __RW ⊃ __R、DATASOURCE_ADMIN ⊃ DATASOURCE_MANAGER）
--   - 02_databases_and_schemas.sql … DATASOURCE.SALESFORCE スキーマ
--   - 03_grants.sql … DATASOURCE__R / __RW / __RWM への権限付与（Future Grants 含む）
--       → DATASOURCE__RWM は DATASOURCE.SALESFORCE への
--         USAGE / SELECT / INSERT / UPDATE / DELETE / TRUNCATE / CREATE TABLE を保有
--         （コネクタが宛先テーブルを自動作成 → CDC マージ更新するのに十分）
--   - 先方のSalesforceサービスユーザー払い出し待ち（下記 <TODO> / コメントアウトを置換）
--
-- 実行順の目安:
--   1) このファイルで (A)〜(D) を流す（APPLICATION ROLE 付与・プール GRANT・Secret 関連は TODO のまま）
--   2) 構築担当は DATASOURCE_ADMIN で Openflow UI にログイン
--        ※ ACCOUNTADMIN / SECURITYADMIN / ORGADMIN は OAuth で既定ブロックされ UI ログイン不可。
--          DATASOURCE_ADMIN / DATASOURCE_MANAGER はカスタムロールなのでブロック対象外。
--          ログインに使うロールは各ユーザーの DEFAULT_ROLE。必要なら
--          ALTER USER "<user>" SET DEFAULT_ROLE = DATASOURCE_MANAGER; で切り替える。
--   3) UI で Openflow デプロイメントを作成（Native App / SPCS コンピュートプール / UI 公開）
--   4) APPLICATION ROLE <app>.OPENFLOW_ADMIN を DATASOURCE_MANAGER に付与
--        （DATASOURCE_ADMIN は DATASOURCE_MANAGER を内包するため自動継承）
--   5) コンピュートプール名を確認して DATASOURCE_OPENFLOW へ USAGE を付与（(D) の TODO）
--   6) UI でランタイム作成時に、実行ロール = DATASOURCE_OPENFLOW / ウェアハウス = OPENFLOW_WH を指定
--   7) ランタイムオブジェクトの Manage access（USAGE / OPERATE / MONITOR /
--        CREATE OPENFLOW CONNECTOR ON SCHEMA 等）は DATASOURCE_MANAGER に付与（(B) 末尾のメモ参照）
--   8) 日常運用者は DATASOURCE_MANAGER で UI にログイン
--
-- 実行ロール:
--   ACCOUNTADMIN … NETWORK RULE / SECRET / EAI / RESOURCE MONITOR / COMPUTE POOL、
--                  (B) のアカウントレベル権限、EAI USAGE 付与
--   SYSADMIN … OPENFLOW_WH の作成
--   SECURITYADMIN … DATASOURCE_OPENFLOW の作成、WH / ロールの GRANT
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------
-- (A) Salesforce API 疎通（Network Rule / Secret / External Access Integration）
-- ---------------------------------------------------
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

-- ---------------------------------------------------
-- (B) Openflow の 管理 / 運用（人間）権限を DATASOURCE ロール階層に付与
--
--   [構築系] DATASOURCE_ADMIN … デプロイメント作成/アップグレードに必要なアカウントレベル権限。
--     ※ これにより DATASOURCE_ADMIN は実質アカウント管理者級に格上げされ、
--        01 で SYSADMIN に内包しているため SYSADMIN にも継承される。影響を許容できない場合は
--        初回デプロイ/アップグレード時のみ付与し、完了後に REVOKE する運用にする。
--   [運用系] DATASOURCE_MANAGER … コネクタ操作・キャンバス編集・ログ確認、および UI ログイン。
--        （データ書き込みはランタイム実行ロール DATASOURCE_OPENFLOW 側＝(D)）
-- ---------------------------------------------------

-- 構築系（アカウントレベル。バージョンにより増減し得るため setup-openflow ドキュメントで要確認）
GRANT CREATE DATABASE       ON ACCOUNT TO ROLE DATASOURCE_ADMIN;
GRANT CREATE WAREHOUSE      ON ACCOUNT TO ROLE DATASOURCE_ADMIN;
GRANT CREATE COMPUTE POOL   ON ACCOUNT TO ROLE DATASOURCE_ADMIN;
GRANT CREATE INTEGRATION    ON ACCOUNT TO ROLE DATASOURCE_ADMIN;  -- External Access / OAuth 等すべてのインテグレーション
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE DATASOURCE_ADMIN;  -- Openflow UI のイングレス公開
GRANT CREATE APPLICATION    ON ACCOUNT TO ROLE DATASOURCE_ADMIN;  -- Openflow Native App のインストール
GRANT CREATE ROLE           ON ACCOUNT TO ROLE DATASOURCE_ADMIN;
GRANT MANAGE GRANTS         ON ACCOUNT TO ROLE DATASOURCE_ADMIN;  -- セットアップ中のロール付与

-- 運用系が UI でランタイムに EAI を割り当てられるよう USAGE を付与
GRANT USAGE ON INTEGRATION SALESFORCE_ACCESS_INT TO ROLE DATASOURCE_MANAGER;

-- デプロイメント作成後（手順4）: Native App のアプリケーションロールを付与
-- （アプリ名はインストール時に決めた名前。既定は OPENFLOW。DATASOURCE_ADMIN は内包で継承）
-- GRANT APPLICATION ROLE <TODO: Openflowアプリ名>.OPENFLOW_ADMIN TO ROLE DATASOURCE_MANAGER;
--   ※ 運用系をより絞るなら OPENFLOW_ADMIN の代わりに OPENFLOW_USER:
-- GRANT APPLICATION ROLE <TODO: Openflowアプリ名>.OPENFLOW_USER  TO ROLE DATASOURCE_MANAGER;

-- Openflow ランタイムオブジェクトのアクセス管理（UI: ランタイム > Manage access で設定）
--   ランタイム名: Openflow_Runtime / 対象スキーマ: DATASOURCE.SALESFORCE
--   USAGE / OPERATE / MONITOR / USAGE ON SCHEMA / CREATE OPENFLOW CONNECTOR ON SCHEMA /
--   USAGE ON DATABASE をすべて DATASOURCE_MANAGER のみに付与済み。
--   SQL で再現する場合（構文は Snowflake バージョンで変わり得る。実体は上記 UI 操作）:
-- GRANT USAGE, OPERATE, MONITOR ON OPENFLOW RUNTIME Openflow_Runtime TO ROLE DATASOURCE_MANAGER;
-- GRANT CREATE OPENFLOW CONNECTOR ON SCHEMA DATASOURCE.SALESFORCE  TO ROLE DATASOURCE_MANAGER;

-- ---------------------------------------------------
-- (C) 取り込み専用ウェアハウス + リソースモニター
--   CDC 定常負荷用。アドホック用途の DATASOURCE_WH と分離（コスト按分・競合回避）。
--   CREDIT_QUOTA は仮値。通知先（Notification Integration）は構成.md で未定のため未設定。
-- ---------------------------------------------------
USE ROLE SYSADMIN;
CREATE WAREHOUSE IF NOT EXISTS OPENFLOW_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Openflow 取り込み（Salesforce CDC）専用。サイズ・自動停止秒数は要調整';

USE ROLE ACCOUNTADMIN;
CREATE RESOURCE MONITOR IF NOT EXISTS OPENFLOW_RM WITH
  CREDIT_QUOTA = 100
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 80 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE OPENFLOW_WH SET RESOURCE_MONITOR = OPENFLOW_RM;

USE ROLE SECURITYADMIN;
GRANT OPERATE, MODIFY ON WAREHOUSE OPENFLOW_WH TO ROLE DATASOURCE_ADMIN;
GRANT USAGE           ON WAREHOUSE OPENFLOW_WH TO ROLE DATASOURCE_MANAGER;  -- 運用時の手動確認用

-- ---------------------------------------------------
-- (D) Openflow ランタイム実行ロール（DATASOURCE_OPENFLOW）
--   Openflow UI でランタイム作成時に「実行ロール」として指定する専用ロール。
--   ランタイムのプロセスがこのロールでデータ操作を行う（人間はログインに使わない）。
--   dbt 側の SALES_TRANSFORMER と対。
--     - DATASOURCE__RWM 継承 … DATASOURCE.SALESFORCE への
--         USAGE / SELECT / INSERT / UPDATE / DELETE / TRUNCATE / CREATE TABLE（03_grants.sql 由来）
-- ---------------------------------------------------
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS DATASOURCE_OPENFLOW
  COMMENT = 'Openflow ランタイム実行ロール。DATASOURCE.SALESFORCE 書込 + EAI/Secret/WH/プール USAGE。人間はログインに使わない';

GRANT ROLE DATASOURCE__RWM TO ROLE DATASOURCE_OPENFLOW;

-- 管理系ロールから見えるように内包
GRANT ROLE DATASOURCE_OPENFLOW TO ROLE DATASOURCE_ADMIN;
GRANT ROLE DATASOURCE_OPENFLOW TO ROLE SYSADMIN;

-- Openflow の Snowflake 接続サービスユーザー SVC_OPENFLOW（キーペア認証）への付与は 06_users.sql。
--   DEFAULT_ROLE = DATASOURCE_OPENFLOW にして接続ユーザーとランタイム実行ロールを揃える。

-- 取り込み用ウェアハウス
GRANT USAGE ON WAREHOUSE OPENFLOW_WH TO ROLE DATASOURCE_OPENFLOW;

-- EAI（EXTERNAL ACCESS INTEGRATION の付与は所有ロールか MANAGE GRANTS が必要）
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON INTEGRATION SALESFORCE_ACCESS_INT TO ROLE DATASOURCE_OPENFLOW;

-- Secret 本体（(A) 上部）のコメントアウト解除と同時に有効化する
-- GRANT READ ON SECRET DATASOURCE.SALESFORCE.SALESFORCE_CREDENTIALS TO ROLE DATASOURCE_OPENFLOW;

-- コンピュートプール（Openflow デプロイメント作成時に払い出される。手順5で名前確定後）
--   SHOW COMPUTE POOLS; で名称を確認（例: OPENFLOW_<deployment>_RUNTIME_POOL）
-- GRANT USAGE ON COMPUTE POOL <TODO: Openflowランタイム用プール名> TO ROLE DATASOURCE_OPENFLOW;
