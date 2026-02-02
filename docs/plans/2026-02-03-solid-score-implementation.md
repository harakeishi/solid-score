# solid-score Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ruby コードを AST 解析し、クラス/モジュール単位で SOLID 原則スコア（0-100）を算出する CLI Gem を構築する。

**Architecture:** `parser` gem で Ruby ソースを AST にパースし、ClassInfo モデルに変換。5つの Analyzer（SRP/OCP/LSP/ISP/DIP）が各原則のスコアを算出。Scorer が重み付き総合スコアを計算し、Formatter で出力。差分解析モードでは git diff を利用して変更クラスのみを対象とする。

**Tech Stack:** Ruby 3.2+, parser gem (AST), ast gem, RSpec, RuboCop, OptionParser (CLI)

**Design doc:** `docs/plans/2026-02-03-solid-score-design.md`

---

## Task 1: プロジェクト基盤セットアップ

**Files:**
- Create: `solid_score.gemspec`
- Create: `Gemfile`
- Create: `Rakefile`
- Create: `lib/solid_score.rb`
- Create: `lib/solid_score/version.rb`
- Create: `spec/spec_helper.rb`
- Create: `.rubocop.yml`
- Create: `exe/solid-score`

**Step 1: gemspec を作成**

```ruby
# solid_score.gemspec
# frozen_string_literal: true

require_relative "lib/solid_score/version"

Gem::Specification.new do |spec|
  spec.name = "solid_score"
  spec.version = SolidScore::VERSION
  spec.authors = ["harachan"]
  spec.email = ["44335168+harakeishi@users.noreply.github.com"]

  spec.summary = "SOLID principles scoring tool for Ruby code"
  spec.description = "Static analysis tool that scores Ruby classes/modules against SOLID principles using AST analysis"
  spec.homepage = "https://github.com/harakeishi/solid-score"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["solid-score"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ast", "~> 2.4"
  spec.add_dependency "parser", "~> 3.3"
end
```

**Step 2: version, エントリポイント, Gemfile, Rakefile を作成**

```ruby
# lib/solid_score/version.rb
# frozen_string_literal: true

module SolidScore
  VERSION = "0.1.0"
end
```

```ruby
# lib/solid_score.rb
# frozen_string_literal: true

require_relative "solid_score/version"

module SolidScore
end
```

```ruby
# Gemfile
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rspec", "~> 3.12"
  gem "rubocop", "~> 1.60"
  gem "simplecov", "~> 0.22"
end
```

```ruby
# Rakefile
# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec
```

**Step 3: spec_helper を作成**

```ruby
# spec/spec_helper.rb
# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "solid_score"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end
```

**Step 4: .rubocop.yml を作成**

```yaml
# .rubocop.yml
AllCops:
  TargetRubyVersion: 3.2
  NewCops: enable
  Exclude:
    - "vendor/**/*"
    - "spec/fixtures/**/*"

Layout/LineLength:
  Max: 120

Metrics/MethodLength:
  Max: 15
  Exclude:
    - "spec/**/*"

Metrics/ClassLength:
  Max: 200

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
    - "solid_score.gemspec"

Style/Documentation:
  Enabled: false

Style/FrozenStringLiteralComment:
  Enabled: true

Style/StringLiterals:
  EnforcedStyle: double_quotes
```

**Step 5: 実行ファイルを作成**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "solid_score"

SolidScore::CLI.new.run(ARGV)
```

**Step 6: bundle install を実行**

Run: `bundle install`
Expected: 依存関係がインストールされる

**Step 7: rspec の初期実行を確認**

Run: `bundle exec rspec`
Expected: `0 examples, 0 failures`

**Step 8: コミット**

```bash
git add solid_score.gemspec Gemfile Gemfile.lock Rakefile lib/ spec/spec_helper.rb .rubocop.yml exe/
git commit -m "ai/chore: プロジェクト基盤セットアップ (gemspec, RSpec, RuboCop)"
```

---

## Task 2: Models - ClassInfo, MethodInfo, ScoreResult

**Files:**
- Create: `lib/solid_score/models/class_info.rb`
- Create: `lib/solid_score/models/method_info.rb`
- Create: `lib/solid_score/models/score_result.rb`
- Create: `spec/solid_score/models/class_info_spec.rb`
- Create: `spec/solid_score/models/method_info_spec.rb`
- Create: `spec/solid_score/models/score_result_spec.rb`

**Step 1: MethodInfo のテストを書く**

```ruby
# spec/solid_score/models/method_info_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Models::MethodInfo do
  describe "#initialize" do
    it "stores method attributes" do
      method_info = described_class.new(
        name: :calculate,
        visibility: :public,
        line_start: 10,
        line_end: 20,
        instance_variables: %i[@total @tax],
        called_methods: [:validate],
        parameters: [[:req, :amount]],
        cyclomatic_complexity: 3,
        raises: [],
        calls_super: false
      )

      expect(method_info.name).to eq(:calculate)
      expect(method_info.visibility).to eq(:public)
      expect(method_info.instance_variables).to eq(%i[@total @tax])
      expect(method_info.called_methods).to eq([:validate])
      expect(method_info.cyclomatic_complexity).to eq(3)
    end
  end

  describe "#public?" do
    it "returns true for public methods" do
      method_info = described_class.new(name: :foo, visibility: :public)
      expect(method_info.public?).to be true
    end

    it "returns false for private methods" do
      method_info = described_class.new(name: :foo, visibility: :private)
      expect(method_info.public?).to be false
    end
  end

  describe "#empty?" do
    it "returns true when line_start equals line_end" do
      method_info = described_class.new(name: :foo, line_start: 5, line_end: 5)
      expect(method_info.empty?).to be true
    end
  end
end
```

**Step 2: テストが失敗することを確認**

Run: `bundle exec rspec spec/solid_score/models/method_info_spec.rb`
Expected: FAIL - `uninitialized constant SolidScore::Models::MethodInfo`

**Step 3: MethodInfo を実装**

```ruby
# lib/solid_score/models/method_info.rb
# frozen_string_literal: true

module SolidScore
  module Models
    class MethodInfo
      attr_reader :name, :visibility, :line_start, :line_end,
                  :instance_variables, :called_methods, :parameters,
                  :cyclomatic_complexity, :raises, :calls_super

      def initialize(name:, visibility: :public, line_start: 0, line_end: 0,
                     instance_variables: [], called_methods: [], parameters: [],
                     cyclomatic_complexity: 1, raises: [], calls_super: false)
        @name = name
        @visibility = visibility
        @line_start = line_start
        @line_end = line_end
        @instance_variables = instance_variables
        @called_methods = called_methods
        @parameters = parameters
        @cyclomatic_complexity = cyclomatic_complexity
        @raises = raises
        @calls_super = calls_super
      end

      def public?
        visibility == :public
      end

      def empty?
        line_start == line_end
      end
    end
  end
end
```

**Step 4: lib/solid_score.rb に require を追加し、テスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/models/method_info"
```

Run: `bundle exec rspec spec/solid_score/models/method_info_spec.rb`
Expected: PASS

**Step 5: ClassInfo のテストを書く**

```ruby
# spec/solid_score/models/class_info_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Models::ClassInfo do
  let(:public_method) { SolidScore::Models::MethodInfo.new(name: :process, visibility: :public) }
  let(:private_method) { SolidScore::Models::MethodInfo.new(name: :validate, visibility: :private) }
  let(:init_method) { SolidScore::Models::MethodInfo.new(name: :initialize, visibility: :public) }

  describe "#initialize" do
    it "stores class attributes" do
      class_info = described_class.new(
        name: "OrderService",
        file_path: "app/services/order_service.rb",
        line_start: 1,
        line_end: 50,
        methods: [public_method, private_method],
        superclass: "BaseService",
        includes: ["Validatable"],
        instance_variables: %i[@order @user]
      )

      expect(class_info.name).to eq("OrderService")
      expect(class_info.superclass).to eq("BaseService")
      expect(class_info.methods).to have_attributes(size: 2)
    end
  end

  describe "#public_methods_list" do
    it "returns only public methods excluding initialize" do
      class_info = described_class.new(
        name: "Foo",
        methods: [init_method, public_method, private_method]
      )

      expect(class_info.public_methods_list.map(&:name)).to eq([:process])
    end
  end

  describe "#line_count" do
    it "calculates lines from start to end" do
      class_info = described_class.new(name: "Foo", line_start: 1, line_end: 50)
      expect(class_info.line_count).to eq(50)
    end
  end

  describe "#has_superclass?" do
    it "returns true when superclass is present" do
      class_info = described_class.new(name: "Foo", superclass: "Bar")
      expect(class_info.has_superclass?).to be true
    end

    it "returns false when no superclass" do
      class_info = described_class.new(name: "Foo")
      expect(class_info.has_superclass?).to be false
    end
  end

  describe "#data_class?" do
    it "returns true when all methods are attr readers/writers" do
      attr_method = SolidScore::Models::MethodInfo.new(
        name: :name, visibility: :public, line_start: 2, line_end: 2
      )
      class_info = described_class.new(
        name: "Foo",
        methods: [init_method, attr_method],
        attr_readers: [:name],
        attr_writers: []
      )
      expect(class_info.data_class?).to be true
    end
  end
end
```

