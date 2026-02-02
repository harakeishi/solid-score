# solid-score 設計書

## 概要

**solid-score** は Ruby コードを AST 解析し、クラス/モジュール単位で SOLID 原則のスコア（0-100）を算出する CLI ツール（Gem）。CI/CD パイプラインおよびローカル開発の両方で使用可能。

## 要件

- Ruby 全般（Gem、純 Ruby、Rails アプリ）を解析対象
- クラス/モジュール単位でスコアを算出
- ターミナル表示（デフォルト）と JSON 出力をサポート
- CI 用に exit code で pass/fail を判定
- PR 差分のみを解析する差分モード
- `.solid-score.yml` による設定カスタマイズ

## アーキテクチャ

```
solid-score [path] [options]
├── Parser (AST解析: parser gem)
├── Extractors (クラス/モジュール情報抽出)
├── Analyzers (SOLID各原則の分析)
│   ├── SRP Analyzer  - LCOM4 + 補助メトリクス
│   ├── OCP Analyzer  - 条件分岐密度 + 型チェック検出
│   ├── LSP Analyzer  - 継承契約の遵守度
│   ├── ISP Analyzer  - インタフェース肥大度
│   └── DIP Analyzer  - 具象依存率
├── Scorer (重み付きスコア算出)
├── DiffAnalyzer (差分解析)
└── Formatters (出力)
    ├── TextFormatter  (ターミナル)
    └── JsonFormatter  (JSON)
```

### コアフロー

1. 対象パス内の `.rb` ファイルを収集（差分モード時は git diff で絞り込み）
2. 各ファイルを `parser` gem で AST にパース
3. AST からクラス/モジュール定義を抽出し `ClassInfo` に変換
4. 各 Analyzer がメトリクスを算出しスコア化
5. Scorer が重み付き総合スコアを算出
6. Formatter で出力
7. 閾値チェックで exit code を決定

## SOLID スコア算出ロジック

### S - 単一責任原則 (SRP)

**主メトリクス: LCOM4 (Lack of Cohesion of Methods 4)**

学術的に最も確立された SRP 計測手法。SonarQube でも採用。

**LCOM4 算出アルゴリズム:**
1. クラス内のメソッドをノードとするグラフを構築
2. 同じインスタンス変数を参照するメソッド同士にエッジを引く
3. 互いに呼び出すメソッド同士にもエッジを引く
4. 連結成分（connected components）の数 = LCOM4

**除外ルール:**
- `initialize` メソッド（コンストラクタは全変数を初期化するため LCOM4 を歪める）
- 継承メソッド（クラス固有でないため）
- 空メソッド（false positive の原因）

**補助メトリクス:**
- WMC (Weighted Methods per Class): メソッドの Cyclomatic Complexity の合計
- クラス行数

**スコア変換:**
| LCOM4 | ベーススコア |
|-------|-------------|
| 1     | 100         |
| 2     | 60          |
| 3     | 30          |
| >= 4  | 0           |

補助メトリクスによる調整:
- WMC > 20: -10点
- WMC > 40: -20点
- クラス行数 > 200: -10点
- クラス行数 > 400: -20点
- データクラス検出（attr_reader/attr_accessor のみ）: LCOM4 ペナルティを軽減

**測定信頼度: High**

