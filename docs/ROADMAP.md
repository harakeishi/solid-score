# solid-score Roadmap

## Vision

AI生成コードの品質ゲートとして、CIで実用的なSOLID原則スコアリングツールを目指す。
人間にも理解しやすく、AIのtoken量削減にも寄与するコード品質の定量化。

## Phase 1: 偽陽性削減 ✅ (Completed)

- [x] DIP: 標準ライブラリホワイトリスト
- [x] LSP: 単純実装・抽象親パターンの除外
- [x] OCP: case/when分岐ペナルティ追加
- [x] Parser: MethodCallInfo によるレシーバ情報収集

## Phase 2a: Rails実用化 🔨 (Current)

実プロジェクトで使えるレベルにする。

### 目標
- Railsプロジェクトでの偽陽性を大幅削減
- クラスメソッド・モジュールの解析対応

### タスク
- [ ] クラスメソッド (`def self.xxx`) の解析対応
- [ ] モジュール (`module`) の解析対応
- [ ] ActiveRecord継承クラスの適切な評価
  - LSP: ActiveRecord/ApplicationRecord継承時のsuper不要パターン
  - ISP: フレームワーク由来メソッドの除外
- [ ] Concern (`include`/`extend`) の適切な評価
  - ISP: フレームワークConcernのinclude数ペナルティ緩和
- [ ] Rails DSL認識 (`has_many`, `belongs_to`, `validates` 等)
- [ ] ネストしたクラス/モジュール対応

## Phase 2b: 検出精度向上

偽陽性・偽陰性の両面を改善。

### タスク
- [ ] OCP: 型チェックパターン拡張 (`respond_to?`, `obj.class ==`)
- [ ] DIP: ファクトリメソッド検出 (`create`, `build`, `call`)
- [ ] DIP: ユーザー定義ホワイトリスト（設定ファイルで指定可能に）
- [ ] LSP: 複数ファイル間の継承関係解析
- [ ] SRP: TCC (Tight Class Cohesion) メトリクス追加
- [ ] SRP: WMC計算の精度向上（Flogスコア連携検討）
- [ ] Confidence指標の改善（各原則の検出信頼度を精緻化）

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
