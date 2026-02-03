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

    # Phase 1 改善: simple_implementation? テスト
    context "with simple implementation (no super)" do
      it "does not penalize simple overrides (3 lines or less, no branching)" do
        classes = parser.parse_file("#{fixtures_path}/lsp_simple_override.rb")
        simple_processor = classes.find { |c| c.name == "SimpleProcessor" }
        score = analyzer.analyze(simple_processor)

        # Simple implementation should not be penalized
        expect(score).to eq(100)
      end

      it "does not penalize simple implementations with abstract parent pattern" do
        classes = parser.parse_file("#{fixtures_path}/lsp_simple_override.rb")
        json_handler = classes.find { |c| c.name == "JsonHandler" }
        score = analyzer.analyze(json_handler)

        # Parent is BaseHandler (contains "Base"), so no penalty
        expect(score).to eq(100)
      end
    end

    # Phase 1 改善: abstract_parent_pattern? テスト
    context "with abstract parent pattern" do
      it "recognizes Base* parent class names as abstract" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "ConcreteProcessor",
          superclass: "BaseProcessor",
          methods: [
            SolidScore::Models::MethodInfo.new(
              name: :process,
              visibility: :public,
              line_start: 1,
              line_end: 5,
              cyclomatic_complexity: 2,
              calls_super: false
            )
          ]
        )
        score = analyzer.analyze(class_info)

        # Abstract parent pattern, no penalty
        expect(score).to eq(100)
      end

      it "recognizes Abstract* parent class names as abstract" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "ConcreteHandler",
          superclass: "AbstractHandler",
          methods: [
            SolidScore::Models::MethodInfo.new(
              name: :handle,
              visibility: :public,
              line_start: 1,
              line_end: 5,
              cyclomatic_complexity: 2,
              calls_super: false
            )
          ]
        )
        score = analyzer.analyze(class_info)

        # Abstract parent pattern, no penalty
        expect(score).to eq(100)
      end
    end

    # Phase 1 改善: 複雑な実装への減点テスト
    context "with complex implementation without super" do
      it "applies reduced penalty for complex overrides" do
        classes = parser.parse_file("#{fixtures_path}/lsp_simple_override.rb")
        complex_processor = classes.find { |c| c.name == "ComplexProcessor" }
        score = analyzer.analyze(complex_processor)

        # ComplexProcessor has:
        # - Parent "BaseProcessor" (abstract_parent_pattern = true, so no super penalty)
        # - process method raises ArgumentError (extra_raise_penalty = 15)
        # - transform method is simple (no penalty)
        # Expected: 100 - 15 = 85
        expect(score).to eq(85)
      end
    end

    context "with regular parent class (not abstract pattern)" do
      it "applies reduced penalty for non-simple implementations" do
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

        # Should apply reduced penalty (5 points)
        expect(score).to eq(95)
      end
    end
  end
end
