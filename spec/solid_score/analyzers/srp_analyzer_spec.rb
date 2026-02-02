# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::SrpAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
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