**Step 6: テストが失敗することを確認**

Run: `bundle exec rspec spec/solid_score/models/class_info_spec.rb`
Expected: FAIL

**Step 7: ClassInfo を実装**

```ruby
# lib/solid_score/models/class_info.rb
# frozen_string_literal: true

module SolidScore
  module Models
    class ClassInfo
      attr_reader :name, :file_path, :line_start, :line_end,
                  :methods, :superclass, :includes, :extends,
                  :instance_variables, :attr_readers, :attr_writers

      def initialize(name:, file_path: "", line_start: 0, line_end: 0,
                     methods: [], superclass: nil, includes: [], extends: [],
                     instance_variables: [], attr_readers: [], attr_writers: [])
        @name = name
        @file_path = file_path
        @line_start = line_start
        @line_end = line_end
        @methods = methods
        @superclass = superclass
        @includes = includes
        @extends = extends
        @instance_variables = instance_variables
        @attr_readers = attr_readers
        @attr_writers = attr_writers
      end

      def public_methods_list
        methods.select { |m| m.public? && m.name != :initialize }
      end

      def line_count
        line_end - line_start + 1
      end

      def has_superclass?
        !superclass.nil? && !superclass.empty?
      end

      def data_class?
        all_attrs = attr_readers + attr_writers
        return false if all_attrs.empty?

        non_init_methods = methods.reject { |m| m.name == :initialize }
        non_init_methods.all? { |m| all_attrs.include?(m.name) }
      end
    end
  end
end
```

**Step 8: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/models/class_info"
```

Run: `bundle exec rspec spec/solid_score/models/class_info_spec.rb`
Expected: PASS

**Step 9: ScoreResult のテストを書く**

```ruby
# spec/solid_score/models/score_result_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Models::ScoreResult do
  describe "#initialize" do
    it "stores scores for each principle" do
      result = described_class.new(
        class_name: "OrderService",
        file_path: "app/services/order_service.rb",
        srp: 85.0,
        ocp: 70.0,
        lsp: 100.0,
        isp: 60.0,
        dip: 75.0
      )

      expect(result.srp).to eq(85.0)
      expect(result.ocp).to eq(70.0)
      expect(result.class_name).to eq("OrderService")
    end
  end

  describe "#total" do
    it "calculates weighted average with default weights" do
      result = described_class.new(
        class_name: "Foo",
        srp: 100.0,
        ocp: 100.0,
        lsp: 100.0,
        isp: 100.0,
        dip: 100.0
      )

      expect(result.total).to eq(100.0)
    end

    it "applies custom weights" do
      result = described_class.new(
        class_name: "Foo",
        srp: 100.0,
        ocp: 0.0,
        lsp: 0.0,
        isp: 0.0,
        dip: 0.0,
        weights: { srp: 1.0, ocp: 0.0, lsp: 0.0, isp: 0.0, dip: 0.0 }
      )

      expect(result.total).to eq(100.0)
    end
  end

  describe "#confidence" do
    it "returns confidence levels for each principle" do
      result = described_class.new(class_name: "Foo")
      confidence = result.confidence

      expect(confidence[:srp]).to eq(:high)
      expect(confidence[:ocp]).to eq(:low)
      expect(confidence[:dip]).to eq(:high)
    end
  end
end
```

**Step 10: ScoreResult を実装**

```ruby
# lib/solid_score/models/score_result.rb
# frozen_string_literal: true

module SolidScore
  module Models
    class ScoreResult
      DEFAULT_WEIGHTS = {
        srp: 0.30,
        ocp: 0.15,
        lsp: 0.10,
        isp: 0.20,
        dip: 0.25
      }.freeze

      CONFIDENCE_LEVELS = {
        srp: :high,
        ocp: :low,
        lsp: :low_medium,
        isp: :medium_high,
        dip: :high
      }.freeze

      attr_reader :class_name, :file_path, :srp, :ocp, :lsp, :isp, :dip, :weights

      def initialize(class_name:, file_path: "", srp: 0.0, ocp: 0.0, lsp: 0.0, isp: 0.0, dip: 0.0,
                     weights: DEFAULT_WEIGHTS)
        @class_name = class_name
        @file_path = file_path
        @srp = srp
        @ocp = ocp
        @lsp = lsp
        @isp = isp
        @dip = dip
        @weights = weights
      end

      def total
        (srp * weights[:srp]) +
          (ocp * weights[:ocp]) +
          (lsp * weights[:lsp]) +
          (isp * weights[:isp]) +
          (dip * weights[:dip])
      end

      def confidence
        CONFIDENCE_LEVELS
      end
    end
  end
end
```

**Step 11: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/models/score_result"
```

Run: `bundle exec rspec spec/solid_score/models/`
Expected: ALL PASS

**Step 12: コミット**

```bash
git add lib/solid_score/models/ spec/solid_score/models/ lib/solid_score.rb
git commit -m "ai/feat: Models (ClassInfo, MethodInfo, ScoreResult) を追加"
```

---

## Task 3: Parser - Ruby AST パーサー

**Files:**
- Create: `lib/solid_score/parser/ruby_parser.rb`
- Create: `spec/solid_score/parser/ruby_parser_spec.rb`
- Create: `spec/fixtures/simple_class.rb`
- Create: `spec/fixtures/class_with_inheritance.rb`
- Create: `spec/fixtures/multiple_classes.rb`

**Step 1: テスト用フィクスチャを作成**

```ruby
# spec/fixtures/simple_class.rb
class Calculator
  def initialize(tax_rate)
    @tax_rate = tax_rate
  end

  def calculate(amount)
    amount + tax_amount(amount)
  end

  private

  def tax_amount(amount)
    amount * @tax_rate
  end
end
```

```ruby
# spec/fixtures/class_with_inheritance.rb
class Animal
  def speak
    raise NotImplementedError
  end
end

class Dog < Animal
  def speak
    "woof"
  end

  def fetch(item)
    "fetches #{item}"
  end
end
```

```ruby
# spec/fixtures/multiple_classes.rb
class Foo
  def bar
    "bar"
  end
end

class Baz
  include Comparable

  def qux
    "qux"
  end
end
```

**Step 2: RubyParser のテストを書く**

```ruby
# spec/solid_score/parser/ruby_parser_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Parser::RubyParser do
  let(:fixtures_path) { File.expand_path("../../fixtures", __FILE__) }

  describe "#parse_file" do
    it "extracts class info from a simple class" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")

      expect(classes.size).to eq(1)

      calc = classes.first
      expect(calc.name).to eq("Calculator")
      expect(calc.superclass).to be_nil
      expect(calc.methods.size).to eq(3) # initialize, calculate, tax_amount
    end

    it "detects method visibility" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")
      calc = classes.first

      public_names = calc.methods.select(&:public?).map(&:name)
      expect(public_names).to contain_exactly(:initialize, :calculate)

      private_names = calc.methods.reject(&:public?).map(&:name)
      expect(private_names).to contain_exactly(:tax_amount)
    end

    it "detects instance variables" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")
      calc = classes.first

      init = calc.methods.find { |m| m.name == :initialize }
      expect(init.instance_variables).to include(:@tax_rate)
    end

    it "detects inheritance" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/class_with_inheritance.rb")

      dog = classes.find { |c| c.name == "Dog" }
      expect(dog.superclass).to eq("Animal")
    end

    it "extracts multiple classes from one file" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/multiple_classes.rb")

      expect(classes.size).to eq(2)
      names = classes.map(&:name)
      expect(names).to contain_exactly("Foo", "Baz")
    end

    it "detects includes" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/multiple_classes.rb")

      baz = classes.find { |c| c.name == "Baz" }
      expect(baz.includes).to include("Comparable")
    end

    it "detects method calls within methods" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")
      calc = classes.first

      calculate_method = calc.methods.find { |m| m.name == :calculate }
      expect(calculate_method.called_methods).to include(:tax_amount)
    end
  end
end
```

**Step 3: テストが失敗することを確認**

Run: `bundle exec rspec spec/solid_score/parser/ruby_parser_spec.rb`
Expected: FAIL - `uninitialized constant SolidScore::Parser::RubyParser`

**Step 4: RubyParser を実装**

