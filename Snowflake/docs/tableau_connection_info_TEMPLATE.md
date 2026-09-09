<!--
Tableau ⇔ Snowflake 接続情報 記録シート（テンプレート）

使い方:
  cp tableau_connection_info_TEMPLATE.md tableau_connection_info.md
  実値を記入する。tableau_connection_info.md は .gitignore 済み（GitHub に上げない）。

禁止事項:
  - PAT の token_secret 本体はこのファイルに書かない（パスワードマネージャ等で別管理）
  - Snowflake ユーザーのパスワード・秘密鍵を書かない
-->

# Tableau ⇔ Snowflake 接続情報

| | |
| --- | --- |
| 記入日 | `<YYYY-MM-DD>` |
| 記入者 | `<氏名>` |
| 用途 | フジテック PoC / 営業パイプライン可視化 |
| ステータス | ☐ 準備中　☐ 疎通確認済　☐ 先方連携済　☐ 本番稼働 |

---

## 1. Snowflake アカウント

| 項目 | 値 |
| --- | --- |
| アカウント識別子 | `<org>-<account>`（例: `SSKMHJJ-VF99886`） |
| アカウント URL | `<org>-<account>.snowflakecomputing.com` |
| ロケーター | `<例: EV13683>` |
| リージョン | `<例: AWS_AP_NORTHEAST_1>` |
| エディション / 契約形態 | `<Standard / Enterprise / トライアル>` |

---

## 2. 接続に使うオブジェクト

| 項目 | 値 | 備考 |
| --- | --- | --- |
| サービスユーザー | `SVC_TABLEAU` | TYPE = SERVICE、参照専用 |
| ロール | `SALES_USER` | PAT の ROLE_RESTRICTION と一致 |
| ウェアハウス | `SALES_WH` | XSMALL / 自動起動 / 60秒で自動停止 |
| データベース | `SALES` | |
| スキーマ | `ANALYTICS_MARTS` | |
| 主な接続先 | `SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE` | 日本語カラム名 |
| 英語カラム版 | `SALES.ANALYTICS_MARTS.V_OPPORTUNITY_LINE_ITEM` | 必要時のみ |

---

## 3. 認証（PAT: Programmatic Access Token）

| 項目 | 値 |
| --- | --- |
| トークン名 | `TABLEAU_PAT` |
| ROLE_RESTRICTION | `SALES_USER` |
| 発行日 | `<YYYY-MM-DD>` |
| 有効期限（DAYS_TO_EXPIRY） | `90` 日 → 失効予定 `<YYYY-MM-DD>` |
| 発行実行者 | `<氏名>` |
| token_secret の保管場所 | `<パスワードマネージャ名 / 項目名>`（★ここに本体は書かない） |
| 受け渡し方法 | `<例: 1Password 共有 / Slack DM 削除前提 など>` |
| 受け渡し日 / 受領者 | `<YYYY-MM-DD>` / `<先方氏名>` |

### ローテーション履歴

| 実施日 | 実施者 | 新失効予定日 | 先方再連携日 | 備考 |
| --- | --- | --- | --- | --- |
| `<YYYY-MM-DD>` | | `<YYYY-MM-DD>` | `<YYYY-MM-DD>` | |

---

## 4. ネットワークポリシー（アクセス元 IP 制限）

| 項目 | 値 |
| --- | --- |
| ポリシー名 | `TABLEAU_PAT_NP` |
| 適用先 | `ALTER USER SVC_TABLEAU SET NETWORK_POLICY = TABLEAU_PAT_NP` |
| 方式 | ☐ ネットワークポリシー（IP許可リスト）　☐ 認証ポリシーで IP 要件を緩和 |

### 許可 IP / CIDR

| # | CIDR | 由来（Pod / 拠点） | 追加日 |
| --- | --- | --- | --- |
| 1 | `<例: 141.163.208.0/23>` | Tableau Cloud `<pod>` | `<YYYY-MM-DD>` |
| 2 | | | |

> Tableau Cloud の Pod 別 IP は
> https://help.tableau.com/current/pro/desktop/en-us/publish_tableau_online_ip_authorization.htm
> または https://ip-ranges.salesforce.com/ip-ranges.json を参照。IP は追加されることがある。

---

## 5. Tableau 側

| 項目 | 値 |
| --- | --- |
| 製品 | ☐ Tableau Cloud　☐ Tableau Server　☐ Tableau Desktop |
| サイト URL | `https://<pod>.online.tableau.com/#/site/<site>` |
| Pod 名 / リージョン | `<例: prod-apnortheast-a / ap-northeast-1>` |
| データソース名 | `<Tableau 上の名称>` |
| パブリッシュ先プロジェクト | `<プロジェクト名>` |
| 接続モード | ☐ ライブ　☐ 抽出（更新スケジュール: `<頻度>`） |
| 認証情報の埋め込み | ☐ あり（埋め込み PAT）　☐ なし |
| 設定実施者 / 日 | `<先方氏名>` / `<YYYY-MM-DD>` |

---

## 6. 動作確認記録

| 確認項目 | 実施日 | 実施者 | 結果 | 備考 |
| --- | --- | --- | --- | --- |
| CLI 疎通（`snow sql -x ... SVC_TABLEAU`） | | | ☐ OK ☐ NG | 期待: `SVC_TABLEAU / SALES_USER / 1000` |
| Tableau からのライブ接続 | | | ☐ OK ☐ NG | |
| 対象テーブルのプレビュー表示 | | | ☐ OK ☐ NG | |
| （抽出の場合）スケジュール更新 | | | ☐ OK ☐ NG | |

### CLI 疎通コマンド（弊社）

```bash
SNOWFLAKE_PASSWORD='<token_secret>' snow sql -x \
  --account '<org>-<account>' --user SVC_TABLEAU \
  --role SALES_USER --warehouse SALES_WH \
  -q "select current_user(), current_role(), count(*) from SALES.ANALYTICS_MARTS.GOLD_OPPORTUNITY_LINE_ITEM_WIDE"
```

---

## 7. 連絡先

| 区分 | 氏名 | 連絡先 | 役割 |
| --- | --- | --- | --- |
| 弊社（ex-ture） | | | Snowflake 設定・PAT 発行・ローテーション |
| 先方（フジテック） | | | Tableau 設定・IP 情報提供 |

---

## 8. 変更履歴

| 日付 | 変更者 | 内容 |
| --- | --- | --- |
| `<YYYY-MM-DD>` | | 初版作成 |
