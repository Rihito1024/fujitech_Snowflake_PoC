-- =====================================================
-- 07_load_gold_opportunity_line_item_wide.sql
-- gold_opportunity_line_item_wide_quoted.csv を SALES.ANALYTICS_MARTS にロード
--
-- 日本語ヘッダー対応のポイント:
--   1. ファイルフォーマットで ENCODING='UTF8' を明示（文字化け防止。実ファイルはUTF-8）
--      ※ もし Shift_JIS のファイルなら ENCODING='WINDOWS932' に変える
--   2. 列名に日本語を使うには 二重引用符付き識別子 "案件名" が必須（裸の識別子に日本語は不可）
--      → 以降 SQL/dbt/BI からは常に "..." で囲み、大文字小文字も完全一致で参照すること
--   3. PARSE_HEADER=TRUE ＋ COPY の MATCH_BY_COLUMN_NAME=CASE_SENSITIVE で
--      「日本語ヘッダー名」で列マッピングする（列順ではなくヘッダー名で対応付け）
--
-- データ型は実CSV(1000行)を確認して付与:
--   - 金額系 NUMBER(15,2) / 比率系 NUMBER(9,2) / 件数・年月 NUMBER
--   - 日付 DATE / タイムスタンプ TIMESTAMP_TZ（値は "...Z" のUTC。AUTOで解釈）
--   - true/false は BOOLEAN、その他は VARCHAR
--   - 全行NULLで判定不能な列は VARCHAR のまま（コメントに推定型を記載）
-- 実行ロール: SALES_MANAGER（SALES__RWM を継承 ＋ SALES_WH USAGE を保有）
-- =====================================================

USE ROLE SALES_MANAGER;
USE WAREHOUSE SALES_WH;
USE SCHEMA SALES.ANALYTICS_MARTS;

-- ---------------------------------------------------
-- 1) 日本語ヘッダーCSV用ファイルフォーマット
-- ---------------------------------------------------
CREATE FILE FORMAT IF NOT EXISTS SALES.ANALYTICS_MARTS.CSV_JA_HEADER
  TYPE = CSV
  ENCODING = 'UTF8'                        -- 日本語(UTF-8)。文字化け防止のため明示
  PARSE_HEADER = TRUE                      -- 1行目を列名として解釈（SKIP_HEADER とは併用不可）
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'       -- カンマ入りの値を囲う二重引用符を解除
  TRIM_SPACE = FALSE
  NULL_IF = ('null', '')                   -- 文字列 "null" と空文字を NULL 扱い
  EMPTY_FIELD_AS_NULL = TRUE
  REPLACE_INVALID_CHARACTERS = TRUE        -- 不正バイトは U+FFFD に置換（保険）
  COMMENT = '日本語ヘッダーのUTF-8 CSV用';

-- ---------------------------------------------------
-- 2) ローカルからのアップロード先 内部ステージ
-- ---------------------------------------------------
CREATE STAGE IF NOT EXISTS SALES.ANALYTICS_MARTS.LOAD_STAGE
  FILE_FORMAT = SALES.ANALYTICS_MARTS.CSV_JA_HEADER
  COMMENT = 'ローカルCSVの PUT アップロード用';

-- ---------------------------------------------------
-- 3) ファイルのアップロード
--    Snowsight のワークシートでは PUT 不可。以下のいずれかで実施する:
--      a) SnowSQL / VSCode拡張 / Python connector で下記 PUT を実行（AUTO_COMPRESSで .csv.gz になる）
--      b) Snowsight 左メニュー Data > Add Data > Load into stage で LOAD_STAGE にアップロード
--         （UIアップロードは圧縮しないので .csv のまま。5)のPATTERNで両対応にしてある）
-- ---------------------------------------------------
-- PUT 'file:///home/rihito/workspace/フジテック/gold_opportunity_line_item_wide_quoted.csv'
--   @SALES.ANALYTICS_MARTS.LOAD_STAGE
--   AUTO_COMPRESS = TRUE
--   OVERWRITE = TRUE;