```ruby
# lib/solid_score/parser/ruby_parser.rb
# frozen_string_literal: true

require "parser/current"

module SolidScore
  module Parser
    class RubyParser
      def parse_file(file_path)
        source = File.read(file_path)
        ast = ::Parser::CurrentRuby.parse(source)
        return [] unless ast

        extract_classes(ast, file_path)
      end

      private

      def extract_classes(node, file_path, classes = [])
        return classes unless node.is_a?(::AST::Node)

        if node.type == :class
          classes << build_class_info(node, file_path)
        else
          node.children.each { |child| extract_classes(child, file_path, classes) }
        end

        classes
      end

      def build_class_info(node, file_path)
        name = extract_class_name(node.children[0])
        superclass = node.children[1] ? extract_class_name(node.children[1]) : nil
        body = node.children[2]

        methods = []
        includes = []
        extends = []
        attr_readers = []
        attr_writers = []
        current_visibility = :public

        if body
          traverse_body(body, methods, includes, extends, attr_readers, attr_writers, current_visibility)
        end

        instance_variables = methods.flat_map(&:instance_variables).uniq

        Models::ClassInfo.new(
          name: name,
          file_path: file_path,
          line_start: node.loc.line,
          line_end: node.loc.last_line,
          methods: methods,
          superclass: superclass,
          includes: includes,
          extends: extends,
          instance_variables: instance_variables,
          attr_readers: attr_readers,
          attr_writers: attr_writers
        )
      end

      def traverse_body(node, methods, includes, extends, attr_readers, attr_writers, current_visibility)
        return unless node.is_a?(::AST::Node)

        case node.type
        when :begin
          node.children.each do |child|
            current_visibility = traverse_body(child, methods, includes, extends,
                                               attr_readers, attr_writers, current_visibility)
          end
        when :def
          methods << build_method_info(node, current_visibility)
        when :send
          current_visibility = handle_send_node(node, current_visibility, includes, extends,
                                                attr_readers, attr_writers)
        end

        current_visibility
      end

      def handle_send_node(node, current_visibility, includes, extends, attr_readers, attr_writers)
        method_name = node.children[1]

        case method_name
        when :private, :protected, :public
          method_name
        when :include
          includes << extract_class_name(node.children[2]) if node.children[2]
          current_visibility
        when :extend
          extends << extract_class_name(node.children[2]) if node.children[2]
          current_visibility
        when :attr_reader
          node.children[2..].each { |arg| attr_readers << arg.children[0] if arg.type == :sym }
          current_visibility
        when :attr_accessor
          node.children[2..].each do |arg|
            next unless arg.type == :sym

            attr_readers << arg.children[0]
            attr_writers << arg.children[0]
          end
          current_visibility
        when :attr_writer
          node.children[2..].each { |arg| attr_writers << arg.children[0] if arg.type == :sym }
          current_visibility
        else
          current_visibility
        end
      end

      def build_method_info(node, visibility)
        name = node.children[0]
        args = node.children[1]
        body = node.children[2]

        instance_vars = []
        called_methods = []
        raises = []
        calls_super = false

        if body
          collect_method_details(body, instance_vars, called_methods, raises)
          calls_super = contains_super?(body)
        end

        parameters = extract_parameters(args)
        complexity = calculate_cyclomatic_complexity(body)

        Models::MethodInfo.new(
          name: name,
          visibility: visibility,
          line_start: node.loc.line,
          line_end: node.loc.last_line,
          instance_variables: instance_vars.uniq,
          called_methods: called_methods.uniq,
          parameters: parameters,
          cyclomatic_complexity: complexity,
          raises: raises,
          calls_super: calls_super
        )
      end

      def collect_method_details(node, instance_vars, called_methods, raises)
        return unless node.is_a?(::AST::Node)

        case node.type
        when :ivar, :ivasgn
          instance_vars << node.children[0]
        when :send
          if node.children[0].nil?
            called_methods << node.children[1]
          end
          if %i[raise fail].include?(node.children[1])
            raise_class = node.children[2]
            raises << extract_class_name(raise_class) if raise_class&.is_a?(::AST::Node) && raise_class.type == :const
          end
        end

        node.children.each { |child| collect_method_details(child, instance_vars, called_methods, raises) }
      end

      def contains_super?(node)
        return false unless node.is_a?(::AST::Node)
        return true if node.type == :super || node.type == :zsuper

        node.children.any? { |child| contains_super?(child) }
      end

      def extract_parameters(args_node)
        return [] unless args_node

        args_node.children.map do |arg|
          [arg.type, arg.children[0]]
        end
      end

      def calculate_cyclomatic_complexity(node, complexity = 1)
        return complexity unless node.is_a?(::AST::Node)

        case node.type
        when :if, :while, :until, :for, :when, :and, :or, :rescue
          complexity += 1
        end

        node.children.each do |child|
          complexity = calculate_cyclomatic_complexity(child, complexity)
        end

        complexity
      end

      def extract_class_name(node)
        return nil unless node.is_a?(::AST::Node)

        case node.type
        when :const
          parent = node.children[0]
          name = node.children[1].to_s
          parent ? "#{extract_class_name(parent)}::#{name}" : name
        else
          node.to_s
        end
      end
    end
  end
end
```

**Step 5: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/parser/ruby_parser"
```

Run: `bundle exec rspec spec/solid_score/parser/ruby_parser_spec.rb`
Expected: ALL PASS

**Step 6: コミット**

```bash
git add lib/solid_score/parser/ spec/solid_score/parser/ spec/fixtures/ lib/solid_score.rb
git commit -m "ai/feat: RubyParser (AST解析・クラス情報抽出) を追加"
```

---

## Task 4: SRP Analyzer (LCOM4)

**Files:**
- Create: `lib/solid_score/analyzers/base_analyzer.rb`
- Create: `lib/solid_score/analyzers/srp_analyzer.rb`
- Create: `spec/solid_score/analyzers/srp_analyzer_spec.rb`
- Create: `spec/fixtures/good_srp.rb`
- Create: `spec/fixtures/bad_srp.rb`
- Create: `spec/fixtures/data_class.rb`

**Step 1: テスト用フィクスチャを作成**

```ruby
# spec/fixtures/good_srp.rb
# 凝集度の高いクラス - LCOM4=1 を期待
class TaxCalculator
  def initialize(rate)
    @rate = rate
  end

  def calculate(amount)
    amount * @rate
  end

  def calculate_with_discount(amount, discount)
    discounted = apply_discount(amount, discount)
    calculate(discounted)
  end

  private

  def apply_discount(amount, discount)
    amount * (1 - discount)
  end
end
```

```ruby
# spec/fixtures/bad_srp.rb
# 凝集度の低いクラス - LCOM4>=2 を期待
class GodClass
  def initialize
    @users = []
    @orders = []
    @log = []
  end

  def add_user(user)
    @users << user
  end

  def find_user(name)
    @users.find { |u| u.name == name }
  end

  def create_order(order)
    @orders << order
  end

  def total_orders
    @orders.sum(&:total)
  end

  def log_message(msg)
    @log << msg
  end

  def print_log
    @log.each { |l| puts l }
  end
end
```

```ruby
# spec/fixtures/data_class.rb
class UserData
  attr_reader :name, :email, :age

  def initialize(name:, email:, age:)
    @name = name
    @email = email
    @age = age
  end
