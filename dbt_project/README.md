# flatpad dbt (Snowflake)

`Databicks_flatpad_pipeline_bundle/flatpad_pipeline_bundle` の Databricks Lakeflow
Declarative Pipelines（`transformations/silver`, `transformations/gold`）を
dbt-Snowflakeプロジェクトとして移植したものです。

## レイヤー対応

| Databricks版 | dbt版 | 配置 | materialization |
| --- | --- | --- | --- |
| `transformations/silver/*.py`（`@dp.materialized_view`） | `models/staging/stg_*.sql` | `silver`スキーマ | view |
| `transformations/gold/*.py`（`@dp.materialized_view`） | `models/marts/*.sql` | `gold`スキーマ | table |

- Bronze層（`bronze_catalog.bronze_schema.*` の生Salesforceデータ）は
  `models/staging/_flatpad__sources.yml` の `source('flatpad_bronze', ...)` として定義。
- `silver_*` → `stg_*` にリネーム（dbtの一般的な命名規則 `stg_<object>` に合わせた）。
  中身のロジック（削除済みレコード除外・列名の英語スネークケース化・型キャスト）は同一。
- `dim_*` / `fact_*` / `bridge_*` / `gold_*` はDatabricks版と同名のまま。
- スキーマ名は `models/`配下の `+schema` 設定と `macros/generate_schema_name.sql` により
  `<target_schema>_silver` ではなく `silver` / `gold` そのものになるようにしている
  （Databricks版のカタログ/スキーマ構成に近づけるため）。

## セットアップ

`profiles.yml`（`~/.dbt/profiles.yml` など）に以下のような設定を追加してください
（値は環境に合わせて置き換え）。

```yaml
flatpad:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "<snowflake_account>"
      user: "{{ env_var('DBT_SNOWFLAKE_USER') }}"
      password: "{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}"
      role: "<role>"
      database: "<transform_database>"   # マート/ステージングモデルの出力先DB
      warehouse: "<warehouse>"
      schema: "flatpad"                  # generate_schema_nameで上書きされるため実質未使用
      threads: 4
```

Bronze（Raw）データのデータベース/スキーマは `dbt_project.yml` の `vars` で指定します。
Databricks版の `databricks.yml` にあった `bronze_catalog` / `bronze_schema` 変数に相当します。

```yaml
vars:
  bronze_database: "FLATPAD_RAW_INGESTED"
  bronze_schema: "PUBLIC"
```

環境ごとに変える場合は `--vars '{"bronze_database": "..."}'` またはターゲット別の
`dbt_project.yml` 上書き（`vars:` を target 分岐させる、もしくは複数プロファイル target を用意）
で対応してください。

## 実行

```bash
dbt deps      # パッケージ依存なし（現状は未使用）
dbt debug     # 接続確認
dbt build     # 全モデル実行 + テスト
```

## 移行時の注意点・要確認事項（TODO）

1. **Bronzeテーブルの列名ケース**: 元コードは `Id` / `IsDeleted` / `AccountId` のような
   Salesforce由来のPascalCase列名をそのまま参照している。Snowflakeの非引用識別子は
   大文字小文字を区別しないためこのままで解決できるはずだが、Bronze側の取り込み方式
   （Fivetran等）によっては列が引用符付き識別子で格納されているケースがある。
   `dbt run` 前に `describe table` 等で実列名を確認し、必要なら
   `models/staging/stg_*.sql` の列参照をダブルクォートに変更すること。
2. **`user` ソーステーブル**: `USER` はSnowflakeの予約語のため
   `_flatpad__sources.yml` で `quoting.identifier: true` を設定済み。
   実テーブル名の大文字小文字が異なる場合は調整が必要。
3. **`dim_date`**: Databricks版は `sequence()+explode()` で日付範囲を生成していたが、
   Snowflakeには同等のSQL関数が無いため `GENERATOR(rowcount => ...)` + `SEQ4()` による
   デイトスパイン方式に変更した。`rowcount` は将来的な実行日を考慮して余裕を持たせている
   （約60年分）。曜日名・月名はSnowflakeに `EEEE`/`MMMM` 相当の書式指定が無いため
   `CASE`式で組み立てている。
4. **`collect_set` → `ARRAY_AGG(DISTINCT ...)`**: `gold_opportunity_line_item_wide` の
   建物所在地の集約で使用。SparkのcollectSetはNULLを除外するが、Snowflakeの
   `ARRAY_AGG`はNULLを含める可能性がある点が挙動差として残っている
   （建物未紐付けの商談で `NULL` が配列要素に混在し得る）。運用上問題になる場合は
   集約対象を事前に `WHERE address_state IS NOT NULL` 等でフィルタすること。
5. **`cluster_by_auto`**: Databricks版の一部テーブル（`fact_opportunity_line_item`,
   `gold_opportunity_wide`, `gold_opportunity_line_item_wide`）は
   Liquid Clustering（`cluster_by_auto=True`）を使用していた。Snowflakeには
   同等の「自動選択」機能が無いため、それぞれ代表的なキー列を明示的な
   `cluster_by` として設定した（実運用のクエリパターンに応じて見直すこと）。
6. **日本語列名（マート最終出力）**: `gold_opportunity_wide` /
   `gold_opportunity_line_item_wide` の最終列名は元コードと同じ日本語。
   Snowflakeの非引用識別子は日本語を含められないため、全てダブルクォートで
   引用識別子として定義している。BIツール側の接続時もこの点に注意。
