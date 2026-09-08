# dbt_project (Snowflake)

フジテック PoC の営業パイプライン用 dbt プロジェクト。Salesforce の Raw データ
（Snowflake `DATASOURCE.SALESFORCE`）をステージング層でクレンジングし、ディメンショナル
モデル（dim / fact / bridge）と BI 抽出用のワイドテーブル（gold）に整形する。

もとは Databricks Lakeflow Declarative Pipelines（`transformations/silver`,
`transformations/gold`）からの移植。ロジック（削除済みレコード除外・列名の英語スネーク
ケース化・型キャスト）は同一。

## レイヤー構成

| レイヤー | 配置 | 命名 | materialization | 出力スキーマ |
| --- | --- | --- | --- | --- |
| ステージング（クレンジング） | `models/staging/` | `stg_*` | view | `<profile schema>_STAGING` |
| マート | `models/mart/` | `dim_*` / `fact_*` / `bridge_*` / `gold_*` | table | `<profile schema>_MARTS` |

- Raw（Salesforce）データは `models/staging/_sources.yml` の
  `source('salesforce', ...)` で定義。参照先は `DATASOURCE.SALESFORCE`（ハードコード）。
  取り込み方式・スキーマ配置は `../Snowflake/sql/02_databases_and_schemas.sql`,
  `../Snowflake/sql/04_storage_integration_and_stage.sql` と対応。
- スキーマ名は `dbt_project.yml` の各レイヤー `+schema`（`staging` / `marts`）と
  dbt 標準の `generate_schema_name`（`<target.schema>_<+schema値>`）で決まる。
  profile の `schema: ANALYTICS` なら `ANALYTICS_STAGING` / `ANALYTICS_MARTS` に出力される。
  ※ 以前あった `macros/generate_schema_name.sql`（`silver` / `gold` をそのまま使う上書き）は廃止。
  ※ `../Snowflake/sql/02_databases_and_schemas.sql` は現状 `SALES.ANALYTICS_INTERMEDIATE` を
    作成している。ステージング層の出力先（`ANALYTICS_STAGING`）と名前が異なるため、
    Snowflake 側スキーマ名か `dbt_project.yml` の `+schema` のどちらかを合わせること。

## セットアップ

`profiles.yml`（`~/.dbt/profiles.yml` など）に以下を追加（値は環境に合わせて置き換え）。

```yaml
dbt_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "<snowflake_account>"
      user: "{{ env_var('DBT_SNOWFLAKE_USER') }}"
      private_key_path: "{{ env_var('DBT_SNOWFLAKE_KEY_PATH') }}"  # キーペア認証推奨
      role: "SALES_TRANSFORMER"          # ../Snowflake/sql/01_roles_and_warehouse.sql で作成
      database: "SALES"                  # ステージング / マートモデルの出力先DB
      warehouse: "SALES_WH"
      schema: "ANALYTICS"                # generate_schema_name で _STAGING / _MARTS が付く
      threads: 4
```

Raw（Salesforce）データの参照先 `DATASOURCE.SALESFORCE` は `models/staging/_sources.yml`
に直接記載しているため、`dbt_project.yml` の `vars` 設定は不要（旧
`bronze_database` / `bronze_schema` は廃止）。環境で参照先を変える場合は
`_sources.yml` の `database:` / `schema:` を編集する。

## 実行

```bash
dbt deps      # パッケージ依存なし（現状は未使用）
dbt debug     # 接続確認
dbt build     # 全モデル実行 + テスト
```

## 移行時の注意点・要確認事項（TODO）

1. **Raw テーブルの列名ケース**: モデルは `Id` / `IsDeleted` / `AccountId` のような
   Salesforce 由来の PascalCase 列名をそのまま参照している。Snowflake の非引用識別子は
   大文字小文字を区別しないためこのままで解決できるはずだが、取り込み方式（外部ステージ /
   Openflow）によっては列が引用符付き識別子で格納されるケースがある。
   `dbt run` 前に `describe table` 等で実列名を確認し、必要なら
   `models/staging/stg_*.sql` の列参照をダブルクォートに変更すること。
2. **`user` ソーステーブル**: `USER` は Snowflake の予約語のため
   `_sources.yml` で `quoting.identifier: true` を設定済み。
   実テーブル名の大文字小文字が異なる場合は調整が必要。
3. **`dim_date`**: Databricks 版は `sequence()+explode()` で日付範囲を生成していたが、
   Snowflake には同等の SQL 関数が無いため `GENERATOR(rowcount => ...)` + `SEQ4()` による
   デイトスパイン方式に変更した。`rowcount` は将来的な実行日を考慮して余裕を持たせている
   （約60年分）。曜日名・月名は Snowflake に `EEEE`/`MMMM` 相当の書式指定が無いため
   `CASE` 式で組み立てている。
4. **`collect_set` → `ARRAY_AGG(DISTINCT ...)`**: `gold_opportunity_line_item_wide` の
   建物所在地の集約で使用。Spark の collectSet は NULL を除外するが、Snowflake の
   `ARRAY_AGG` は NULL を含める可能性がある点が挙動差として残っている
   （建物未紐付けの商談で `NULL` が配列要素に混在し得る）。運用上問題になる場合は
   集約対象を事前に `WHERE address_state IS NOT NULL` 等でフィルタすること。
5. **`cluster_by`**: Databricks 版で Liquid Clustering（`cluster_by_auto=True`）だった
   `fact_opportunity_line_item` / `gold_opportunity_wide` / `gold_opportunity_line_item_wide`
   は、Snowflake に自動選択機能が無いため代表的なキー列を明示的な `cluster_by` として
   設定した（実運用のクエリパターンに応じて見直すこと）。
6. **日本語列名（マート最終出力）**: `gold_opportunity_wide` /
   `gold_opportunity_line_item_wide` の最終列名は元コードと同じ日本語。
   Snowflake の非引用識別子は日本語を含められないため、全てダブルクォートで
   引用識別子として定義している。BI ツール側の接続時もこの点に注意。