end
```

**Step 2: BaseAnalyzer とテストを書く**

```ruby
# spec/solid_score/analyzers/srp_analyzer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::SrpAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __FILE__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a cohesive class (good SRP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_srp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with a god class (bad SRP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_srp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be <= 60
      end
    end

    context "with a data class" do
      it "returns a high score (penalty mitigated)" do
        classes = parser.parse_file("#{fixtures_path}/data_class.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with a class with no methods" do
      it "returns 100 (trivial class)" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Empty", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end
  end

  describe "#calculate_lcom4" do
    it "returns 1 for a fully cohesive class" do
      classes = parser.parse_file("#{fixtures_path}/good_srp.rb")
      lcom4 = analyzer.calculate_lcom4(classes.first)

      expect(lcom4).to eq(1)
    end

    it "returns >= 2 for a class with multiple responsibilities" do
      classes = parser.parse_file("#{fixtures_path}/bad_srp.rb")
      lcom4 = analyzer.calculate_lcom4(classes.first)

      expect(lcom4).to be >= 2
    end
  end
end
```

**Step 3: テストが失敗することを確認**

Run: `bundle exec rspec spec/solid_score/analyzers/srp_analyzer_spec.rb`
Expected: FAIL

**Step 4: BaseAnalyzer を実装**

```ruby
# lib/solid_score/analyzers/base_analyzer.rb
# frozen_string_literal: true

module SolidScore
  module Analyzers
    class BaseAnalyzer
      def analyze(class_info)
        raise NotImplementedError, "#{self.class}#analyze must be implemented"
      end

      private

      def clamp_score(score)
        [[score, 0].max, 100].min.round(1)
      end
    end
  end
end
```

**Step 5: SrpAnalyzer を実装**

```ruby
# lib/solid_score/analyzers/srp_analyzer.rb
# frozen_string_literal: true

module SolidScore
  module Analyzers
    class SrpAnalyzer < BaseAnalyzer
      LCOM4_SCORES = {
        1 => 100,
        2 => 60,
        3 => 30
      }.freeze

      def analyze(class_info)
        methods = analyzable_methods(class_info)
        return 100 if methods.empty?

        lcom4 = calculate_lcom4(class_info)
        base_score = lcom4_to_score(lcom4)

        base_score = mitigate_data_class(base_score, class_info) if class_info.data_class?

        score = base_score
        score -= wmc_penalty(class_info)
        score -= line_count_penalty(class_info)

        clamp_score(score)
      end

      def calculate_lcom4(class_info)
        methods = analyzable_methods(class_info)
        return 1 if methods.size <= 1

        graph = build_method_graph(methods)
        count_connected_components(graph, methods)
      end

      private

      def analyzable_methods(class_info)
        class_info.methods.reject { |m| m.name == :initialize || m.empty? }
      end

      def build_method_graph(methods)
        adjacency = Hash.new { |h, k| h[k] = Set.new }

        methods.each_with_index do |m1, i|
          methods[(i + 1)..].each do |m2|
            if share_instance_variables?(m1, m2) || call_each_other?(m1, m2)
              adjacency[m1.name] << m2.name
              adjacency[m2.name] << m1.name
            end
          end
        end

        adjacency
      end

      def share_instance_variables?(m1, m2)
        (m1.instance_variables & m2.instance_variables).any?
      end

      def call_each_other?(m1, m2)
        m1.called_methods.include?(m2.name) || m2.called_methods.include?(m1.name)
      end

      def count_connected_components(graph, methods)
        visited = Set.new
        components = 0

        methods.each do |method|
          next if visited.include?(method.name)

          bfs(method.name, graph, visited)
          components += 1
        end

        components
      end

      def bfs(start, graph, visited)
        queue = [start]

        while (current = queue.shift)
          next if visited.include?(current)

          visited << current
          graph[current].each { |neighbor| queue << neighbor unless visited.include?(neighbor) }
        end
      end

      def lcom4_to_score(lcom4)
        LCOM4_SCORES.fetch(lcom4, 0)
      end

      def mitigate_data_class(score, _class_info)
        [score, 90].max
      end

      def wmc_penalty(class_info)
        wmc = class_info.methods.sum(&:cyclomatic_complexity)

        if wmc > 40
          20
        elsif wmc > 20
          10
        else
          0
        end
      end

      def line_count_penalty(class_info)
        lines = class_info.line_count

        if lines > 400
          20
        elsif lines > 200
          10
        else
          0
        end
      end
    end
  end
end
```

**Step 6: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/analyzers/base_analyzer"
require_relative "solid_score/analyzers/srp_analyzer"
```

Run: `bundle exec rspec spec/solid_score/analyzers/srp_analyzer_spec.rb`
Expected: ALL PASS

**Step 7: コミット**

```bash
git add lib/solid_score/analyzers/ spec/solid_score/analyzers/ spec/fixtures/ lib/solid_score.rb
git commit -m "ai/feat: SRP Analyzer (LCOM4アルゴリズム) を追加"
```

---

## Task 5: OCP Analyzer

**Files:**
- Create: `lib/solid_score/analyzers/ocp_analyzer.rb`
- Create: `spec/solid_score/analyzers/ocp_analyzer_spec.rb`
- Create: `spec/fixtures/good_ocp.rb`
- Create: `spec/fixtures/bad_ocp.rb`

**Step 1: テスト用フィクスチャを作成**

```ruby
# spec/fixtures/good_ocp.rb
class Shape
  def area
    raise NotImplementedError
  end
end

class Circle < Shape
  def initialize(radius)
    @radius = radius
  end

  def area
    Math::PI * @radius**2
  end
end
```

```ruby
# spec/fixtures/bad_ocp.rb
class ShapeCalculator
  def area(shape)
    case shape.type
    when :circle
      Math::PI * shape.radius**2
    when :rectangle
      shape.width * shape.height
    when :triangle
      0.5 * shape.base * shape.height
    end
  end

  def perimeter(shape)
    if shape.is_a?(Circle)
      2 * Math::PI * shape.radius
    elsif shape.is_a?(Rectangle)
      2 * (shape.width + shape.height)
    elsif shape.is_a?(Triangle)
      shape.side_a + shape.side_b + shape.side_c
    end
  end
end
```

**Step 2: テストを書く**

```ruby
# spec/solid_score/analyzers/ocp_analyzer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::OcpAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __FILE__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a class using polymorphism (good OCP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_ocp.rb")
        shape = classes.find { |c| c.name == "Shape" }
        score = analyzer.analyze(shape)

        expect(score).to be >= 80
      end
    end

    context "with a class using case/when and type checks (bad OCP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_ocp.rb")
        calc = classes.first
        score = analyzer.analyze(calc)

        expect(score).to be <= 50
      end
    end

    context "with a class with no methods" do
      it "returns 100" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Empty", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end
  end
end
```

**Step 3: テストが失敗することを確認**

Run: `bundle exec rspec spec/solid_score/analyzers/ocp_analyzer_spec.rb`
Expected: FAIL

**Step 4: OcpAnalyzer を実装**

```ruby
# lib/solid_score/analyzers/ocp_analyzer.rb
# frozen_string_literal: true

module SolidScore
  module Analyzers
    class OcpAnalyzer < BaseAnalyzer
      TYPE_CHECK_METHODS = %i[is_a? kind_of? instance_of?].freeze
      EXTENSION_PATTERNS = [:raise].freeze
      MAX_TYPE_CHECK_PENALTY = 40
      MAX_EXTENSION_BONUS = 20

      def analyze(class_info)
        return 100 if class_info.methods.empty?

        score = 100.0

        score -= conditional_density_penalty(class_info)
        score -= type_check_penalty(class_info)
        score += extension_point_bonus(class_info)

        clamp_score(score)
      end

      private

      def conditional_density_penalty(class_info)
        method_count = class_info.methods.size.to_f
        return 0 if method_count.zero?

        case_count = count_case_whens(class_info)
        elsif_chain_count = count_elsif_chains(class_info)
        density = (case_count + elsif_chain_count) / method_count

        if density > 1.0
          40
        elsif density > 0.5
          20
        else
          0
        end
      end

      def count_case_whens(class_info)
        class_info.methods.sum do |method|
          count_node_type_in_method(method, :case)
        end
      end

      def count_elsif_chains(class_info)
        class_info.methods.count do |method|
          method.cyclomatic_complexity > 3
        end
      end

      def count_node_type_in_method(method, _type)
        method.cyclomatic_complexity > 1 ? 1 : 0
      end

      def type_check_penalty(class_info)
        type_checks = class_info.methods.sum do |method|
          method.called_methods.count { |m| TYPE_CHECK_METHODS.include?(m) }
        end

        [type_checks * 10, MAX_TYPE_CHECK_PENALTY].min
      end

      def extension_point_bonus(class_info)
        extension_points = class_info.methods.count do |method|
          method.raises.include?("NotImplementedError")
        end

        has_block_params = class_info.methods.count do |method|
          method.parameters.any? { |type, _| type == :block }
        end

        [((extension_points + has_block_params) * 10), MAX_EXTENSION_BONUS].min
      end
    end
  end
end
```

**Step 5: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/analyzers/ocp_analyzer"
```

Run: `bundle exec rspec spec/solid_score/analyzers/ocp_analyzer_spec.rb`
Expected: ALL PASS

**Step 6: コミット**

```bash
git add lib/solid_score/analyzers/ocp_analyzer.rb spec/solid_score/analyzers/ocp_analyzer_spec.rb spec/fixtures/good_ocp.rb spec/fixtures/bad_ocp.rb lib/solid_score.rb
git commit -m "ai/feat: OCP Analyzer (条件分岐密度・型チェック検出) を追加"
```

---

## Task 6: LSP Analyzer

**Files:**
- Create: `lib/solid_score/analyzers/lsp_analyzer.rb`
- Create: `spec/solid_score/analyzers/lsp_analyzer_spec.rb`
- Create: `spec/fixtures/good_lsp.rb`
- Create: `spec/fixtures/bad_lsp.rb`

**Step 1: フィクスチャ作成**

```ruby
# spec/fixtures/good_lsp.rb
class BaseProcessor
  def process(data)
    raise NotImplementedError
  end
end

class CsvProcessor < BaseProcessor
  def process(data)
    super
  rescue NotImplementedError
    data.split(",")
  end
end
```

```ruby
# spec/fixtures/bad_lsp.rb
class BaseLogger
  def log(message)
    puts message
  end
end

class StrictLogger < BaseLogger
  def log(message, level = :info)
    raise ArgumentError, "message too short" if message.length < 5

    super(message)
  end
end
```

**Step 2: テストを書く**

```ruby
# spec/solid_score/analyzers/lsp_analyzer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::LspAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __FILE__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a class without inheritance" do
      it "returns 100 (LSP not applicable)" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Standalone", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end

    context "with good LSP compliance" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_lsp.rb")
        csv_processor = classes.find { |c| c.name == "CsvProcessor" }
        score = analyzer.analyze(csv_processor)

        expect(score).to be >= 80
      end
    end

    context "with LSP violations (extra raises, signature change)" do
      it "returns a lower score" do
        classes = parser.parse_file("#{fixtures_path}/bad_lsp.rb")
        strict_logger = classes.find { |c| c.name == "StrictLogger" }
        score = analyzer.analyze(strict_logger)

        expect(score).to be < 100
      end
    end
  end
end
```

**Step 3: テスト失敗を確認**

Run: `bundle exec rspec spec/solid_score/analyzers/lsp_analyzer_spec.rb`
Expected: FAIL

**Step 4: LspAnalyzer を実装**

```ruby
# lib/solid_score/analyzers/lsp_analyzer.rb
# frozen_string_literal: true

module SolidScore
  module Analyzers
    class LspAnalyzer < BaseAnalyzer
      SIGNATURE_CHANGE_PENALTY = 20
      EXTRA_RAISE_PENALTY = 15
      NO_SUPER_PENALTY = 10

      def analyze(class_info)
        return 100 unless class_info.has_superclass?

        score = 100.0

        class_info.methods.each do |method|
          next if method.name == :initialize

          score -= signature_change_penalty(method, class_info)
          score -= extra_raise_penalty(method)
          score -= no_super_penalty(method)
        end

        clamp_score(score)
      end

      private

      def signature_change_penalty(method, _class_info)
        has_extra_params = method.parameters.size > 2
        has_extra_params ? SIGNATURE_CHANGE_PENALTY : 0
      end

      def extra_raise_penalty(method)
        standard_raises = ["NotImplementedError"]
        extra_raises = method.raises.reject { |r| standard_raises.include?(r) }

        extra_raises.any? ? EXTRA_RAISE_PENALTY : 0
      end

      def no_super_penalty(method)
        return 0 if method.calls_super

        NO_SUPER_PENALTY
      end
    end
  end
end
```

**Step 5: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/analyzers/lsp_analyzer"
```

Run: `bundle exec rspec spec/solid_score/analyzers/lsp_analyzer_spec.rb`
Expected: ALL PASS

**Step 6: コミット**

```bash
git add lib/solid_score/analyzers/lsp_analyzer.rb spec/solid_score/analyzers/lsp_analyzer_spec.rb spec/fixtures/good_lsp.rb spec/fixtures/bad_lsp.rb lib/solid_score.rb
git commit -m "ai/feat: LSP Analyzer (継承契約の遵守度) を追加"
```

---

## Task 7: ISP Analyzer

**Files:**
- Create: `lib/solid_score/analyzers/isp_analyzer.rb`
- Create: `spec/solid_score/analyzers/isp_analyzer_spec.rb`
- Create: `spec/fixtures/good_isp.rb`
- Create: `spec/fixtures/bad_isp.rb`

**Step 1: フィクスチャ作成**

```ruby
# spec/fixtures/good_isp.rb
class Printable
  def print
    format_output
  end

  private

  def format_output
    "formatted"
  end
end
```

```ruby
# spec/fixtures/bad_isp.rb
class KitchenSink
  include Comparable
  include Enumerable
  include Singleton
  extend Forwardable
  include Observable
  include MonitorMixin
  include Timeout

  def method_a; end
  def method_b; end
  def method_c; end
  def method_d; end
  def method_e; end
  def method_f; end
  def method_g; end
  def method_h; end
  def method_i; end
  def method_j; end
  def method_k; end
  def method_l; end
  def method_m; end
  def method_n; end
  def method_o; end
  def method_p; end
  def method_q; end
  def method_r; end
  def method_s; end
  def method_t; end
  def method_u; end
end
```

**Step 2: テストを書く**

```ruby
# spec/solid_score/analyzers/isp_analyzer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::IspAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __FILE__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a small focused interface (good ISP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_isp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with a bloated interface (bad ISP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_isp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be <= 40
      end
    end

    context "with no methods" do
      it "returns 100" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Empty", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end
  end
end
```

**Step 3: テスト失敗を確認**

Run: `bundle exec rspec spec/solid_score/analyzers/isp_analyzer_spec.rb`
Expected: FAIL

**Step 4: IspAnalyzer を実装**

```ruby
# lib/solid_score/analyzers/isp_analyzer.rb
# frozen_string_literal: true

module SolidScore
  module Analyzers
    class IspAnalyzer < BaseAnalyzer
      PUBLIC_METHOD_SCORES = [
        [5, 100],
        [10, 80],
        [15, 60],
        [20, 40]
      ].freeze

      def analyze(class_info)
        public_methods = class_info.public_methods_list
        return 100 if public_methods.empty?

        score = public_method_score(public_methods.size)
        score -= include_penalty(class_info)
        score -= cohesion_penalty(class_info)

        clamp_score(score)
      end

      private

      def public_method_score(count)
        PUBLIC_METHOD_SCORES.each do |threshold, score|
          return score if count <= threshold
        end

        20
      end

      def include_penalty(class_info)
        include_count = class_info.includes.size + class_info.extends.size

        if include_count >= 7
          20
        elsif include_count >= 4
          10
        else
          0
        end
      end

      def cohesion_penalty(class_info)
        public_methods = class_info.public_methods_list
        return 0 if public_methods.size <= 2

        srp = SrpAnalyzer.new
        public_only_class = Models::ClassInfo.new(
          name: class_info.name,
          methods: public_methods
        )
        lcom4 = srp.calculate_lcom4(public_only_class)

        lcom4 > 2 ? 15 : 0
      end
    end
  end
end
```

**Step 5: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/analyzers/isp_analyzer"
```

Run: `bundle exec rspec spec/solid_score/analyzers/isp_analyzer_spec.rb`
Expected: ALL PASS

**Step 6: コミット**

```bash
git add lib/solid_score/analyzers/isp_analyzer.rb spec/solid_score/analyzers/isp_analyzer_spec.rb spec/fixtures/good_isp.rb spec/fixtures/bad_isp.rb lib/solid_score.rb
git commit -m "ai/feat: ISP Analyzer (インタフェース肥大度) を追加"
```

---

## Task 8: DIP Analyzer

**Files:**
- Create: `lib/solid_score/analyzers/dip_analyzer.rb`
- Create: `spec/solid_score/analyzers/dip_analyzer_spec.rb`
- Create: `spec/fixtures/good_dip.rb`
- Create: `spec/fixtures/bad_dip.rb`

**Step 1: フィクスチャ作成**

```ruby
# spec/fixtures/good_dip.rb
class OrderService
  def initialize(repository:, notifier:)
    @repository = repository
    @notifier = notifier
  end

  def create(params)
    order = @repository.save(params)
    @notifier.notify(order)
    order
  end
end
```

```ruby
# spec/fixtures/bad_dip.rb
class OrderService
  def create(params)
    order = OrderRepository.new.save(params)
    EmailNotifier.new.notify(order)
    SlackNotifier.new.post(order)
    AuditLogger.new.log(order)
    InventoryManager.new.reserve(order)
    PaymentGateway.new.charge(order)
    order
  end
end
```

**Step 2: テストを書く**

```ruby
# spec/solid_score/analyzers/dip_analyzer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::DipAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __FILE__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with dependency injection (good DIP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_dip.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with hardcoded dependencies (bad DIP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_dip.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be <= 50
      end
    end

    context "with no dependencies" do
      it "returns 100" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Pure",
          methods: [SolidScore::Models::MethodInfo.new(name: :compute)]
        )
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end
  end
