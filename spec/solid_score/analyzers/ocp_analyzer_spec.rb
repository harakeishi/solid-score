# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::OcpAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
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

    # Phase 1 改善: case/when ペナルティテスト
    context "with case/when pattern" do
      it "applies penalty for case/when branches" do
        classes = parser.parse_file("#{fixtures_path}/ocp_case_when.rb")
        type_handler = classes.find { |c| c.name == "TypeHandler" }
        score = analyzer.analyze(type_handler)

        # 3 when branches * 5 points = 15 points penalty (plus conditional density)
        expect(score).to be < 100
      end

      it "does not penalize classes without case/when" do
        classes = parser.parse_file("#{fixtures_path}/ocp_case_when.rb")
        simple_processor = classes.find { |c| c.name == "SimpleProcessor" }
        score = analyzer.analyze(simple_processor)

        expect(score).to eq(100)
      end
    end

    context "with case_when_count in MethodInfo" do
      it "counts case/when branches correctly" do
        method_with_case = SolidScore::Models::MethodInfo.new(
          name: :process,
          case_when_count: 5 # 5 when branches
        )
        class_info = SolidScore::Models::ClassInfo.new(
          name: "TestClass",
          methods: [method_with_case]
        )

        score = analyzer.analyze(class_info)

        # 5 branches * 5 points = 25 points penalty
        expect(score).to eq(75)
      end

      it "caps case/when penalty at maximum" do
        method_with_many_cases = SolidScore::Models::MethodInfo.new(
          name: :process,
          case_when_count: 10 # 10 when branches
        )
        class_info = SolidScore::Models::ClassInfo.new(
          name: "TestClass",
          methods: [method_with_many_cases]
        )

        score = analyzer.analyze(class_info)

        # Should cap at 30 points (MAX_CASE_WHEN_PENALTY)
        expect(score).to eq(70)
      end
    end
  end
end
