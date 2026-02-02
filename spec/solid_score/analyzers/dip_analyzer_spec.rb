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
  end
end