end
```

**Step 3: テスト失敗を確認**

Run: `bundle exec rspec spec/solid_score/analyzers/dip_analyzer_spec.rb`
Expected: FAIL

**Step 4: DipAnalyzer を実装**

```ruby
# lib/solid_score/analyzers/dip_analyzer.rb
# frozen_string_literal: true

require "set"

module SolidScore
  module Analyzers
    class DipAnalyzer < BaseAnalyzer
      DI_BONUS = 15

      def analyze(class_info)
        concrete_deps = count_concrete_instantiations(class_info)
        injected_deps = count_injected_dependencies(class_info)
        total_deps = concrete_deps + injected_deps

        return 100 if total_deps.zero?

        concrete_ratio = concrete_deps.to_f / total_deps
        score = 100 - (concrete_ratio * 100)

        score += DI_BONUS if injected_deps.positive?
        score -= ce_penalty(class_info)

        clamp_score(score)
      end

      private

      def count_concrete_instantiations(class_info)
        class_info.methods.sum do |method|
          method.called_methods.count { |m| m == :new }
        end
      end

      def count_injected_dependencies(class_info)
        init = class_info.methods.find { |m| m.name == :initialize }
        return 0 unless init

        init.parameters.count { |type, _| %i[key keyreq].include?(type) }
      end

      def ce_penalty(class_info)
        external_refs = Set.new
        class_info.methods.each do |method|
          method.called_methods.each do |called|
            external_refs << called if called == :new
          end
        end

        ce = external_refs.size + count_concrete_instantiations(class_info)

        if ce > 20
          20
        elsif ce > 10
          10
        else
          0
        end
      end
    end
  end
end
```

**Step 5: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/analyzers/dip_analyzer"
```

