# SOLID Score 分析レポート: muu プロジェクト

**日時**: 2026-03-26
**ツールバージョン**: solid-score v0.1.0 (Phase 2a + 2b + 2c)
**対象**: `app/` + `lib/` 全体

---

## 1. サマリ

| 指標 | 値 |
|------|-----|
| 総クラス数 | 1,241 |
| **全体平均** | **90.2** |
| 完全スコア (100点) | 675 クラス (54.4%) |
| 50点未満 | 55 クラス (4.4%) |

### Phase 2c (Railsコンテキスト認識) の改善効果

| 指標 | Before | After | 改善 |
|------|--------|-------|------|
| 全体平均 | 87.4 | 90.2 | +2.8 |
| 50点未満 | 96 | 55 | -41 (43%削減) |
| DIP=0 | 163 | 50 | -113 (69%削減) |

## 2. レイヤー別スコア

| レイヤー | クラス数 | 平均スコア | 50点未満 | 評価 |
|---------|---------|-----------|---------|------|
| serializers | 11 | 96.2 | 0 | 優秀 |
| lib | 283 | 94.2 | 3 | 優秀 |
| mailers | 29 | 95.2 | 0 | 優秀 |
| services | 182 | 93.9 | 1 | 優秀 |
| jobs | 9 | 87.9 | 0 | 良好 |
| other | 57 | 87.8 | 0 | 良好 |
| validators | 23 | 86.8 | 0 | 良好 |
| models | 382 | 88.3 | 48 | 良好 |
| controllers | 246 | 86.6 | 1 | 良好 |
| forms | 19 | 82.1 | 2 | 良好 |

## 3. 原則別平均スコア

| 原則 | 平均 | 評価 |
|------|------|------|
| SRP (単一責任) | 87.3 | 良好 |
| OCP (開放閉鎖) | 83.5 | 改善余地あり |
| LSP (リスコフ置換) | 97.2 | 非常に良好 |
| ISP (インターフェース分離) | 94.5 | 良好 |
| DIP (依存性逆転) | 91.4 | 良好 |

## 4. スコア分布

| レンジ | クラス数 | 割合 | 状態 |
|--------|---------|------|------|
| 0-29 (Critical) | 5 | 0.4% | 要リファクタリング |
| 30-49 (Low) | 50 | 4.0% | 要改善 |
| 50-69 (Medium) | 121 | 9.8% | 改善推奨 |
| 70-84 (Good) | 118 | 9.5% | 概ね良好 |
| 85-99 (High) | 272 | 21.9% | 良好 |
| 100-100 (Perfect) | 675 | 54.4% | 問題なし |

## 5. 要改善クラス: Models (50点未満 48件)

### Critical (30点未満)

| クラス | SRP | OCP | LSP | ISP | DIP | Total | 主な課題 |
|--------|-----|-----|-----|-----|-----|-------|---------|
| ApiV2::DomainPurchaseResult | 0 | 40.0 | 0 | 5 | 50.0 | 19.5 | SRP:0, OCP:40.0, ISP:5 |
| ApiV2::Domain | 0 | 40.0 | 0 | 25 | 50.0 | 23.5 | SRP:0, OCP:40.0, ISP:25 |
| ApiV2::DomainPurchasePreview | 0 | 40.0 | 25.0 | 25 | 50.0 | 26.0 | SRP:0, OCP:40.0, ISP:25 |
| ApiV2::AiSiteBuilderOptionUpdateRequest | 0 | 40.0 | 40.0 | 25 | 50.0 | 27.5 | SRP:0, OCP:40.0, ISP:25 |

### Low (30-49)

