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

  describe "preset support" do
    it "applies Rails preset values" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          preset: rails
        YAML

        config = described_class.from_file(config_path)

        expect(config.paths).to include("app/models", "app/controllers")
        expect(config.exclude).to include("spec/**", "vendor/**")
        expect(config.weights[:dip]).to eq(0.30)
        expect(config.dip_whitelist).to include("Rails", "Logger")
      end
    end

    it "allows explicit YAML to override preset" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          preset: rails
          paths:
            - app/models
          weights:
            srp: 0.50
        YAML

        config = described_class.from_file(config_path)

        expect(config.paths).to eq(["app/models"])
        expect(config.weights[:srp]).to eq(0.50)
      end
    end
  end

  # Issue #14: extended tuning knobs
  describe "extended configuration keys" do
    it "loads inspection_classes" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          inspection_classes:
            - "*::Inspect"
            - "Foo::DebugTools"
        YAML
        config = described_class.from_file(config_path)
        expect(config.inspection_class_patterns).to eq(["*::Inspect", "Foo::DebugTools"])
      end
    end

    it "loads custom symmetric_method_pairs" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          symmetric_method_pairs:
            custom:
              - [acquire, release]
              - [check_in, check_out]
        YAML
        config = described_class.from_file(config_path)
        expect(config.symmetric_method_pairs).to eq([%w[acquire release], %w[check_in check_out]])
      end
    end

    it "loads diff_thresholds" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          diff_thresholds:
            ignore_below_delta: 3.0
            flag_only_structural_below: 2.0
        YAML
        config = described_class.from_file(config_path)
        expect(config.diff_thresholds[:ignore_below_delta]).to eq(3.0)
        expect(config.diff_thresholds[:flag_only_structural_below]).to eq(2.0)
      end
    end

    it "loads scoring options" do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, ".solid-score.yml")
        File.write(config_path, <<~YAML)
          scoring:
            isp_public_method_curve: linear
            case_when_2way_lenient: true
        YAML
        config = described_class.from_file(config_path)
        expect(config.scoring_options[:isp_public_method_curve]).to eq(:linear)
        expect(config.scoring_options[:case_when_2way_lenient]).to be true
      end
    end

    it "uses sensible defaults when keys are absent" do
      config = described_class.default
      expect(config.inspection_class_patterns).to eq([])
      expect(config.symmetric_method_pairs).to eq([])
      expect(config.diff_thresholds).to eq(
        ignore_below_delta: 0.0,
        flag_only_structural_below: 0.0
      )
      expect(config.scoring_options).to eq(
        isp_public_method_curve: :linear,
        case_when_2way_lenient: true
      )
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