Run: `bundle exec rspec spec/solid_score/analyzers/dip_analyzer_spec.rb`
Expected: ALL PASS

**Step 6: コミット**

```bash
git add lib/solid_score/analyzers/dip_analyzer.rb spec/solid_score/analyzers/dip_analyzer_spec.rb spec/fixtures/good_dip.rb spec/fixtures/bad_dip.rb lib/solid_score.rb
git commit -m "ai/feat: DIP Analyzer (具象依存率・DI検出) を追加"
```

---

## Task 9: Scorer (重み付き総合スコア算出)

**Files:**
- Create: `lib/solid_score/scorer.rb`
- Create: `spec/solid_score/scorer_spec.rb`

**Step 1: テストを書く**

```ruby
# spec/solid_score/scorer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Scorer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../fixtures", __FILE__) }

  describe "#score" do
    it "returns a ScoreResult for a class" do
      classes = parser.parse_file("#{fixtures_path}/good_srp.rb")
      scorer = described_class.new
      result = scorer.score(classes.first)

      expect(result).to be_a(SolidScore::Models::ScoreResult)
      expect(result.class_name).to eq("TaxCalculator")
      expect(result.srp).to be_between(0, 100)
      expect(result.ocp).to be_between(0, 100)
      expect(result.lsp).to be_between(0, 100)
      expect(result.isp).to be_between(0, 100)
      expect(result.dip).to be_between(0, 100)
      expect(result.total).to be_between(0, 100)
    end

    it "accepts custom weights" do
      classes = parser.parse_file("#{fixtures_path}/good_srp.rb")
      weights = { srp: 1.0, ocp: 0.0, lsp: 0.0, isp: 0.0, dip: 0.0 }
      scorer = described_class.new(weights: weights)
      result = scorer.score(classes.first)

      expect(result.total).to eq(result.srp)
    end
  end

  describe "#score_all" do
    it "returns results for multiple classes" do
      classes = parser.parse_file("#{fixtures_path}/multiple_classes.rb")
      scorer = described_class.new
      results = scorer.score_all(classes)

      expect(results.size).to eq(2)
      expect(results.map(&:class_name)).to contain_exactly("Foo", "Baz")
    end
  end
end
```

**Step 2: テスト失敗を確認**

Run: `bundle exec rspec spec/solid_score/scorer_spec.rb`
Expected: FAIL

**Step 3: Scorer を実装**

```ruby
# lib/solid_score/scorer.rb
# frozen_string_literal: true

module SolidScore
  class Scorer
    def initialize(weights: Models::ScoreResult::DEFAULT_WEIGHTS)
      @weights = weights
      @srp_analyzer = Analyzers::SrpAnalyzer.new
      @ocp_analyzer = Analyzers::OcpAnalyzer.new
      @lsp_analyzer = Analyzers::LspAnalyzer.new
      @isp_analyzer = Analyzers::IspAnalyzer.new
      @dip_analyzer = Analyzers::DipAnalyzer.new
    end

    def score(class_info)
      Models::ScoreResult.new(
        class_name: class_info.name,
        file_path: class_info.file_path,
        srp: @srp_analyzer.analyze(class_info),
        ocp: @ocp_analyzer.analyze(class_info),
        lsp: @lsp_analyzer.analyze(class_info),
        isp: @isp_analyzer.analyze(class_info),
        dip: @dip_analyzer.analyze(class_info),
        weights: @weights
      )
    end

    def score_all(class_infos)
      class_infos.map { |ci| score(ci) }
    end
  end
end
```

**Step 4: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/scorer"
```

Run: `bundle exec rspec spec/solid_score/scorer_spec.rb`
Expected: ALL PASS

**Step 5: コミット**

```bash
git add lib/solid_score/scorer.rb spec/solid_score/scorer_spec.rb lib/solid_score.rb
git commit -m "ai/feat: Scorer (重み付き総合スコア算出) を追加"
```

---

## Task 10: Configuration

**Files:**
- Create: `lib/solid_score/configuration.rb`
- Create: `spec/solid_score/configuration_spec.rb`

**Step 1: テストを書く**

```ruby
# spec/solid_score/configuration_spec.rb
# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "tmpdir"

RSpec.describe SolidScore::Configuration do
  describe ".default" do
    it "returns default configuration" do
      config = described_class.default

      expect(config.paths).to eq(["."])
      expect(config.exclude).to eq([])
      expect(config.format).to eq(:text)
      expect(config.thresholds[:total]).to eq(0)
      expect(config.weights[:srp]).to eq(0.30)
    end
  end

  describe ".from_file" do
    it "loads configuration from YAML file" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          paths:
            - app/
            - lib/
          exclude:
            - "spec/**/*"
          thresholds:
            total: 70
          weights:
            srp: 0.40
          format: json
        YAML

        config = described_class.from_file(config_path)

        expect(config.paths).to eq(["app/", "lib/"])
        expect(config.exclude).to eq(["spec/**/*"])
        expect(config.thresholds[:total]).to eq(70)
        expect(config.weights[:srp]).to eq(0.40)
        expect(config.format).to eq(:json)
      end
    end

    it "returns default when file does not exist" do
      config = described_class.from_file("/nonexistent/.solid-score.yml")

      expect(config.paths).to eq(["."])
    end
  end

  describe "#merge_cli_options" do
    it "overrides config with CLI options" do
      config = described_class.default
      config.merge_cli_options(format: :json, min_score: 80)

      expect(config.format).to eq(:json)
      expect(config.thresholds[:total]).to eq(80)
    end
  end
end
```

**Step 2: テスト失敗を確認 → 実装**

```ruby
# lib/solid_score/configuration.rb
# frozen_string_literal: true

require "yaml"

module SolidScore
  class Configuration
    DEFAULT_WEIGHTS = {
      srp: 0.30,
      ocp: 0.15,
      lsp: 0.10,
      isp: 0.20,
      dip: 0.25
    }.freeze

    DEFAULT_THRESHOLDS = {
      total: 0,
      srp: 0,
      ocp: 0,
      lsp: 0,
      isp: 0,
      dip: 0
    }.freeze

    attr_accessor :paths, :exclude, :format, :thresholds, :weights,
                  :diff_ref, :max_decrease, :new_class_min

    def initialize
      @paths = ["."]
      @exclude = []
      @format = :text
      @thresholds = DEFAULT_THRESHOLDS.dup
      @weights = DEFAULT_WEIGHTS.dup
      @diff_ref = nil
      @max_decrease = nil
      @new_class_min = nil
    end

    def self.default
      new
    end

    def self.from_file(path)
      config = new
      return config unless File.exist?(path)

      yaml = YAML.safe_load_file(path, symbolize_names: false) || {}
      config.apply_yaml(yaml)
      config
    end

    def apply_yaml(yaml)
      @paths = yaml["paths"] if yaml["paths"]
      @exclude = yaml["exclude"] if yaml["exclude"]
      @format = yaml["format"]&.to_sym if yaml["format"]

      if yaml["thresholds"]
        yaml["thresholds"].each { |k, v| @thresholds[k.to_sym] = v }
      end

      if yaml["weights"]
        yaml["weights"].each { |k, v| @weights[k.to_sym] = v }
      end

      if yaml["diff"]
        @max_decrease = yaml["diff"]["max_decrease"]
        @new_class_min = yaml["diff"]["new_class_min"]
      end
    end

    def merge_cli_options(options)
      @format = options[:format] if options[:format]
      @diff_ref = options[:diff_ref] if options[:diff_ref]
      @thresholds[:total] = options[:min_score] if options[:min_score]

      %i[srp ocp lsp isp dip].each do |principle|
        key = :"min_#{principle}"
        @thresholds[principle] = options[key] if options[key]
      end

      @max_decrease = options[:max_decrease] if options[:max_decrease]
      @exclude = options[:exclude].split(",") if options[:exclude]
    end
  end
end
```

**Step 3: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/configuration"
```

Run: `bundle exec rspec spec/solid_score/configuration_spec.rb`
Expected: ALL PASS

**Step 4: コミット**

```bash
git add lib/solid_score/configuration.rb spec/solid_score/configuration_spec.rb lib/solid_score.rb
git commit -m "ai/feat: Configuration (YAML設定・CLI上書き) を追加"
```

---

## Task 11: Formatters (Text + JSON)

**Files:**
- Create: `lib/solid_score/formatters/base_formatter.rb`
- Create: `lib/solid_score/formatters/text_formatter.rb`
- Create: `lib/solid_score/formatters/json_formatter.rb`
- Create: `spec/solid_score/formatters/text_formatter_spec.rb`
- Create: `spec/solid_score/formatters/json_formatter_spec.rb`

**Step 1: テストを書く**