| クラス | SRP | OCP | LSP | ISP | DIP | Total |
|--------|-----|-----|-----|-----|-----|-------|
| ApiV2::AiSiteBuilderOption | 0 | 40.0 | 0 | 5 | 100 | 32.0 |
| ApiV2::DomainProvisionableResponseData | 0 | 40.0 | 55.0 | 45 | 50.0 | 33.0 |
| ApiV2::DomainSearchResult | 0 | 40.0 | 55.0 | 45 | 50.0 | 33.0 |
| ApiV2::Error | 0 | 40.0 | 70.0 | 45 | 50.0 | 34.5 |
| ApiV2::GetOidcDiscovery200Response | 0 | 40.0 | 0 | 25 | 100 | 36.0 |
| ApiV2::PartnerGwsCustomer | 0 | 40.0 | 0 | 25 | 100 | 36.0 |
| ApiV2::PartnerGwsEntitlement | 0 | 40.0 | 0 | 25 | 100 | 36.0 |
| ApiV2::AiSiteBuilderContract | 0 | 40.0 | 10.0 | 25 | 100 | 37.0 |
| ApiV2::DnsRecord | 0 | 40.0 | 10.0 | 25 | 100 | 37.0 |
| ApiV2::GetOidcJwks200ResponseKeysInner | 0 | 40.0 | 10.0 | 25 | 100 | 37.0 |
| ApiV2::PartnerGwsCustomerCreateRequest | 0 | 40.0 | 10.0 | 25 | 100 | 37.0 |
| ApiV2::DnsRecordCreateRequest | 0 | 40.0 | 25.0 | 25 | 100 | 38.5 |
| ApiV2::OrgPostalAddress | 0 | 40.0 | 25.0 | 25 | 100 | 38.5 |
| ApiV2::DnsRecordUpdateRequest | 0 | 40.0 | 55.0 | 45 | 100 | 45.5 |
| ApiV2::DomainContract | 0 | 40.0 | 55.0 | 45 | 100 | 45.5 |
| ApiV2::PaginationMeta | 0 | 40.0 | 55.0 | 45 | 100 | 45.5 |
| ApiV2::AiSiteBuilderOptionListResponse | 0 | 40.0 | 70.0 | 45 | 100 | 47.0 |
| ApiV2::DnsRecordsResponse | 0 | 40.0 | 70.0 | 45 | 100 | 47.0 |
| ApiV2::DomainListResponse | 0 | 40.0 | 70.0 | 45 | 100 | 47.0 |
| ApiV2::DomainPurchasePreviewRequest | 0 | 40.0 | 70.0 | 45 | 100 | 47.0 |

*...他 24 件*

## 6. 要改善クラス: Controllers (50点未満 1件)

| クラス | SRP | OCP | LSP | ISP | DIP | Total |
|--------|-----|-----|-----|-----|-----|-------|
| Checkout::SessionsController | 0 | 30.0 | 100.0 | 85 | 60.0 | 46.5 |

## 7. 要改善クラス: lib (50点未満 3件)

| クラス | SRP | OCP | LSP | ISP | DIP | Total |
|--------|-----|-----|-----|-----|-----|-------|
| Muumuu::RegistrarApi::Onamae | 0 | 80.0 | 100 | 25 | 0.0 | 27.0 |
| Muumuu::GoogleCloudChannel::Client::Entitlement | 0 | 50.0 | 100 | 65 | 0 | 30.5 |
| Muumuu::GoogleCloudChannel::Client::Customer | 50 | 50.0 | 100 | 80 | 0.0 | 48.5 |

## 8. 改善提案

### 優先度: 高 (Godモデル分割)

50点未満のモデル群は、LCOM4が高く複数の責務を持つGodモデルが多い。
ビジネスロジックをService層に抽出し、モデルはデータアクセスとバリデーションに集中させる。

### 優先度: 中 (Concern肥大化)

DomainOrderable等の大規模Concernは、より小さな責務のConcernに分割する。

### 優先度: 低 (OCP改善)

case/when分岐が多いクラスは、ポリモーフィズムやStrategyパターンへの置き換えを検討。

## 9. 全体評価

- **54%のクラスが満点、86%が70点以上** — 全体的にコード品質は高い
- **services/lib/mailers層は平均93点台** — Service層への責務移行が進んでいる
- **Controller層の偽陽性は解消** — Phase 2cでRailsコンテキスト認識を導入
- **残る低スコアは妥当な指摘** — Godモデル・肥大化Concernが検出対象
- **CIゲート推奨閾値**: `--min-score 50` で4.4%のクラスが検出される