**根拠:**
- Chidamber & Kemerer (1993) が提案した CK メトリクスの一部
- Hitz & Montazeri が LCOM4 として改良
- SonarQube, NDepend 等の商用ツールでも採用
- [LCOM4 Documentation](https://objectscriptquality.com/docs/metrics/lack-cohesion-methods-lcom4)

**既知の限界:**
- データクラスで誤検出する可能性（対策: データクラス検出ロジック）
- フレームワーク依存クラスで false positive（対策: 将来的に除外リスト）

---

### O - 開放閉鎖原則 (OCP)

**メトリクス: 条件分岐密度 + 型チェック検出 + 拡張ポイント**

OCP は静的解析で最も計測が難しい原則。兆候ベースの推定。

**算出方法:**

1. **条件分岐密度** = `(case/when数 + if/elsif チェーン長3以上の数) / メソッド数`
2. **型チェック使用**: `is_a?`, `kind_of?`, `instance_of?`, `class ==` の使用回数
3. **拡張ポイント**: `raise NotImplementedError`（テンプレートメソッド）、ブロック/Proc 引数の存在

**スコア変換:**
- ベーススコア: 100
- 条件分岐密度 > 0.5: -20点
- 条件分岐密度 > 1.0: -40点
- 型チェック1つにつき: -10点（最大 -40点）
- 拡張ポイント1つにつき: +10点（最大 +20点）
- 最終スコアは 0-100 にクランプ

**測定信頼度: Low**

**根拠:**
- NDepend の "Base class should not use derivatives" ルール
- 型チェック（downcast）は OCP 違反の典型的な兆候
- [NDepend: SOLID Code](https://blog.ndepend.com/solid-code/)

**既知の限界:**
- 正当な条件分岐も検出してしまう
- ストラテジーパターンの使用を検出できない

---

### L - リスコフ置換原則 (LSP)

**メトリクス: 継承契約の遵守度**

**算出方法:**

1. **シグネチャ互換性**: オーバーライドメソッドの引数数が親と異なる → -20点/件
2. **事前条件の強化**: 親にない `raise`/`fail` の追加 → -15点/件
3. **super 呼び出し**: オーバーライドで `super` を完全に無視 → -10点/件
4. **継承がないクラス**: デフォルト100点（LSP は継承に関する原則）

**スコア変換:**
- ベーススコア: 100
- 各違反で減点（最低 0 点）

**測定信頼度: Low-Medium**

**根拠:**
- LSP の定量化は「派生クラスが親のテストをすべてパスするか」が理想だが、静的解析では不可能
- シグネチャ変更と事前条件の強化は LSP 違反の客観的な兆候
- [Software Metrics for SOLID Conformity](https://www.researchgate.net/publication/333228560_Software_Metrics_Proposal_for_Conformity_Checking_of_Class_Diagram_to_SOLID_Design_Principles)

**既知の限界:**
- 継承がないクラスでは無評価（デフォルト100点）
- Ruby の動的型付けにより、戻り値型の変化を検出困難

---

### I - インタフェース分離原則 (ISP)

**メトリクス: パブリックインタフェースの肥大度**

**算出方法:**

1. **パブリックメソッド数**:
   | メソッド数 | スコア |
   |-----------|--------|
   | 1-5       | 100    |
   | 6-10      | 80     |
   | 11-15     | 60     |
   | 16-20     | 40     |
   | 21+       | 20     |

2. **include/extend の数**:
   - 3以下: 0点減点
   - 4-6: -10点
   - 7+: -20点

3. **パブリックメソッド間の凝集度**:
   - パブリックメソッドのみで LCOM4 を計算
   - LCOM4 > 2 の場合、インタフェースが分離可能 → -15点

**測定信頼度: Medium-High**

**根拠:**
- パブリックメソッド数はクラスのインタフェースの広さを直接表す
- Ruby の module include は明示的なインタフェース追加
- [NDepend: SOLID Code](https://blog.ndepend.com/solid-code/)

---

### D - 依存性逆転原則 (DIP)

**メトリクス: Robert Martin の Abstractness/Instability 応用**

**算出方法:**

1. **具象依存率** = `SomeClass.new の呼び出し数 / (SomeClass.new + inject された依存数)`
   - 0 → 100点（全て注入）
   - 0.5 → 50点
   - 1.0 → 0点（全てハードコード）

2. **DI 使用度**: `initialize` でオブジェクトを引数として受け取っているか
   - DI パターン使用: +15点ボーナス

3. **Efferent Coupling (Ce)**: 外部クラスへの依存数
   - Ce > 10: -10点
   - Ce > 20: -20点

**スコア変換:**
- `100 - (具象依存率 × 100) + DI ボーナス - Ce ペナルティ`
- 0-100 にクランプ

**測定信頼度: High**

**根拠:**
- Robert Martin の Ce/Ca メトリクスは理論的基盤が強い
- `SomeClass.new` のパターンは AST で確実に検出可能
- [Robert Martin's Package Metrics](https://kariera.future-processing.pl/blog/object-oriented-metrics-by-robert-martin/)

---

## 総合スコア

```
総合スコア = (SRP × 0.30) + (OCP × 0.15) + (LSP × 0.10) + (ISP × 0.20) + (DIP × 0.25)
```

| 原則 | 重み | 理由 |
|------|------|------|
| SRP  | 0.30 | LCOM4 は最も検証済みのメトリクス |
| OCP  | 0.15 | 静的解析での精度が低いため |
| LSP  | 0.10 | 継承がないクラスでは計測不能 |
| ISP  | 0.20 | パブリックメソッド数は客観的に計測可能 |
| DIP  | 0.25 | 依存関係は確実に検出可能 |

重み付けは `.solid-score.yml` でカスタマイズ可能。

## 差分解析モード

### フロー

1. `git diff --name-only <base>` で変更された `.rb` ファイルを取得
2. `git diff <base>` で各ファイルの変更行範囲を取得
3. 変更行にかかるクラス/モジュールを特定
4. 対象クラスのみ SOLID スコアを算出
5. ベースブランチのスコアとの比較（改善/悪化を表示）

### CLI オプション

```bash
$ solid-score --diff origin/main        # 指定ブランチとの差分
$ solid-score --diff HEAD~1             # 直前コミットとの差分
$ solid-score --diff-base auto          # CI で自動検出
```

### CI 判定基準

- `--min-score`: 差分クラスの総合スコアが閾値未満なら fail
- `--max-decrease`: 1クラスあたりのスコア低下が閾値を超えたら fail
- `--new-class-min`: 新規クラスの最低スコア

## CLI インターフェース

```bash
solid-score [path] [options]

Options:
  --format FORMAT       出力形式 (text|json) [default: text]
  --config FILE         設定ファイルのパス [default: .solid-score.yml]
  --min-score SCORE     最低総合スコア (CI用)
  --min-srp SCORE       SRP 最低スコア
  --min-ocp SCORE       OCP 最低スコア
  --min-lsp SCORE       LSP 最低スコア
  --min-isp SCORE       ISP 最低スコア
  --min-dip SCORE       DIP 最低スコア
  --diff REF            差分解析のベース参照
  --diff-base auto      CI で自動的にベースブランチを検出
  --max-decrease SCORE  許容するスコア低下の最大値
  --exclude PATTERN     除外パターン (カンマ区切り)
  --version             バージョン表示
  --help                ヘルプ表示
```

## 設定ファイル (.solid-score.yml)

```yaml
paths:
  - app/
  - lib/
exclude:
  - "spec/**/*"
  - "vendor/**/*"
  - "db/**/*"

thresholds:
  total: 60
  srp: 50
  ocp: 40
  lsp: 40
  isp: 50
  dip: 50

weights:
  srp: 0.30
  ocp: 0.15
  lsp: 0.10
  isp: 0.20
  dip: 0.25

diff:
  max_decrease: 10
  new_class_min: 60

format: text
```

## プロジェクト構成

```
solid-score/
├── lib/
│   ├── solid_score.rb
│   └── solid_score/
│       ├── version.rb
│       ├── cli.rb
│       ├── configuration.rb
│       ├── runner.rb
│       ├── parser/
│       │   └── ruby_parser.rb
│       ├── models/
│       │   ├── class_info.rb
│       │   ├── method_info.rb
│       │   └── score_result.rb
│       ├── analyzers/
│       │   ├── base_analyzer.rb
│       │   ├── srp_analyzer.rb
│       │   ├── ocp_analyzer.rb
│       │   ├── lsp_analyzer.rb
│       │   ├── isp_analyzer.rb
│       │   └── dip_analyzer.rb
│       ├── scorer.rb
│       ├── diff_analyzer.rb
│       └── formatters/
│           ├── base_formatter.rb
│           ├── text_formatter.rb
│           └── json_formatter.rb
├── spec/
│   ├── spec_helper.rb
│   ├── solid_score/
│   │   ├── analyzers/
│   │   │   ├── srp_analyzer_spec.rb
│   │   │   ├── ocp_analyzer_spec.rb
│   │   │   ├── lsp_analyzer_spec.rb
│   │   │   ├── isp_analyzer_spec.rb
│   │   │   └── dip_analyzer_spec.rb
│   │   ├── parser/
│   │   │   └── ruby_parser_spec.rb
│   │   ├── scorer_spec.rb
│   │   ├── diff_analyzer_spec.rb
│   │   └── cli_spec.rb
│   └── fixtures/
│       ├── good_srp.rb
│       ├── bad_srp.rb
│       ├── good_ocp.rb
│       ├── bad_ocp.rb
│       └── ...
├── Gemfile
├── solid_score.gemspec
├── Rakefile
├── .rubocop.yml
├── .solid-score.yml
├── LICENSE
└── README.md
```

## 依存 Gem

```ruby
# Runtime
spec.add_dependency "parser", "~> 3.3"
spec.add_dependency "ast", "~> 2.4"

# Development
spec.add_development_dependency "rspec", "~> 3.12"
spec.add_development_dependency "rubocop", "~> 1.60"
spec.add_development_dependency "simplecov", "~> 0.22"
```

CLI は標準ライブラリの `OptionParser` を使用し、依存を最小限に保つ。

## 参考文献

- [LCOM4 Metric Documentation](https://objectscriptquality.com/docs/metrics/lack-cohesion-methods-lcom4)
- [NDepend: Measure How SOLID Your Code Is](https://blog.ndepend.com/solid-code/)
- [Robert Martin's Object-Oriented Metrics](https://kariera.future-processing.pl/blog/object-oriented-metrics-by-robert-martin/)
- [Software Metrics for SOLID Conformity (ResearchGate)](https://www.researchgate.net/publication/333228560_Software_Metrics_Proposal_for_Conformity_Checking_of_Class_Diagram_to_SOLID_Design_Principles)
- [LCOM and SRP (Medium)](https://medium.com/@suraif16/lack-of-cohesion-in-methods-265a9a26fd66)
- [NDepend: Lack of Cohesion of Methods](https://blog.ndepend.com/lack-of-cohesion-methods/)
- [Metrics to Quantify SOLID (JETIR)](https://www.jetir.org/view?paper=JETIR1806241)
- [Software Package Metrics (Wikipedia)](https://en.wikipedia.org/wiki/Software_package_metrics)
