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

    attr_accessor :paths, :exclude, :format, :thresholds, :weights,
                  :diff_ref, :max_decrease, :new_class_min

    def initialize
      @paths = ["."]
      @exclude = []
      @format = :text
      @thresholds = DEFAULT_THRESHOLDS.dup
      @weights = DEFAULT_WEIGHTS.dup
      @diff_ref = nil
      @max_decrease = nil
      @new_class_min = nil
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
      @paths = yaml["paths"] if yaml["paths"]
      @exclude = yaml["exclude"] if yaml["exclude"]
      @format = yaml["format"]&.to_sym if yaml["format"]

      yaml["thresholds"]&.each { |k, v| @thresholds[k.to_sym] = v }

      yaml["weights"]&.each { |k, v| @weights[k.to_sym] = v }

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
  end
end