-- ★アップロード後、必ず実物を確認する（"0 files processed" の主因は名前/パス不一致）
LIST @SALES.ANALYTICS_MARTS.LOAD_STAGE;

-- ---------------------------------------------------
-- 4) テーブル作成（列名 = 日本語ヘッダーそのまま。型は実CSVから判定）
--    ※ 旧・全VARCHAR版を作成済みなら先に:
--      DROP TABLE IF EXISTS SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE;
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE (
  "品目ID"                 VARCHAR,
  "案件ID"                 VARCHAR,
  "案件名"                  VARCHAR,
  "工事番号"                VARCHAR,
  "ビル"                    VARCHAR,
  "ビルID"                 VARCHAR,
  "商談ビル"                VARCHAR,
  "配送モデル"              VARCHAR,           -- 全行NULL
  "BPRモデル"              VARCHAR,
  "品目レコードタイプ"      VARCHAR,
  "業務シートコード"        VARCHAR,
  "表示順"                  VARCHAR,           -- 全行NULL（表示順序。整数の可能性）
  "サービス日"              VARCHAR,           -- 全行NULL（日付の可能性）
  "台数"                    NUMBER(9,0),
  "割引率"                  VARCHAR,           -- 全行NULL（率。数値の可能性）
  "受注予定額"              NUMBER(15,2),
  "定価"                    NUMBER(15,2),
  "小計"                    NUMBER(15,2),
  "合計金額"                NUMBER(15,2),
  "現契約金額"              VARCHAR,           -- 全行NULL（金額の可能性）
  "ML"                      NUMBER(15,2),
  "提示金額"                NUMBER(15,2),
  "見積金額"                NUMBER(15,2),
  "利益"                    NUMBER(15,2),
  "利益率"                  NUMBER(9,2),
  "ML比率"                 NUMBER(9,2),
  "見積比率"                NUMBER(9,2),
  "増減額"                  NUMBER(15,2),
  "フェーズ"                VARCHAR,
  "商談タイプ"              VARCHAR,           -- 全行NULL
  "リードソース"            VARCHAR,           -- 全行NULL
  "フォーキャストカテゴリ"  VARCHAR,
  "フォーキャストカテゴリ名" VARCHAR,
  "受注見込み・応札方針"    VARCHAR,
  "クローズ済み"            BOOLEAN,
  "受注済み"                BOOLEAN,
  "クローズ日"              DATE,
  "受注予定日"              DATE,
  "建築着工日"              DATE,
  "本体着工日"              DATE,
  "据付工期"                DATE,
  "契約納期"                DATE,
  "最終活動日"              DATE,
  "最終フェーズ変更日"      TIMESTAMP_TZ,      -- 例: 2025-12-03T20:04:13.000Z (UTC)
  "商品コード"              VARCHAR,
  "商品名"                  VARCHAR,
  "商品説明"                VARCHAR,           -- 全行NULL
  "商品ファミリー"          VARCHAR,
  "商品有効フラグ"          BOOLEAN,
  "商品アーカイブフラグ"    BOOLEAN,
  "顧客名（契約先）"        VARCHAR,
  "顧客タイプ（契約先）"    VARCHAR,           -- 全行NULL
  "請求先市区町村"          VARCHAR,
  "請求先都道府県"          VARCHAR,
  "請求先国"                VARCHAR,
  "設計事務所"              VARCHAR,
  "建物所有者（施主）"      VARCHAR,
  "建物都道府県"            VARCHAR,           -- JSON配列の文字列 例: ["神奈川県"]
  "建物市区町村"            VARCHAR,           -- JSON配列の文字列 例: []
  "建物住所"                VARCHAR,           -- JSON配列の文字列
  "主担当者"                VARCHAR,
  "主担当者役職"            VARCHAR,
  "主担当者部門"            VARCHAR,           -- 全行NULL
  "主担当部署"              VARCHAR,
  "上位部署名"              VARCHAR,
  "受注エリア"              VARCHAR,
  "受注店所"                VARCHAR,
  "レコードタイプ名"        VARCHAR,
  "クローズ年"              NUMBER(4,0),
  "クローズ月"              NUMBER(2,0),
  "クローズ四半期"          NUMBER(2,0),
  "クローズ会計年度"        NUMBER(4,0),
  "クローズ曜日"            VARCHAR,
  "クローズ月名"            VARCHAR,
  "クローズ年月"            VARCHAR,           -- 例: 2025-12
  "クローズ年四半期"        VARCHAR,           -- 例: 2025-Q3
  "クローズ日週末フラグ"    BOOLEAN,
  "受注予定/年"             NUMBER(4,0),
  "受注予定/月"             NUMBER(2,0),
  "受注予定年度"            NUMBER(4,0),
  "受注予定年月"            VARCHAR,           -- 例: 2024-02
  "受注予定年四半期"        VARCHAR,           -- 例: 2024-Q1
  "サービス年"              VARCHAR,           -- 全行NULL（整数の可能性）
  "サービス月"              VARCHAR,           -- 全行NULL（整数の可能性）
  "サービス会計年度"        VARCHAR,           -- 全行NULL（整数の可能性）
  "サービス年月"            VARCHAR,           -- 全行NULL
  "サービス年四半期"        VARCHAR,           -- 全行NULL
  "品目作成日"              TIMESTAMP_TZ,      -- 例: 2025-12-05T21:04:53.000Z (UTC)
  "品目最終更新日"          TIMESTAMP_TZ       -- 例: 2026-07-22T09:55:34.000Z (UTC)
);

