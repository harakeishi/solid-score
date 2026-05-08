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

    # Issue #7: linear public method scoring curve
    describe "#public_method_score (linear curve)" do
      let(:scoring) { analyzer.send(:public_method_score, count) }

      context "when count <= 5" do
        it "returns the ceiling" do
          (0..5).each do |n|
            expect(analyzer.send(:public_method_score, n)).to eq(100)
          end
        end
      end

      context "when count is between 6 and 24" do
        it "applies a -4pt slope per method" do
          expect(analyzer.send(:public_method_score, 6)).to eq(96)
          expect(analyzer.send(:public_method_score, 7)).to eq(92)
          expect(analyzer.send(:public_method_score, 10)).to eq(80)
          expect(analyzer.send(:public_method_score, 24)).to eq(24)
        end
      end

      context "when count >= 25" do
        it "floors at 20" do
          expect(analyzer.send(:public_method_score, 25)).to eq(20)
          expect(analyzer.send(:public_method_score, 50)).to eq(20)
          expect(analyzer.send(:public_method_score, 200)).to eq(20)
        end
      end

      it "does not exhibit a 20pt cliff when crossing 5 -> 6" do
        score5 = analyzer.send(:public_method_score, 5)
        score6 = analyzer.send(:public_method_score, 6)
        expect(score5 - score6).to eq(4)
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
