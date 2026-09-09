# Tableau Cloud ⇔ Snowflake 接続手順（PoC）

Salesforce 由来の営業データ（Snowflake 上のマート）を Tableau Cloud から参照するための
接続手順書です。認証は **PAT（Programmatic Access Token）** を使用します。

- 対象データ: 商談品目ワイドテーブル（1 行 = 商談 × 商品明細）
- 接続ユーザー: `SVC_TABLEAU`（参照専用のサービスユーザー）
- 想定所要時間: 15 分程度

---

## 0. 役割分担

| # | 作業 | 担当 |
| --- | --- | --- |
| 1 | **Tableau Cloud サイトの Pod（リージョン）と Egress IP レンジの共有** | **フジテック** |
| 2 | Snowflake 側のユーザー・権限・ネットワークポリシー作成 | 弊社（ex-ture） |
| 3 | PAT（トークン）の発行 | 弊社（ex-ture） |
| 4 | PAT・接続情報の受け渡し | 弊社 → フジテック（安全な経路で） |
| 5 | **Tableau Cloud でのデータソース作成・パブリッシュ** | **フジテック** |
| 6 | PAT 有効期限前のローテーションと再連携 | 弊社（ex-ture） |

本書の主対象は **1** と **5**（フジテック様の作業）です。2〜4 は付録 A を参照。

### 1 について（先方から弊社へ共有いただくもの）

Snowflake 側でアクセス元 IP を許可リスト方式で制限します。Tableau Cloud から Snowflake
への通信の送信元 IP を許可する必要があるため、以下を共有してください。

- Tableau Cloud サイトの **Pod 名 / デプロイ先リージョン**
  （サイト URL のサブドメイン、例 `10ax`, `us-east-1`, `eu-west-1a` 等。
  管理者メニューの「設定」→ サーバー情報でも確認可）
- 上記 Pod の **Egress IP アドレス / CIDR レンジ**
  （Tableau が Pod 単位で公開。Tableau Cloud のヘルプ「IP アドレスとエンドポイントの
  許可リスト登録」を参照）

> IP を絞らない運用（認証ポリシーで IP 要件自体を外す）も技術的には可能です。
> 方針を変更する場合は弊社にご相談ください（付録 A の代替案）。

---

## 1. 事前に弊社から受け取る情報

| 項目 | 値 | 備考 |
| --- | --- | --- |
| Snowflake アカウント URL | `<弊社から連携>` | 例: `xxxxxxx-xxxxxxx.snowflakecomputing.com` |
| ユーザー名 | `SVC_TABLEAU` | 固定 |
| パスワード欄に入れる値 | `<PAT トークン（弊社から別送）>` | **パスワードではなく PAT を入力**。発行時のみ表示される長い文字列 |
| ロール | `SALES_USER` | |
| ウェアハウス | `SALES_WH` | XSMALL。自動起動・60 秒で自動停止 |
| データベース | `SALES` | |
| スキーマ | `ANALYTICS_MARTS` | |
| 接続先テーブル | `GOLD_OPPORTUNITY_LINE_ITEM_WIDE` | 日本語カラム名（例: 「案件名」「合計金額」） |

> PAT は機密情報です。メール本文に平文で貼らず、パスワード共有ツール等でお渡しします。
> 有効期限は **90 日**。期限が近づいたら弊社がローテーションし、新しい値を再連携します。

---

## 2. Tableau Cloud でのデータソース作成

Tableau Cloud（ブラウザ）または Tableau Desktop から作成できます。ここではブラウザ手順。

### 2-1. 接続の開始

1. Tableau Cloud にサインイン
2. 左メニュー **「新規」→「データソース」**（または Web 作成から「Snowflake」を選択）
3. コネクタ一覧から **Snowflake** を選択

### 2-2. サーバーと認証

| フィールド | 入力値 |
| --- | --- |
| サーバー (Server) | 受領した **Snowflake アカウント URL** |
| 認証 (Authentication) | **「ユーザー名とパスワード」** を選択 |
| ユーザー名 (Username) | `SVC_TABLEAU` |
| パスワード (Password) | 受領した **PAT トークン** をそのまま貼り付け |

> Snowflake の PAT は「パスワードの代わり」として使えます。専用の認証方式を選ぶ必要は
> ありません。Tableau 2024.2 以降で「Snowflake 個人用アクセストークン」の選択肢が
> 出る場合はそちらでも構いません（トークンを同様に貼り付け）。

「サインイン」をクリック。

### 2-3. ロール / ウェアハウスの指定

接続後の詳細設定で以下を選択（プルダウンに表示されます）。

| フィールド | 値 |
| --- | --- |
| ロール (Role) | `SALES_USER` |
| ウェアハウス (Warehouse) | `SALES_WH` |

### 2-4. テーブルの選択

1. データベース: **`SALES`**
2. スキーマ: **`ANALYTICS_MARTS`**
3. テーブル: **`GOLD_OPPORTUNITY_LINE_ITEM_WIDE`** をキャンバスにドラッグ

