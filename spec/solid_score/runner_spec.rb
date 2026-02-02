# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Runner do
  let(:fixtures_path) { File.expand_path("../fixtures", __dir__) }

  describe "#run" do
    it "analyzes Ruby files in the given path and returns results" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.exclude = []

      runner = described_class.new(config)
      results = runner.run

      expect(results).to be_an(Array)
      expect(results).not_to be_empty
      expect(results.first).to be_a(SolidScore::Models::ScoreResult)
    end

    it "respects exclude patterns" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.exclude = ["**/bad_*.rb"]

      runner = described_class.new(config)
      results = runner.run

      bad_classes = results.select { |r| r.class_name.start_with?("God", "KitchenSink", "ShapeCalculator") }
      expect(bad_classes).to be_empty
    end
  end

  describe "#passing?" do
    it "returns true when all scores meet thresholds" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.thresholds[:total] = 0

      runner = described_class.new(config)
      runner.run

      expect(runner.passing?).to be true
    end

    it "returns false when scores are below threshold" do
      config = SolidScore::Configuration.default
      config.paths = [fixtures_path]
      config.thresholds[:total] = 100

      runner = described_class.new(config)
      runner.run

      expect(runner.passing?).to be false
    end
  end
end
