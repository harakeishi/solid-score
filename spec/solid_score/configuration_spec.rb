# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "tmpdir"

RSpec.describe SolidScore::Configuration do
  describe ".default" do
    it "returns default configuration" do
      config = described_class.default

      expect(config.paths).to eq(["."])
      expect(config.exclude).to eq([])
      expect(config.format).to eq(:text)
      expect(config.thresholds[:total]).to eq(0)
      expect(config.weights[:srp]).to eq(0.30)
    end
  end

  describe ".from_file" do
    it "loads configuration from YAML file" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          paths:
            - app/
            - lib/
          exclude:
            - "spec/**/*"
          thresholds:
            total: 70
          weights:
            srp: 0.40
          format: json
        YAML

        config = described_class.from_file(config_path)

        expect(config.paths).to eq(["app/", "lib/"])
        expect(config.exclude).to eq(["spec/**/*"])
        expect(config.thresholds[:total]).to eq(70)
        expect(config.weights[:srp]).to eq(0.40)
        expect(config.format).to eq(:json)
      end
    end

    it "returns default when file does not exist" do
      config = described_class.from_file("/nonexistent/.solid-score.yml")

      expect(config.paths).to eq(["."])
    end
  end

  describe "#merge_cli_options" do
    it "overrides config with CLI options" do
      config = described_class.default
      config.merge_cli_options(format: :json, min_score: 80)

      expect(config.format).to eq(:json)
      expect(config.thresholds[:total]).to eq(80)
    end
  end
end