これで 1 テーブルのデータソースになります（結合不要。全ディメンション結合済みの
ワイドテーブルです）。

### 2-5. 接続モード

- **ライブ接続**を推奨（データ量が少なく、`SALES_WH` は自動起動のため）
- 抽出（Extract）にする場合は、パブリッシュ後にスケジュール更新を設定

### 2-6. パブリッシュ

1. データソース名を付けて Tableau Cloud にパブリッシュ
2. 認証情報の扱い: **「埋め込みパスワード」**（＝埋め込み PAT）を選択
   - スケジュール更新やダッシュボードの共有を行う場合に必要
   - PAT ローテーション時は、このデータソースの「接続の編集」から新トークンに更新

---

## 3. 使う上での注意

- **カラム名が日本語**です（「案件名」「クローズ日」「合計金額」など）。
  Tableau の GUI 操作では問題ありませんが、カスタム SQL を書く場合は
  `SELECT "案件名", "合計金額" FROM ...` のように **二重引用符**で囲んでください。
- `SVC_TABLEAU` は **参照専用**（`SELECT` のみ）。書き込み・DDL はできません。
- 同ユーザーは `SALES` データベースのマート層のみ参照可能です。
- 英語カラム名が必要な場合は、同スキーマのビュー
  `SALES.ANALYTICS_MARTS.V_OPPORTUNITY_LINE_ITEM`（列名を英語エイリアスにしたもの）も
  利用できます。

---

## 4. トラブルシューティング

| 症状 | 原因 / 対処 |
| --- | --- |
| `Incorrect username or password` | PAT の期限切れ、またはコピー漏れ（前後の空白・改行）。弊社に再発行を依頼 |
| `Role 'SALES_USER' ... not granted` / ロールが選べない | PAT のロール制限と不一致。弊社に連絡 |
| `IP address x.x.x.x is not allowed to access Snowflake` | その送信元 IP がネットワークポリシーの許可リストに未登録。エラー文中の IP を弊社へ連携し、許可リストに追加してもらう（Tableau Cloud のメンテナンス等で Egress IP が増えることがある） |
| ウェアハウスが起動しない / タイムアウト | `SALES_WH` は自動起動。初回クエリで数秒待ちが発生。再試行で解消 |
| 数値が想定と違う | マートの仕様差異の可能性。弊社と数値突合を実施 |

---

## 付録 A. 弊社（ex-ture）側で実施する Snowflake 設定

`Snowflake/sql/06_users.sql` に含まれます。要点のみ:

```sql
USE ROLE SECURITYADMIN;

-- 1) サービスユーザー
CREATE USER IF NOT EXISTS SVC_TABLEAU
  TYPE = SERVICE
  DEFAULT_ROLE = SALES_USER
  DEFAULT_WAREHOUSE = SALES_WH;
GRANT ROLE SALES_USER TO USER SVC_TABLEAU;   -- 参照権限は SALES_USER → SALES__R

-- 2) ネットワークポリシー: PAT の前提。先方共有の Tableau Cloud Egress IP を許可
CREATE NETWORK POLICY IF NOT EXISTS TABLEAU_PAT_NP
  ALLOWED_IP_LIST = ('<先方共有の IP/CIDR を列挙>');
ALTER USER SVC_TABLEAU SET NETWORK_POLICY = TABLEAU_PAT_NP;

-- 3) PAT 発行（Snowsight で手動実行。token_secret は発行時のみ表示）
ALTER USER IF EXISTS SVC_TABLEAU ADD PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT
  ROLE_RESTRICTION = 'SALES_USER'
  DAYS_TO_EXPIRY = 90;
```

発行結果の `token_secret` を安全な経路でフジテック様へ受け渡します。

> 代替案（IP を絞らない場合）: ネットワークポリシーの代わりに認証ポリシーで
> `PAT_POLICY = (NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED)` を設定し
> `SVC_TABLEAU` に適用する。詳細は `Snowflake/sql/06_users.sql` のコメント。

### ローテーション（90 日ごと）

```sql
ALTER USER IF EXISTS SVC_TABLEAU ROTATE PROGRAMMATIC ACCESS TOKEN TABLEAU_PAT
  EXPIRE_ROTATED_TOKEN_AFTER_HOURS = 24;   -- 旧トークンは 24 時間後に失効
```

新 `token_secret` を再連携 → フジテック様が Tableau データソースの接続情報を更新。

---

## 付録 B. 疎通確認（弊社）

PAT 発行後、弊社側で以下を実行して接続を確認します。

```bash
SNOWFLAKE_PASSWORD='<token_secret>' snow sql --temporary-connection \
  --account '<アカウント>' --user SVC_TABLEAU \
  --role SALES_USER --warehouse SALES_WH \
  -q "select current_user(), current_role(),
      count(*) from SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE;"
```

期待値: `SVC_TABLEAU` / `SALES_USER` / `1000`（PoC データ）。