```ruby
# spec/solid_score/formatters/text_formatter_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Formatters::TextFormatter do
  let(:results) do
    [
      SolidScore::Models::ScoreResult.new(
        class_name: "OrderService",
        file_path: "app/services/order_service.rb",
        srp: 85.0, ocp: 70.0, lsp: 100.0, isp: 60.0, dip: 75.0
      )
    ]
  end

  describe "#format" do
    it "includes class name and scores" do
      formatter = described_class.new
      output = formatter.format(results)

      expect(output).to include("OrderService")
      expect(output).to include("85")
      expect(output).to include("70")
    end

    it "includes project average" do
      formatter = described_class.new
      output = formatter.format(results)

      expect(output).to include("Average") | expect(output).to include("average")
    end
  end
end
```

```ruby
# spec/solid_score/formatters/json_formatter_spec.rb
# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe SolidScore::Formatters::JsonFormatter do
  let(:results) do
    [
      SolidScore::Models::ScoreResult.new(
        class_name: "OrderService",
        file_path: "app/services/order_service.rb",
        srp: 85.0, ocp: 70.0, lsp: 100.0, isp: 60.0, dip: 75.0
      )
    ]
  end

  describe "#format" do
    it "returns valid JSON" do
      formatter = described_class.new
      output = formatter.format(results)
      parsed = JSON.parse(output)

      expect(parsed).to be_a(Hash)
      expect(parsed["classes"]).to be_an(Array)
      expect(parsed["classes"].first["class_name"]).to eq("OrderService")
      expect(parsed["classes"].first["srp"]).to eq(85.0)
    end

    it "includes summary" do
      formatter = described_class.new
      output = formatter.format(results)
      parsed = JSON.parse(output)

      expect(parsed["summary"]).to include("total_classes")
      expect(parsed["summary"]).to include("average_score")
    end
  end
end
```

**Step 2: テスト失敗を確認 → 実装**

```ruby
# lib/solid_score/formatters/base_formatter.rb
# frozen_string_literal: true

module SolidScore
  module Formatters
    class BaseFormatter
      def format(results)
        raise NotImplementedError
      end
    end
  end
end
```

```ruby
# lib/solid_score/formatters/text_formatter.rb
# frozen_string_literal: true

module SolidScore
  module Formatters
    class TextFormatter < BaseFormatter
      def format(results)
        return "No classes found to analyze.\n" if results.empty?

        lines = []
        lines << "solid-score v#{VERSION}\n"
        lines << "Analyzed #{results.size} class(es)\n\n"
        lines << header_line
        lines << separator_line

        results.each { |r| lines << result_line(r) }

        lines << separator_line
        lines << average_line(results)
        lines << ""

        lines.join("\n")
      end

      private

      def header_line
        format("%-40s %5s %5s %5s %5s %5s %7s", "Class", "SRP", "OCP", "LSP", "ISP", "DIP", "Total")
      end

      def separator_line
        "-" * 75
      end

      def result_line(result)
        format("%-40s %5.1f %5.1f %5.1f %5.1f %5.1f %7.1f",
               truncate(result.class_name, 40),
               result.srp, result.ocp, result.lsp, result.isp, result.dip, result.total)
      end

      def average_line(results)
        avg = ->(method) { results.sum(&method) / results.size.to_f }

        format("%-40s %5.1f %5.1f %5.1f %5.1f %5.1f %7.1f",
               "Average",
               avg.call(:srp), avg.call(:ocp), avg.call(:lsp),
               avg.call(:isp), avg.call(:dip), avg.call(:total))
      end

      def truncate(str, max)
        str.length > max ? "#{str[0..max - 4]}..." : str
      end
    end
  end
end
```

```ruby
# lib/solid_score/formatters/json_formatter.rb
# frozen_string_literal: true

require "json"

module SolidScore
  module Formatters
    class JsonFormatter < BaseFormatter
      def format(results)
        data = {
          version: VERSION,
          classes: results.map { |r| format_result(r) },
          summary: build_summary(results)
        }

        JSON.pretty_generate(data)
      end

      private

      def format_result(result)
        {
          class_name: result.class_name,
          file_path: result.file_path,
          srp: result.srp,
          ocp: result.ocp,
          lsp: result.lsp,
          isp: result.isp,
          dip: result.dip,
          total: result.total.round(1),
          confidence: result.confidence.transform_values(&:to_s)
        }
      end

      def build_summary(results)
        return { total_classes: 0, average_score: 0.0 } if results.empty?

        {
          total_classes: results.size,
          average_score: (results.sum(&:total) / results.size).round(1)
        }
      end
    end
  end
end
```

**Step 3: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/formatters/base_formatter"
require_relative "solid_score/formatters/text_formatter"
require_relative "solid_score/formatters/json_formatter"
```

Run: `bundle exec rspec spec/solid_score/formatters/`
Expected: ALL PASS

**Step 4: コミット**

```bash
git add lib/solid_score/formatters/ spec/solid_score/formatters/ lib/solid_score.rb
git commit -m "ai/feat: Formatters (Text + JSON出力) を追加"
```

---

## Task 12: Runner (オーケストレーション)

**Files:**
- Create: `lib/solid_score/runner.rb`
- Create: `spec/solid_score/runner_spec.rb`

**Step 1: テストを書く**

```ruby
# spec/solid_score/runner_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Runner do
  let(:fixtures_path) { File.expand_path("../fixtures", __FILE__) }

  describe "#run" do
    it "analyzes Ruby files in the given path and returns results" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.exclude = []

      runner = described_class.new(config)
      results = runner.run

      expect(results).to be_an(Array)
      expect(results).not_to be_empty
      expect(results.first).to be_a(SolidScore::Models::ScoreResult)
    end

    it "respects exclude patterns" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.exclude = ["**/bad_*.rb"]

      runner = described_class.new(config)
      results = runner.run

      bad_classes = results.select { |r| r.class_name.start_with?("God", "KitchenSink", "ShapeCalculator") }
      expect(bad_classes).to be_empty
    end
  end

  describe "#passing?" do
    it "returns true when all scores meet thresholds" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.thresholds[:total] = 0

      runner = described_class.new(config)
      runner.run

      expect(runner.passing?).to be true
    end

    it "returns false when scores are below threshold" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.thresholds[:total] = 100

      runner = described_class.new(config)
      runner.run

      expect(runner.passing?).to be false
    end
  end
end
```

**Step 2: テスト失敗を確認 → 実装**

```ruby
# lib/solid_score/runner.rb
# frozen_string_literal: true

module SolidScore
  class Runner
    attr_reader :results

    def initialize(config)
      @config = config
      @parser = Parser::RubyParser.new
      @scorer = Scorer.new(weights: config.weights)
      @results = []
    end

    def run
      files = collect_files
      classes = files.flat_map { |f| parse_file(f) }
      @results = @scorer.score_all(classes)
    end

    def passing?
      return true if @results.empty?

      @results.all? { |r| meets_thresholds?(r) }
    end

    def formatted_output
      formatter = build_formatter
      formatter.format(@results)
    end

    private

    def collect_files
      files = @config.paths.flat_map do |path|
        if File.file?(path)
          [path]
        else
          Dir.glob(File.join(path, "**", "*.rb"))
        end
      end

      files.reject { |f| excluded?(f) }
    end

    def excluded?(file)
      @config.exclude.any? do |pattern|
        File.fnmatch?(pattern, file, File::FNM_PATHNAME | File::FNM_DOTMATCH)
      end
    end

    def parse_file(file)
      @parser.parse_file(file)
    rescue ::Parser::SyntaxError
      []
    end

    def meets_thresholds?(result)
      return false if result.total < @config.thresholds[:total]

      %i[srp ocp lsp isp dip].all? do |principle|
        result.send(principle) >= @config.thresholds[principle]
      end
    end

    def build_formatter
      case @config.format
      when :json
        Formatters::JsonFormatter.new
      else
        Formatters::TextFormatter.new
      end
    end
  end
end
```

**Step 3: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/runner"
```

Run: `bundle exec rspec spec/solid_score/runner_spec.rb`
Expected: ALL PASS

**Step 4: コミット**

```bash
git add lib/solid_score/runner.rb spec/solid_score/runner_spec.rb lib/solid_score.rb
git commit -m "ai/feat: Runner (解析オーケストレーション) を追加"
```

---

## Task 13: CLI

**Files:**
- Create: `lib/solid_score/cli.rb`
- Create: `spec/solid_score/cli_spec.rb`

**Step 1: テストを書く**

```ruby
# spec/solid_score/cli_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::CLI do
  let(:fixtures_path) { File.expand_path("../fixtures", __FILE__) }

  describe "#run" do
    it "analyzes files and outputs results" do
      cli = described_class.new
      output = capture_stdout { cli.run([fixtures_path]) }

      expect(output).to include("solid-score")
      expect(output).to include("Average")
    end

    it "supports --format json" do
      cli = described_class.new
      output = capture_stdout { cli.run([fixtures_path, "--format", "json"]) }

      parsed = JSON.parse(output)
      expect(parsed["classes"]).to be_an(Array)
    end

    it "supports --version" do
      cli = described_class.new
      output = capture_stdout { cli.run(["--version"]) }

      expect(output).to include(SolidScore::VERSION)
    end

    it "returns exit code 1 when below threshold" do
      cli = described_class.new
      exit_code = nil

      capture_stdout do
        exit_code = cli.run([fixtures_path, "--min-score", "100"])
      end

      expect(exit_code).to eq(1)
    end

    it "returns exit code 0 when passing" do
      cli = described_class.new
      exit_code = nil

      capture_stdout do
        exit_code = cli.run([fixtures_path, "--min-score", "0"])
      end

      expect(exit_code).to eq(0)
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
```

