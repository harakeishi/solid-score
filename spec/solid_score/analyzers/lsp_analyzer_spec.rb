# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::LspAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
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

    # super を呼ばないオーバーライド／新規追加メソッドはそれ自体では LSP 違反
    # ではないため減点しない。superclass の種類（フレームワーク基底・Base*・
    # 任意の親）やメソッドの複雑さに関わらず、契約破りの raise が無い限り 100 点
    # になることを示す。これは「no_super を判定軸から外した」という設計判断の
    # 回帰ガードであり、ここが 100 でなくなったらロジックが逆戻りしている。
    context "with overrides that skip super (no contract-breaking raise)" do
      def child_class(superclass:, raises: [])
        SolidScore::Models::ClassInfo.new(
          name: "Child",
          superclass: superclass,
          methods: [
            SolidScore::Models::MethodInfo.new(
              name: :work,
              visibility: :public,
              line_start: 1,
              line_end: 8, # 単純実装かどうかに依らず減点しないことを示すため複数行
              cyclomatic_complexity: 3, # 分岐があっても減点しない
              calls_super: false,
              raises: raises
            )
          ]
        )
      end

      it "does not penalize a Rails framework base subclass" do
        expect(analyzer.analyze(child_class(superclass: "ApplicationRecord"))).to eq(100)
      end

      it "does not penalize a Base*-named parent subclass" do
        expect(analyzer.analyze(child_class(superclass: "BaseProcessor"))).to eq(100)
      end

      it "does not penalize an arbitrary parent subclass" do
        expect(analyzer.analyze(child_class(superclass: "SomeRandomParent"))).to eq(100)
      end

      it "still penalizes a contract-breaking raise regardless of parent type" do
        score = analyzer.analyze(child_class(superclass: "ApplicationRecord", raises: ["ArgumentError"]))
        expect(score).to eq(85)
      end
    end

    # 同じ性質をパーサ経由のフィクスチャでも確認する。ComplexProcessor は
    # ArgumentError を raise するため extra_raise(15) のみが効いて 85 点になる。
    context "with parsed fixtures" do
      it "leaves a simple override at 100" do
        classes = parser.parse_file("#{fixtures_path}/lsp_simple_override.rb")
        simple_processor = classes.find { |c| c.name == "SimpleProcessor" }
        expect(analyzer.analyze(simple_processor)).to eq(100)
      end

      it "penalizes only the contract-breaking raise in a complex override" do
        classes = parser.parse_file("#{fixtures_path}/lsp_simple_override.rb")
        complex_processor = classes.find { |c| c.name == "ComplexProcessor" }
        # process が ArgumentError を raise → extra_raise_penalty(15) のみ。
        expect(analyzer.analyze(complex_processor)).to eq(85)
      end
    end

    context "with an override that does not call super" do
      it "does not penalize merely for skipping super" do
        # 「super を呼ばないこと自体」は LSP 違反ではない。静的解析では
        # 完全オーバーライド／新規追加メソッドと区別できないため減点しない。
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Child",
          superclass: "Parent", # Not a Base* or Abstract* class
          methods: [
            SolidScore::Models::MethodInfo.new(
              name: :complex_method,
              visibility: :public,
              line_start: 1,
              line_end: 10, # More than 3 lines
              cyclomatic_complexity: 3, # Complex
              calls_super: false
            )
          ]
        )
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end

      it "still penalizes overrides that raise a non-standard exception" do
        # 親契約を破る例外（NotImplementedError 以外）は引き続き減点する。
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Child",
          superclass: "Parent",
          methods: [
            SolidScore::Models::MethodInfo.new(
              name: :risky,
              visibility: :public,
              line_start: 1,
              line_end: 10,
              cyclomatic_complexity: 3,
              calls_super: false,
              raises: ["ArgumentError"]
            )
          ]
        )
        score = analyzer.analyze(class_info)

        expect(score).to eq(85)
      end
    end
  end
end
