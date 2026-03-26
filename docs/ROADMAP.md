# solid-score Roadmap

## Vision

AI生成コードの品質ゲートとして、CIで実用的なSOLID原則スコアリングツールを目指す。
人間にも理解しやすく、AIのtoken量削減にも寄与するコード品質の定量化。

## Phase 1: 偽陽性削減 ✅ (Completed)

- [x] DIP: 標準ライブラリホワイトリスト
- [x] LSP: 単純実装・抽象親パターンの除外
- [x] OCP: case/when分岐ペナルティ追加
- [x] Parser: MethodCallInfo によるレシーバ情報収集

## Phase 2a: Rails実用化 ✅ (Completed)

- [x] クラスメソッド (`def self.xxx`) の解析対応
- [x] モジュール (`module`) の解析対応
- [x] ネストしたクラス/モジュール対応
- [x] Rails DSL認識 (`has_many`, `belongs_to`, `validates` 等)
- [x] ActiveRecord継承クラスの適切な評価 (LSP: superなしペナルティ免除)
- [x] Concern (`include`/`extend`) の適切な評価 (ISP: ペナルティ緩和)

## Phase 2b: 検出精度向上 ✅ (Completed)

- [x] OCP: 型チェックパターン拡張 (`respond_to?` を弱い型チェックとして追加)
- [x] DIP: ファクトリメソッド検出 (`create`, `build`, `call`, `open`)
- [x] DIP: ユーザー定義ホワイトリスト（`.solid-score.yml` の `dip.whitelist` で設定可能）
- [x] Confidence: class_infoに基づく動的な信頼度計算

## Phase 2c: Railsコンテキスト認識 ✅ (Completed)

実プロジェクト検証で判明した偽陽性を解消。Railsアーキテクチャのコンテキストを自動認識。

- [x] ClassInfo: レイヤー自動判別 (file_path/superclassから controller/model/service/lib等)
- [x] ClassInfo: フレームワーク基盤クラス判定 (ActiveRecord::Base等)
- [x] ClassInfo: HTTPクライアントパターン検出
- [x] DIP: レイヤー別ペナルティ重み (Controller:0.4, Model:0.5, Service/Lib:1.0)
- [x] SRP: フレームワーク基盤クラスの最低スコア70点保証
- [x] SRP: 小規模クラス(メソッド≤3)のLCOM4を1に固定
- [x] SRP: APIクライアントパターンの最低スコア80点保証

### 改善効果 (実プロジェクト1,241クラス)
- 全体平均: 87.4 → 90.2 (+2.8)
- 50点未満: 96 → 55 (-43%)
- DIP=0: 163 → 50 (-69%)
- Controller層50点未満: 25 → 1 (-96%)

### 未対応（Phase 4へ移行）
- [ ] LSP: 複数ファイル間の継承関係解析
- [ ] SRP: TCC (Tight Class Cohesion) メトリクス追加
- [ ] SRP: WMC計算の精度向上（Flogスコア連携検討）

## Phase 3: エコシステム統合

既存CIパイプラインにシームレスに乗せる。

### タスク
- [ ] RuboCop Cop統合 (`rubocop-solid-score` gem)
- [ ] HTMLレポート出力
- [ ] GitHub Actions公式Action
- [ ] PR コメント自動投稿（スコア差分表示）
- [ ] `.solid-score.yml` のRailsプリセット

## Phase 4: 次世代解析

速度・精度・信頼性の根本的向上。

### タスク
- [ ] Prism パーサー移行 (Ruby 3.3+)
- [ ] Reek/Flog データ連携アダプター
- [ ] 複合スコアリング（外部ツール結果の統合）
- [ ] LSP: RBS/Sorbet型情報活用
- [ ] Git履歴ベースのChange Coupling分析

## Metrics

| 指標 | Phase 1 | Phase 2a目標 | Phase 3目標 |
|------|---------|-------------|-------------|
| Railsプロジェクト偽陽性率 | 未計測 | <20% | <10% |
| 解析対象カバー率 | クラスのみ | クラス+モジュール | 全Ruby構造 |
| CI統合容易性 | CLI | CLI+設定プリセット | RuboCop+Action |
