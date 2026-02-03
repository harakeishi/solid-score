# solid-score 改善提案書

## 目次

1. [概要](#概要)
2. [DIP Analyzer の問題点と改善案](#dip-analyzer-の問題点と改善案)
3. [LSP Analyzer の問題点と改善案](#lsp-analyzer-の問題点と改善案)
4. [OCP Analyzer の問題点と改善案](#ocp-analyzer-の問題点と改善案)
5. [SRP Analyzer の問題点と改善案](#srp-analyzer-の問題点と改善案)
6. [ISP Analyzer の問題点と改善案](#isp-analyzer-の問題点と改善案)
7. [Parser の問題点と改善案](#parser-の問題点と改善案)
8. [実装優先度と工数見積もり](#実装優先度と工数見積もり)

---

## 概要

本ドキュメントは、solid-score リポジトリの各 Analyzer について詳細な分析を行い、スコアリング精度向上のための具体的な改善提案をまとめたものです。

### 分析対象バージョン

- 分析日: 2026-02-03
- 対象ファイル:
  - `lib/solid_score/analyzers/dip_analyzer.rb`
  - `lib/solid_score/analyzers/lsp_analyzer.rb`
  - `lib/solid_score/analyzers/ocp_analyzer.rb`
  - `lib/solid_score/analyzers/srp_analyzer.rb`
  - `lib/solid_score/analyzers/isp_analyzer.rb`
  - `lib/solid_score/parser/ruby_parser.rb`

---

## DIP Analyzer の問題点と改善案

### 現状の実装

**ファイル**: `lib/solid_score/analyzers/dip_analyzer.rb:26-29`

```ruby
def count_concrete_instantiations(class_info)
  class_info.methods.sum do |method|
    method.called_methods.count { |m| m == :new }
  end
end
```

### 問題点 1: 標準ライブラリのインスタンス化が具象依存としてカウントされる

#### 問題の根拠

現在の実装では、`.new` の呼び出しをすべて具象依存としてカウントしています。これにより、以下のような正当な使用がペナルティを受けます:

```ruby
# 以下はすべて false positive になる
class DataProcessor
  def process(data)
    result = Array.new        # -ペナルティ
    hash = Hash.new(0)        # -ペナルティ
    set = Set.new             # -ペナルティ
    queue = Queue.new         # -ペナルティ
    mutex = Mutex.new         # -ペナルティ
    time = Time.new           # -ペナルティ
    date = Date.new(2024, 1, 1) # -ペナルティ
    regexp = Regexp.new("pattern") # -ペナルティ
    struct = Struct.new(:x, :y) # -ペナルティ
    # ...
  end
end
```

#### 改善案: ホワイトリストの導入

**期待効果**: false positive を大幅に削減し、より正確な DIP スコアリングを実現

```ruby
# 提案する実装
class DipAnalyzer < BaseAnalyzer
  # Ruby標準ライブラリおよびコアクラスのホワイトリスト
  STANDARD_LIBRARY_WHITELIST = %i[
    # 基本データ構造
    Array Hash Set SortedSet
    # スレッド・同期
    Thread Mutex Monitor ConditionVariable Queue SizedQueue
    # 時間・日付
    Time Date DateTime
    # 数値
    BigDecimal Rational Complex
    # 文字列・正規表現
    String StringIO Regexp
    # IO関連
    File Dir IO Tempfile
    # 構造体
    Struct OpenStruct
    # 例外
    StandardError RuntimeError ArgumentError TypeError
    # その他
    Range Enumerator Proc Method
  ].freeze

  # プロジェクト固有のホワイトリスト(設定可能)
  attr_reader :custom_whitelist

  def initialize(custom_whitelist: [])
    @custom_whitelist = custom_whitelist
  end

  private

  def count_concrete_instantiations(class_info)
    whitelist = STANDARD_LIBRARY_WHITELIST + custom_whitelist

    class_info.methods.sum do |method|
      method.called_methods.count do |m|
        next false unless m == :new

        # 呼び出し元のレシーバを取得して判定
        # ※これには Parser の改修が必要
        !whitelist.include?(receiver_class_name)
      end
    end
  end
end
```

#### トレードオフ

| 項目 | メリット | デメリット |
|------|----------|------------|
| 精度 | false positive 削減 | ホワイトリストの維持コスト |
| 設定性 | プロジェクト固有のカスタマイズ可能 | 設定の複雑化 |
| 実装 | 比較的単純な変更 | Parser の改修も必要 |

#### 代替案: レシーバベースの判定

```ruby
# 代替案: .new の呼び出し元クラス名を取得して判定
# Parser でレシーバ情報を収集する必要がある
def count_concrete_instantiations(class_info)
  class_info.methods.sum do |method|
    method.new_calls.count do |call|
      !standard_library_class?(call.receiver_class)
    end
  end
end
```

### 問題点 2: レシーバ情報の未収集

#### 問題の根拠

**ファイル**: `lib/solid_score/parser/ruby_parser.rb:149-150`

```ruby
when :send
  called_methods << node.children[1]  # メソッド名のみ収集
```

現在は `send` ノードからメソッド名のみを収集しており、レシーバ(呼び出し元)の情報が欠落しています。

#### 改善案: メソッド呼び出し情報の拡張

```ruby
# MethodInfo に新しいフィールドを追加
class MethodCallInfo
  attr_reader :method_name, :receiver, :receiver_type

  def initialize(method_name:, receiver: nil, receiver_type: :unknown)
    @method_name = method_name
    @receiver = receiver
    @receiver_type = receiver_type  # :const, :ivar, :lvar, :self, :unknown
  end
end

# Parser での収集
def collect_method_details(node, instance_vars, called_methods, raises, method_calls)
  # ...
  when :send
    receiver = node.children[0]
    method_name = node.children[1]

    method_calls << MethodCallInfo.new(
      method_name: method_name,
      receiver: extract_receiver_name(receiver),
      receiver_type: classify_receiver(receiver)
    )
  # ...
end
```

---

## LSP Analyzer の問題点と改善案

### 現状の実装

**ファイル**: `lib/solid_score/analyzers/lsp_analyzer.rb:34-38`

```ruby
def no_super_penalty(method)
  return 0 if method.calls_super

  NO_SUPER_PENALTY  # 10点減点
end
```

### 問題点 1: super 呼び出しがないだけで減点される

#### 問題の根拠

現在の実装では、親クラスを持つクラスのすべてのメソッド（initialize を除く）が、`super` を呼び出していない場合に 10 点減点されます。

これは以下のケースで誤検出（false positive）となります:

```ruby
# ケース1: Template Method パターン
class BaseProcessor
  def process(data)
    raise NotImplementedError
  end
end

class CsvProcessor < BaseProcessor
  def process(data)  # super を呼ぶ必要がない
    data.split(",")  # -10点 (false positive)
  end
end

# ケース2: 完全なオーバーライド（意図的な振る舞いの変更）
class Animal
  def speak
    "..."
  end
end

class Dog < Animal
  def speak  # 親の実装を呼ぶ必要がない
    "Woof!"  # -10点 (false positive)
  end
end

# ケース3: 子クラス固有のメソッド
class Parent
  def common_method
    # ...
  end
end

class Child < Parent
  def child_specific_method  # 親に存在しないメソッド
    "only in child"  # -10点 (false positive)
  end
end
```

#### 正当に super を呼ばないケースの分類

| パターン | 説明 | super 不要の理由 |
|----------|------|------------------|
| Template Method | 抽象メソッドの実装 | 親は NotImplementedError を raise するのみ |
| Complete Override | 完全なオーバーライド | 親の振る舞いを意図的に置き換え |
| Child-specific Method | 子クラス固有メソッド | 親に対応するメソッドが存在しない |
| Hook Method | フック/コールバック | 空実装またはデフォルト値を返すのみ |

#### 改善案 A: 親クラスのメソッド存在チェック

**期待効果**: false positive を大幅に削減

```ruby
def no_super_penalty(method, class_info)
  return 0 if method.calls_super

  # 親クラスに同名メソッドが存在するかチェック
  return 0 unless parent_has_method?(class_info.superclass, method.name)

  # 親メソッドが NotImplementedError を raise する場合は減点しない
  return 0 if parent_method_is_abstract?(class_info.superclass, method.name)

  NO_SUPER_PENALTY
end

private

def parent_has_method?(parent_class, method_name)
  # 実装: 親クラスのメソッド一覧を取得して存在確認
  # ※ランタイム情報が必要になる可能性あり
end
```

#### 改善案 B: ペナルティの条件緩和（静的解析のみ）

**期待効果**: 実装コストを抑えつつ精度改善

```ruby
def no_super_penalty(method, class_info)
  return 0 if method.calls_super

  # 以下の条件では減点しない
  # 1. メソッドが単純（cyclomatic_complexity == 1）かつ短い
  # 2. 親クラスが抽象的（NotImplementedError を持つ）
  # 3. 戻り値が親と異なる型を示唆する（ヒューリスティック）

  return 0 if simple_implementation?(method)
  return 0 if abstract_parent_pattern?(class_info)

  NO_SUPER_PENALTY / 2  # ペナルティを半減
end

def simple_implementation?(method)
  method.cyclomatic_complexity == 1 && (method.line_end - method.line_start) <= 3
end

def abstract_parent_pattern?(class_info)
  # 同一ファイル内の親クラスが NotImplementedError パターンを持つ場合
  # ※制限あり: 同一ファイル内の解析のみ
end
```

#### 改善案 C: 設定によるペナルティの無効化

```ruby
# Configuration で制御
module SolidScore
  class Configuration
    attr_accessor :lsp_super_penalty_enabled

    def initialize
      @lsp_super_penalty_enabled = false  # デフォルトで無効化
    end
  end
end

def no_super_penalty(method)
  return 0 unless SolidScore.configuration.lsp_super_penalty_enabled
  return 0 if method.calls_super

  NO_SUPER_PENALTY
end
```

#### トレードオフ比較

| 改善案 | 精度向上 | 実装コスト | 副作用 |
|--------|----------|------------|--------|
| A: 親メソッド存在チェック | 高 | 高（ランタイム情報必要） | パフォーマンス低下 |
| B: 条件緩和 | 中 | 低 | 一部 false negative |
| C: 設定無効化 | - | 最低 | 機能の放棄 |

**推奨**: 改善案 B を Phase 1 で実装し、Phase 2 で A に移行

---

## OCP Analyzer の問題点と改善案

### 現状の実装

**ファイル**: `lib/solid_score/analyzers/ocp_analyzer.rb`

```ruby
TYPE_CHECK_METHODS = %i[is_a? kind_of? instance_of?].freeze

def conditional_density_penalty(class_info)
  # 条件分岐密度のみで評価
end

def type_check_penalty(class_info)
  # is_a?, kind_of?, instance_of? のみ検出
end
```

### 問題点 1: 条件分岐密度のみでの評価の限界

#### 問題の根拠

**ファイル**: `lib/solid_score/analyzers/ocp_analyzer.rb:24-37`

条件分岐の数だけでは、以下の違いを区別できません:

```ruby
# ケース1: 正当な条件分岐（OCP違反ではない）
class Validator
  def validate(value)
    return false if value.nil?
    return false if value.empty?
    return false if value.length > 100

    true
  end
end

# ケース2: OCP違反の条件分岐（型に基づく分岐）
class ShapeCalculator
  def area(shape)
    case shape.type
    when :circle then circle_area(shape)
    when :rectangle then rectangle_area(shape)
    when :triangle then triangle_area(shape)  # 新しい図形追加時に修正必要
    end
  end
end
```

両者とも同じ分岐数であっても、OCP の観点では全く異なる品質です。

#### 改善案: ポリモーフィズム検出の追加

**期待効果**: OCP 準拠のコードに適切なボーナスを付与

```ruby
def analyze(class_info)
  return 100 if class_info.methods.empty?

  score = 100.0

  score -= conditional_density_penalty(class_info)
  score -= type_check_penalty(class_info)
  score -= case_when_penalty(class_info)          # 新規追加
  score += extension_point_bonus(class_info)
  score += polymorphism_bonus(class_info)         # 新規追加
  score += strategy_pattern_bonus(class_info)     # 新規追加

  clamp_score(score)
end

private

# case/when での型・シンボル分岐を検出
def case_when_penalty(class_info)
  case_when_count = class_info.methods.sum do |method|
    count_case_when_branches(method)
  end

  [case_when_count * 5, 30].min
end

# ポリモーフィズム（サブクラスでのオーバーライド）を検出
def polymorphism_bonus(class_info)
  return 0 unless class_info.has_superclass?

  overridden_methods = class_info.methods.count do |method|
    # 親クラスの抽象メソッドをオーバーライドしている
    method.name != :initialize && !method.calls_super
  end

  [overridden_methods * 5, 15].min
end

# Strategy パターン（インジェクションされた依存の利用）を検出
def strategy_pattern_bonus(class_info)
  init = class_info.methods.find { |m| m.name == :initialize }
  return 0 unless init

  injected_deps = init.parameters.count { |type, _| %i[key keyreq].include?(type) }
  other_methods_use_deps = class_info.methods.any? do |m|
    m.name != :initialize && m.instance_variables.any?
  end

  (injected_deps > 0 && other_methods_use_deps) ? 10 : 0
end
```

### 問題点 2: 型チェックの検出漏れ

#### 問題の根拠

**ファイル**: `lib/solid_score/analyzers/ocp_analyzer.rb:6`

```ruby
TYPE_CHECK_METHODS = %i[is_a? kind_of? instance_of?].freeze
```

以下の型チェックパターンが検出されません:

```ruby
# 検出されない型チェックパターン
class Handler
  def handle(obj)
    case obj.class.name        # パターン1: class.name
    when "User" then handle_user(obj)
    when "Admin" then handle_admin(obj)
    end

    if obj.class == User       # パターン2: class ==
      handle_user(obj)
    end

    case obj                   # パターン3: case obj ... when Class
    when User then handle_user(obj)
    when Admin then handle_admin(obj)
    end

    if obj.respond_to?(:admin?) && obj.admin?  # パターン4: respond_to? による分岐
      handle_admin(obj)
    end

    obj.type == :user          # パターン5: type/kind 属性による分岐
  end
end
```

#### 改善案: 型チェックパターンの拡張

```ruby
# 検出対象のメソッド/パターンを拡張
TYPE_CHECK_METHODS = %i[
  is_a? kind_of? instance_of?
  class
].freeze

# 追加の検出ロジック
def type_check_penalty(class_info)
  direct_checks = count_direct_type_checks(class_info)
  class_comparison = count_class_comparisons(class_info)
  type_attribute_checks = count_type_attribute_checks(class_info)

  total = direct_checks + class_comparison + type_attribute_checks
  [total * 10, MAX_TYPE_CHECK_PENALTY].min
end

def count_class_comparisons(class_info)
  # .class == SomeClass パターンの検出
  # Parser の改修が必要
end

def count_type_attribute_checks(class_info)
  # .type, .kind 属性へのアクセスとその後の比較を検出
  # ヒューリスティック: type/kind メソッド呼び出し後の == 比較
end
```

#### トレードオフ

| 検出パターン | 実装難易度 | false positive リスク |
|--------------|------------|----------------------|
| is_a?/kind_of? | 低（現状） | 低 |
| .class == | 中 | 低 |
| case obj when Class | 高（AST 解析必要） | 低 |
| respond_to? | 中 | 高（正当な使用も多い） |
| .type/.kind 属性 | 中 | 中（命名規則依存） |

---

## SRP Analyzer の問題点と改善案

### 現状の実装

**ファイル**: `lib/solid_score/analyzers/srp_analyzer.rb`

LCOM4（Lack of Cohesion of Methods 4）をベースにした凝集度分析を実装しています。

### 問題点 1: クラスメソッドの未対応

#### 問題の根拠

**ファイル**: `lib/solid_score/parser/ruby_parser.rb:70-71`

```ruby
when :def
  methods << build_method_info(node, current_visibility)
```

`def self.method_name` や `class << self` 内のメソッドが収集されていません。

```ruby
# 以下のクラスメソッドは解析対象外
class Service
  def self.create(params)    # 未検出
    new(params).call
  end

  class << self
    def configure(options)   # 未検出
      @config = options
    end
  end

  def call
    # インスタンスメソッドのみ解析される
  end
end
```

#### 改善案: クラスメソッドの収集

```ruby
def traverse_body(node, methods, includes, extends, attr_readers, attr_writers, current_visibility)
  return unless node.is_a?(::AST::Node)

  case node.type
  when :begin
    # ...
  when :def
    methods << build_method_info(node, current_visibility, :instance)
  when :defs  # 追加: self.method_name パターン
    methods << build_method_info(node, current_visibility, :class)
  when :sclass  # 追加: class << self パターン
    traverse_singleton_class(node, methods, current_visibility)
  when :send
    # ...
  end

  current_visibility
end

def traverse_singleton_class(node, methods, current_visibility)
  body = node.children[1]
  return unless body

  # class << self 内のメソッドを収集
  traverse_body(body, methods, [], [], [], [], current_visibility)
end
```

### 問題点 2: モジュールの解析未対応

#### 問題の根拠

**ファイル**: `lib/solid_score/parser/ruby_parser.rb:21-22`

```ruby
if node.type == :class
  classes << build_class_info(node, file_path)
```

`module` ノードが無視されています。

```ruby
# 以下のモジュールは解析対象外
module Concerns
  module Authenticatable
    def authenticate(credentials)
      # ...
    end

    def logout
      # ...
    end
  end
end
```

#### 改善案: モジュール対応

```ruby
def extract_classes(node, file_path, classes = [])
  return classes unless node.is_a?(::AST::Node)

  case node.type
  when :class
    classes << build_class_info(node, file_path, :class)
  when :module
    classes << build_class_info(node, file_path, :module)  # 追加
  else
    node.children.each { |child| extract_classes(child, file_path, classes) }
  end

  classes
end
```

---

## ISP Analyzer の問題点と改善案

### 現状の実装

**ファイル**: `lib/solid_score/analyzers/isp_analyzer.rb`

パブリックメソッド数と include の数でスコアリングしています。

### 問題点 1: メソッドのグルーピングが考慮されていない

#### 問題の根拠

同じ数のパブリックメソッドでも、それらが論理的にグループ化されているかどうかで ISP 準拠度は異なります。

```ruby
# ケース1: 関連するメソッドが1つのインターフェース（良い）
class UserRepository
  def find(id); end
  def find_all; end
  def save(user); end
  def delete(user); end
  def count; end
end

# ケース2: 無関係なメソッドが混在（悪い）
class GodClass
  def send_email; end
  def calculate_tax; end
  def render_html; end
  def query_database; end
  def compress_file; end
end
```

両者ともパブリックメソッド数は 5 で同じスコアになります。

#### 改善案: メソッド凝集度の考慮

```ruby
def analyze(class_info)
  public_methods = class_info.public_methods_list
  return 100 if public_methods.empty?

  score = public_method_score(public_methods.size)
  score -= include_penalty(class_info)
  score -= cohesion_penalty(class_info)
  score -= method_naming_diversity_penalty(class_info)  # 追加
  score += interface_segregation_bonus(class_info)      # 追加

  clamp_score(score)
end

# メソッド名のプレフィックス多様性でペナルティ
def method_naming_diversity_penalty(class_info)
  public_methods = class_info.public_methods_list
  return 0 if public_methods.size <= 3

  prefixes = public_methods.map { |m| extract_method_prefix(m.name) }.uniq
  diversity_ratio = prefixes.size.to_f / public_methods.size

  diversity_ratio > 0.7 ? 15 : 0  # 高い多様性はペナルティ
end

def extract_method_prefix(name)
  # find_user -> find
  # calculate_tax -> calculate
  name.to_s.split("_").first
end

# 適切にインターフェースが分離されている場合のボーナス
def interface_segregation_bonus(class_info)
  # include されている Concern/Module が適切に分離されている場合
  # 各 include のメソッド数が少ない場合にボーナス
  0  # TODO: 実装
end
```

---

## Parser の問題点と改善案

### 現状の実装

**ファイル**: `lib/solid_score/parser/ruby_parser.rb`

### 問題点一覧

| 問題 | ファイル:行 | 影響 |
|------|-------------|------|
| クラスメソッド未対応 | :70-71 | SRP, DIP |
| モジュール未対応 | :21-22 | 全 Analyzer |
| レシーバ情報未収集 | :149-150 | DIP |
| ネストしたクラス未対応 | :21-28 | 全 Analyzer |
| ブロック内定義未対応 | - | SRP |

### 包括的な改善案

```ruby
class RubyParser
  # 収集対象の拡張
  def extract_definitions(node, file_path, definitions = [])
    return definitions unless node.is_a?(::AST::Node)

    case node.type
    when :class
      definitions << build_class_info(node, file_path, :class)
    when :module
      definitions << build_module_info(node, file_path)
    when :sclass
      # class << self の処理
    end

    # ネストした定義も再帰的に収集
    node.children.each { |child| extract_definitions(child, file_path, definitions) }

    definitions
  end

  # メソッド呼び出しの詳細情報収集
  def collect_method_details(node, context)
    # ...
    when :send
      receiver = node.children[0]
      method_name = node.children[1]

      context.method_calls << MethodCallInfo.new(
        method_name: method_name,
        receiver: extract_receiver(receiver),
        receiver_type: classify_receiver_type(receiver),
        arguments: extract_arguments(node)
      )
    # ...
  end
end
```

---

## 実装優先度と工数見積もり

### Phase 1: 高優先度（false positive の大幅削減）

| 改善項目 | 対象 Analyzer | 工数 | 依存関係 |
|----------|---------------|------|----------|
| 標準ライブラリホワイトリスト | DIP | 2-3 日 | Parser 改修（レシーバ情報） |
| super ペナルティ条件緩和 | LSP | 1-2 日 | なし |
| case/when ペナルティ追加 | OCP | 1-2 日 | なし |

**合計工数**: 4-7 日

### Phase 2: 中優先度（精度向上）

| 改善項目 | 対象 Analyzer | 工数 | 依存関係 |
|----------|---------------|------|----------|
| レシーバ情報収集 | Parser | 3-4 日 | なし |
| クラスメソッド対応 | Parser | 2-3 日 | なし |
| モジュール対応 | Parser | 2-3 日 | なし |
| 型チェックパターン拡張 | OCP | 2-3 日 | Parser 改修 |
| ポリモーフィズム検出 | OCP | 2-3 日 | なし |

**合計工数**: 11-16 日

### Phase 3: 低優先度（高度な分析）

| 改善項目 | 対象 Analyzer | 工数 | 依存関係 |
|----------|---------------|------|----------|
| 親クラスメソッド存在チェック | LSP | 5-7 日 | ランタイム情報 or 複数ファイル解析 |
| Strategy パターン検出 | OCP | 3-4 日 | DIP との連携 |
| メソッド名多様性ペナルティ | ISP | 2-3 日 | なし |
| ネストしたクラス対応 | Parser | 2-3 日 | なし |

**合計工数**: 12-17 日

### 実装順序の推奨

```
Phase 1 (必須)
├── 1.1 LSP: super ペナルティ条件緩和 (依存なし)
├── 1.2 OCP: case/when ペナルティ追加 (依存なし)
└── 1.3 DIP: 標準ライブラリホワイトリスト
    └── (前提) Parser: レシーバ情報収集の基本実装

Phase 2 (推奨)
├── 2.1 Parser: クラスメソッド対応
├── 2.2 Parser: モジュール対応
├── 2.3 Parser: レシーバ情報収集の完全実装
├── 2.4 OCP: 型チェックパターン拡張 (2.3 に依存)
└── 2.5 OCP: ポリモーフィズム検出

Phase 3 (オプション)
├── 3.1 LSP: 親クラスメソッド存在チェック
├── 3.2 OCP: Strategy パターン検出
├── 3.3 ISP: メソッド名多様性ペナルティ
└── 3.4 Parser: ネストしたクラス対応
```

---

## まとめ

### 優先的に取り組むべき問題

1. **DIP Analyzer**: 標準ライブラリの false positive が最も影響大
2. **LSP Analyzer**: super 必須条件は Template Method パターンを誤検出
3. **OCP Analyzer**: 条件分岐密度だけでは OCP 違反を正確に検出できない

### 技術的負債

- Parser がクラスメソッド・モジュールに未対応
- メソッド呼び出しのレシーバ情報が欠落
- 複数ファイルにまたがる解析ができない

### 期待される効果

Phase 1 完了後:
- false positive: 推定 40-50% 削減
- より実用的なスコアリング

Phase 2 完了後:
- false positive: 推定 70-80% 削減
- モジュール・クラスメソッドを含む包括的な解析

Phase 3 完了後:
- 高度なパターン検出による精度向上
- エンタープライズレベルのコード品質評価ツールとしての完成度