-- 別案: ヘッダーから列を自動推論して作成する場合（型も推論される。手書き不要だが型ブレに注意）
-- CREATE TABLE IF NOT EXISTS SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE
--   USING TEMPLATE (
--     SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
--     FROM TABLE(INFER_SCHEMA(
--       LOCATION => '@SALES.ANALYTICS_MARTS.LOAD_STAGE/gold_opportunity_line_item_wide_quoted.csv.gz',
--       FILE_FORMAT => 'SALES.ANALYTICS_MARTS.CSV_JA_HEADER'
--     ))
--   );

-- ---------------------------------------------------
-- 5) ロード（日本語ヘッダー名で列マッチ）
--    "0 files processed" の場合:
--      - LIST の結果とファイル名が一致しているか（.gz の有無、サブフォルダの有無）
--      - 既ロード済みでスキップされている → FORCE = TRUE で再ロード（下記は付与済み）
--    型変換エラーが出た場合の切り分け:
--      - ON_ERROR = 'CONTINUE' に変えて流し、どの列/値で落ちるか確認
--        （事前チェックは: COPY ... VALIDATION_MODE = 'RETURN_ALL_ERRORS';）
--      - TIMESTAMP_TZ 列("...Z")が解釈できない場合は該当列を VARCHAR に変更してロード後に TO_TIMESTAMP_TZ で変換
-- ---------------------------------------------------
COPY INTO SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE
  FROM @SALES.ANALYTICS_MARTS.LOAD_STAGE
  FILE_FORMAT = (FORMAT_NAME = 'SALES.ANALYTICS_MARTS.CSV_JA_HEADER')
  PATTERN = '.*gold_opportunity_line_item_wide_quoted\.csv(\.gz)?'   -- .gz 有無どちらも拾う
  MATCH_BY_COLUMN_NAME = CASE_SENSITIVE     -- 位置ではなくヘッダー名で対応付け（日本語なので大小区別）
  ON_ERROR = 'ABORT_STATEMENT'
  FORCE = TRUE;                             -- 検証中の再ロード用。確定後は外してよい

-- ---------------------------------------------------
-- 6) 確認
-- ---------------------------------------------------
-- SELECT COUNT(*) FROM SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE;   -- 1000 想定
-- SELECT "案件名", "商品名", "合計金額", "クローズ日" FROM SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE LIMIT 10;
