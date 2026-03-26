# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::IspAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
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

    # Phase 2a: フレームワークConcernの緩和
    context "with framework module includes" do
      it "applies reduced penalty for framework modules" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "AuditableRecord",
          includes: %w[Comparable ActiveModel::Validations ActiveModel::Dirty ActiveSupport::Callbacks],
          methods: [
            SolidScore::Models::MethodInfo.new(name: :audit, visibility: :public, line_start: 1, line_end: 3)
          ]
        )
        score_with_framework = analyzer.analyze(class_info)

        class_info_custom = SolidScore::Models::ClassInfo.new(
          name: "CustomRecord",
          includes: %w[MyModule1 MyModule2 MyModule3 MyModule4],
          methods: [
            SolidScore::Models::MethodInfo.new(name: :audit, visibility: :public, line_start: 1, line_end: 3)
          ]
        )
        score_with_custom = analyzer.analyze(class_info_custom)

        # Framework includes should result in higher score than custom includes
        expect(score_with_framework).to be > score_with_custom
      end
    end
  end
end
