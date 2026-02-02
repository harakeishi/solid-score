# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Scorer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../fixtures", __dir__) }

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
