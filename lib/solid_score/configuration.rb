# frozen_string_literal: true

require "yaml"

module SolidScore
  class Configuration
    DEFAULT_WEIGHTS = {
      srp: 0.30,
      ocp: 0.15,
      lsp: 0.10,
      isp: 0.20,
      dip: 0.25
    }.freeze

    DEFAULT_THRESHOLDS = {
      total: 0,
      srp: 0,
      ocp: 0,
      lsp: 0,
      isp: 0,
      dip: 0
    }.freeze

    # Issue #14: extended tuning knobs
    DEFAULT_DIFF_THRESHOLDS = {
      ignore_below_delta: 0.0,
      flag_only_structural_below: 0.0
    }.freeze

    DEFAULT_SCORING_OPTIONS = {
      isp_public_method_curve: :linear,
      case_when_2way_lenient: true
    }.freeze

    attr_accessor :paths, :exclude, :format, :thresholds, :weights,
                  :diff_ref, :max_decrease, :new_class_min,
                  :dip_whitelist,
                  :inspection_class_patterns, :symmetric_method_pairs,
                  :diff_thresholds, :scoring_options

    def initialize
      @paths = ["."]
      @exclude = []
      @format = :text
      @thresholds = DEFAULT_THRESHOLDS.dup
      @weights = DEFAULT_WEIGHTS.dup
      @diff_ref = nil
      @max_decrease = nil
      @new_class_min = nil
      @dip_whitelist = []
      @inspection_class_patterns = []
      @symmetric_method_pairs = []
      @diff_thresholds = DEFAULT_DIFF_THRESHOLDS.dup
      @scoring_options = DEFAULT_SCORING_OPTIONS.dup
    end

    def self.default
      new
    end

    def self.from_file(path)
      config = new
      return config unless File.exist?(path)

      yaml = YAML.safe_load_file(path, symbolize_names: false) || {}
      config.apply_yaml(yaml)
      config
    end

    def apply_yaml(yaml)
      apply_preset(yaml["preset"]) if yaml["preset"]

      @paths = yaml["paths"] if yaml["paths"]
      @exclude = yaml["exclude"] if yaml["exclude"]
      @format = yaml["format"]&.to_sym if yaml["format"]

      yaml["thresholds"]&.each { |k, v| @thresholds[k.to_sym] = v }

      yaml["weights"]&.each { |k, v| @weights[k.to_sym] = v }

      if yaml["dip"]
        @dip_whitelist = yaml["dip"]["whitelist"] || []
      end

      apply_extended_keys(yaml)

      return unless yaml["diff"]

      @max_decrease = yaml["diff"]["max_decrease"]
      @new_class_min = yaml["diff"]["new_class_min"]
    end

    def merge_cli_options(options)
      @format = options[:format] if options[:format]
      @diff_ref = options[:diff_ref] if options[:diff_ref]
      @thresholds[:total] = options[:min_score] if options[:min_score]

      %i[srp ocp lsp isp dip].each do |principle|
        key = :"min_#{principle}"
        @thresholds[principle] = options[key] if options[key]
      end

      @max_decrease = options[:max_decrease] if options[:max_decrease]
      @exclude = options[:exclude].split(",") if options[:exclude]
    end

    private

    def apply_preset(name)
      preset = Presets.fetch(name)
      @paths = preset[:paths] if preset[:paths]
      @exclude = preset[:exclude] if preset[:exclude]
      preset[:weights]&.each { |k, v| @weights[k] = v }
      @dip_whitelist = preset[:dip_whitelist] if preset[:dip_whitelist]
    end

    # Issue #14: keys parsed by apply_extended_keys but not yet wired into
    # the analyzers. Setting any of them is currently a no-op; the runtime
    # emits a one-time warning so users know their config has no effect yet.
    UNWIRED_EXTENDED_KEYS = %w[
      inspection_classes
      symmetric_method_pairs
      diff_thresholds
      scoring
    ].freeze

    def apply_extended_keys(yaml)
      @inspection_class_patterns = Array(yaml["inspection_classes"]) if yaml["inspection_classes"]

      custom_pairs = yaml["symmetric_method_pairs"].is_a?(Hash) &&
                     yaml["symmetric_method_pairs"]["custom"]
      @symmetric_method_pairs = custom_pairs if custom_pairs

      diff_thresholds = yaml["diff_thresholds"]
      diff_thresholds.each { |k, v| @diff_thresholds[k.to_sym] = v } if diff_thresholds.is_a?(Hash)

      scoring = yaml["scoring"]
      scoring.each { |k, v| @scoring_options[k.to_sym] = normalize_scoring_value(v) } if scoring.is_a?(Hash)

      warn_unwired_keys(yaml)
    end

    def normalize_scoring_value(value)
      return value.downcase.to_sym if value.is_a?(String)

      value
    end

    def warn_unwired_keys(yaml)
      present = UNWIRED_EXTENDED_KEYS.select { |k| yaml.key?(k) }
      return if present.empty?

      Kernel.warn(
        "[solid_score] .solid-score.yml keys parsed but not yet wired " \
          "into the analyzers: #{present.join(", ")} (tracked as a follow-up)."
      )
    end
  end
end