**Step 2: テスト失敗を確認 → 実装**

```ruby
# lib/solid_score/cli.rb
# frozen_string_literal: true

require "optparse"

module SolidScore
  class CLI
    def run(args)
      options = parse_options(args)
      return 0 if options[:exit]

      config = load_config(options)
      config.merge_cli_options(options)

      paths = args.reject { |a| a.start_with?("-") }
      config.paths = paths unless paths.empty?

      runner = Runner.new(config)
      runner.run

      puts runner.formatted_output

      runner.passing? ? 0 : 1
    end

    private

    def parse_options(args)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: solid-score [path] [options]"

        opts.on("--format FORMAT", %w[text json], "Output format (text|json)") do |f|
          options[:format] = f.to_sym
        end

        opts.on("--config FILE", "Config file path") do |f|
          options[:config] = f
        end

        opts.on("--min-score SCORE", Integer, "Minimum total score (CI)") do |s|
          options[:min_score] = s
        end

        %w[srp ocp lsp isp dip].each do |principle|
          opts.on("--min-#{principle} SCORE", Integer, "Minimum #{principle.upcase} score") do |s|
            options[:"min_#{principle}"] = s
          end
        end

        opts.on("--diff REF", "Diff base reference") do |r|
          options[:diff_ref] = r
        end

        opts.on("--max-decrease SCORE", Integer, "Max score decrease per class") do |s|
          options[:max_decrease] = s
        end

        opts.on("--exclude PATTERN", "Exclude patterns (comma-separated)") do |p|
          options[:exclude] = p
        end

        opts.on("--version", "Show version") do
          puts "solid-score v#{VERSION}"
          options[:exit] = true
        end

        opts.on("-h", "--help", "Show help") do
          puts opts
          options[:exit] = true
        end
      end

      parser.parse!(args)
      options
    end

    def load_config(options)
      config_path = options[:config] || ".solid-score.yml"
      Configuration.from_file(config_path)
    end
  end
end
```

**Step 3: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/cli"
```

Run: `bundle exec rspec spec/solid_score/cli_spec.rb`
Expected: ALL PASS

**Step 4: 全テスト通過を確認**

Run: `bundle exec rspec`
Expected: ALL PASS

**Step 5: コミット**

```bash
git add lib/solid_score/cli.rb spec/solid_score/cli_spec.rb lib/solid_score.rb
git commit -m "ai/feat: CLI (OptionParser・exit code) を追加"
```

---

## Task 14: DiffAnalyzer (差分解析モード)

**Files:**
- Create: `lib/solid_score/diff_analyzer.rb`
- Create: `spec/solid_score/diff_analyzer_spec.rb`

**Step 1: テストを書く**

```ruby
# spec/solid_score/diff_analyzer_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::DiffAnalyzer do
  describe "#changed_files" do
    it "returns list of changed .rb files" do
      analyzer = described_class.new("HEAD~1")
      allow(analyzer).to receive(:git_diff_names).and_return(
        "app/models/user.rb\napp/models/order.rb\nREADME.md\n"
      )

      files = analyzer.changed_files
      expect(files).to eq(["app/models/user.rb", "app/models/order.rb"])
    end
  end

  describe "#changed_line_ranges" do
    it "parses diff output into file => ranges hash" do
      analyzer = described_class.new("HEAD~1")
      diff_output = <<~DIFF
        --- a/app/models/user.rb
        +++ b/app/models/user.rb
        @@ -10,5 +10,8 @@ class User
      DIFF

      allow(analyzer).to receive(:git_diff_output).and_return(diff_output)

      ranges = analyzer.changed_line_ranges
      expect(ranges).to have_key("app/models/user.rb")
    end
  end
end
```

**Step 2: テスト失敗を確認 → 実装**

```ruby
# lib/solid_score/diff_analyzer.rb
# frozen_string_literal: true

module SolidScore
  class DiffAnalyzer
    attr_reader :base_ref

    def initialize(base_ref)
      @base_ref = base_ref
    end

    def changed_files
      git_diff_names.split("\n").select { |f| f.end_with?(".rb") }
    end

    def changed_line_ranges
      ranges = Hash.new { |h, k| h[k] = [] }
      current_file = nil

      git_diff_output.each_line do |line|
        if line.start_with?("+++ b/")
          current_file = line.sub("+++ b/", "").strip
        elsif line.match?(/^@@ .+ @@/)
          match = line.match(/@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
          if match && current_file
            start_line = match[1].to_i
            count = (match[2] || "1").to_i
            ranges[current_file] << (start_line..(start_line + count - 1))
          end
        end
      end

      ranges
    end

    def filter_classes(classes, file_ranges)
      classes.select do |class_info|
        file_ranges.key?(class_info.file_path) &&
          file_ranges[class_info.file_path].any? do |range|
            range.overlaps?(class_info.line_start..class_info.line_end)
          end
      end
    end

    private

    def git_diff_names
      `git diff --name-only #{base_ref}`.strip
    end

    def git_diff_output
      `git diff #{base_ref}`
    end
  end
end
```

**Step 3: require を追加しテスト通過を確認**

`lib/solid_score.rb` に追加:
```ruby
require_relative "solid_score/diff_analyzer"
```

Run: `bundle exec rspec spec/solid_score/diff_analyzer_spec.rb`
Expected: ALL PASS

**Step 4: コミット**

```bash
git add lib/solid_score/diff_analyzer.rb spec/solid_score/diff_analyzer_spec.rb lib/solid_score.rb
git commit -m "ai/feat: DiffAnalyzer (git差分解析モード) を追加"
```

---

## Task 15: 統合テスト・全体動作確認

**Files:**
- Create: `spec/integration/full_analysis_spec.rb`

**Step 1: 統合テストを書く**

```ruby
# spec/integration/full_analysis_spec.rb
# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Full analysis integration" do
  let(:fixtures_path) { File.expand_path("../fixtures", __dir__) }

  it "analyzes all fixture files end-to-end" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]

    runner = SolidScore::Runner.new(config)
    results = runner.run

    expect(results).not_to be_empty

    results.each do |result|
      expect(result.srp).to be_between(0, 100)
      expect(result.ocp).to be_between(0, 100)
      expect(result.lsp).to be_between(0, 100)
      expect(result.isp).to be_between(0, 100)
      expect(result.dip).to be_between(0, 100)
      expect(result.total).to be_between(0, 100)
    end
  end

  it "good classes score higher than bad classes" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]

    runner = SolidScore::Runner.new(config)
    results = runner.run

    good_srp = results.find { |r| r.class_name == "TaxCalculator" }
    bad_srp = results.find { |r| r.class_name == "GodClass" }

    expect(good_srp.srp).to be > bad_srp.srp if good_srp && bad_srp
  end

  it "outputs valid text format" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]

    runner = SolidScore::Runner.new(config)
    runner.run
    output = runner.formatted_output

    expect(output).to include("solid-score")
    expect(output).to include("Average")
  end

  it "outputs valid JSON format" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]
    config.format = :json

    runner = SolidScore::Runner.new(config)
    runner.run
    output = runner.formatted_output

    parsed = JSON.parse(output)
    expect(parsed["classes"]).to be_an(Array)
    expect(parsed["summary"]["total_classes"]).to be > 0
  end
end
```

**Step 2: テスト通過を確認**

Run: `bundle exec rspec spec/integration/full_analysis_spec.rb`
Expected: ALL PASS

**Step 3: 全テストスイート通過を確認**

Run: `bundle exec rspec`
Expected: ALL PASS

**Step 4: RuboCop 通過を確認**

Run: `bundle exec rubocop`
Expected: no offenses detected (or fix offenses)

**Step 5: CLI の手動動作確認**

Run: `bundle exec ruby exe/solid-score spec/fixtures/`
Expected: テーブル形式でスコアが表示される

Run: `bundle exec ruby exe/solid-score spec/fixtures/ --format json`
Expected: JSON 形式で出力される

**Step 6: コミット**

```bash
git add spec/integration/
git commit -m "ai/test: 統合テスト追加・全体動作確認完了"
```

---

## Task 16: exe ファイルに実行権限付与・最終整備

**Step 1: exe に実行権限付与**

```bash
chmod +x exe/solid-score
```

**Step 2: 全テスト最終確認**

Run: `bundle exec rspec`
Run: `bundle exec rubocop`
Expected: ALL PASS

**Step 3: 最終コミット**

```bash
git add -A
git commit -m "ai/chore: 実行権限付与・最終整備"
```
