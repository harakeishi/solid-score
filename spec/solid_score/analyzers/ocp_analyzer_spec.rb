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

    # Phase 2b: respond_to? の弱い型チェックペナルティ
    context "with respond_to? checks" do
      it "applies reduced penalty for respond_to?" do
        classes = parser.parse_file("#{fixtures_path}/respond_to_example.rb")
        handler = classes.first
        score = analyzer.analyze(handler)

        # respond_to? は弱い型チェック（5点/回）→ 3回 = 15点
        expect(score).to be < 100
        expect(score).to be > 50
      end

      it "penalizes respond_to? less than is_a?" do
        # respond_to? 3回 → 15点
        respond_to_method = SolidScore::Models::MethodInfo.new(
          name: :handle,
          called_methods: [:respond_to?, :respond_to?, :respond_to?]
        )
        respond_to_class = SolidScore::Models::ClassInfo.new(
          name: "A", methods: [respond_to_method]
        )

        # is_a? 3回 → 30点
        is_a_method = SolidScore::Models::MethodInfo.new(
          name: :handle,
          called_methods: [:is_a?, :is_a?, :is_a?]
        )
        is_a_class = SolidScore::Models::ClassInfo.new(
          name: "B", methods: [is_a_method]
        )

        respond_to_score = analyzer.analyze(respond_to_class)
        is_a_score = analyzer.analyze(is_a_class)

        expect(respond_to_score).to be > is_a_score
      end
    end

    # Issue #11: 2-way / 3-way case/when leniency
    context "with light case/when usage" do
      it "applies 2pt for a 2-way case (1 when clause)" do
        method = SolidScore::Models::MethodInfo.new(name: :process, case_when_count: 1)
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        # base 100 - 2 = 98 (no other penalty for a single method without complexity)
        expect(analyzer.analyze(class_info)).to eq(98)
      end

      it "applies 5pt for a 3-way case (2 when clauses)" do
        method = SolidScore::Models::MethodInfo.new(name: :process, case_when_count: 2)
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        expect(analyzer.analyze(class_info)).to eq(95)
      end

      it "uses linear penalty for 4-way and more" do
        method3 = SolidScore::Models::MethodInfo.new(name: :process, case_when_count: 3)
        method4 = SolidScore::Models::MethodInfo.new(name: :process, case_when_count: 4)

        c3 = SolidScore::Models::ClassInfo.new(name: "Demo3", methods: [method3])
        c4 = SolidScore::Models::ClassInfo.new(name: "Demo4", methods: [method4])

        # n*5 starting from n=3
        expect(analyzer.analyze(c3)).to eq(85)
        expect(analyzer.analyze(c4)).to eq(80)
      end

      it "accumulates penalties across methods" do
        m1 = SolidScore::Models::MethodInfo.new(name: :a, case_when_count: 1)
        m2 = SolidScore::Models::MethodInfo.new(name: :b, case_when_count: 1)
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [m1, m2])
        # 2pt + 2pt = 4pt
        expect(analyzer.analyze(class_info)).to eq(96)
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

      # Issue #11 follow-up: under the per-method curve the cap still applies
      # when many methods each contribute moderate-size case/when penalties.
      it "caps the class-level penalty when accumulation across methods exceeds MAX" do
        # 4 methods * 4 when-clauses each: per-method 4*5 = 20pt -> total raw 80pt,
        # capped at MAX_CASE_WHEN_PENALTY = 30pt.
        methods = (1..4).map do |i|
          SolidScore::Models::MethodInfo.new(name: :"m_#{i}", case_when_count: 4)
        end
        class_info = SolidScore::Models::ClassInfo.new(name: "Big", methods: methods)
        # density = (cyclomatic-1)*4 / 4 = 0 (default complexity 1) -> no density penalty
        # case_when_penalty capped at 30 -> score 70
        expect(analyzer.analyze(class_info)).to eq(70)
      end
    end
  end
end
