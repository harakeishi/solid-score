# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::DipAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
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

    # Phase 1 改善: 標準ライブラリホワイトリストのテスト
    context "with standard library classes" do
      it "does not penalize standard library instantiations" do
        classes = parser.parse_file("#{fixtures_path}/dip_standard_library.rb")
        data_processor = classes.find { |c| c.name == "DataProcessor" }
        score = analyzer.analyze(data_processor)

        # Standard library classes (Array, Hash, Time, Mutex) should not be penalized
        expect(score).to eq(100)
      end

      it "penalizes custom class instantiations" do
        classes = parser.parse_file("#{fixtures_path}/dip_standard_library.rb")
        order_processor = classes.find { |c| c.name == "OrderProcessor" }
        score = analyzer.analyze(order_processor)

        # Custom classes (OrderRepository, EmailNotifier, AuditLogger) should be penalized
        expect(score).to be < 100
      end

      it "correctly handles mixed standard and custom classes" do
        classes = parser.parse_file("#{fixtures_path}/dip_standard_library.rb")
        mixed_processor = classes.find { |c| c.name == "MixedProcessor" }
        score = analyzer.analyze(mixed_processor)

        # MixedProcessor has:
        # - 1 injected dependency (service:)
        # - Hash.new, Time.new are standard library (not counted)
        # - ProcessingHelper.new is custom (counted as 1)
        # concrete_deps = 1, injected_deps = 1, total = 2
        # concrete_ratio = 0.5, base_score = 50 + DI_BONUS(15) = 65
        expect(score).to be > 50
        expect(score).to be < 100
      end
    end

    context "with standard library whitelist" do
      it "recognizes common standard library classes" do
        whitelisted = %w[Array Hash Set Time Date Mutex Thread Logger]
        whitelisted.each do |klass|
          method_call = SolidScore::Models::MethodCallInfo.new(
            method_name: :new,
            receiver: klass,
            receiver_type: :const
          )
          method_info = SolidScore::Models::MethodInfo.new(
            name: :test,
            method_calls: [method_call]
          )
          class_info = SolidScore::Models::ClassInfo.new(
            name: "Test",
            methods: [method_info]
          )

          score = analyzer.analyze(class_info)
          expect(score).to eq(100), "Expected #{klass} to be whitelisted"
        end
      end

      it "does not whitelist custom classes" do
        custom_classes = %w[UserService OrderRepository CustomLogger]
        custom_classes.each do |klass|
          method_call = SolidScore::Models::MethodCallInfo.new(
            method_name: :new,
            receiver: klass,
            receiver_type: :const
          )
          method_info = SolidScore::Models::MethodInfo.new(
            name: :test,
            method_calls: [method_call]
          )
          class_info = SolidScore::Models::ClassInfo.new(
            name: "Test",
            methods: [method_info]
          )

          score = analyzer.analyze(class_info)
          expect(score).to be < 100, "Expected #{klass} to NOT be whitelisted"
        end
      end
    end
  end
end
