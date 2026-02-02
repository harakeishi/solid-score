# frozen_string_literal: true

module SolidScore
  class Runner
    attr_reader :results

    def initialize(config)
      @config = config
      @parser = Parser::RubyParser.new
      @scorer = Scorer.new(weights: config.weights)
      @results = []
    end

    def run
      files = collect_files
      classes = files.flat_map { |f| parse_file(f) }
      @results = @scorer.score_all(classes)
    end

    def passing?
      return true if @results.empty?

      @results.all? { |r| meets_thresholds?(r) }
    end

    def formatted_output
      formatter = build_formatter
      formatter.format(@results)
    end

    private

    def collect_files
      files = @config.paths.flat_map do |path|
        if File.file?(path)
          [path]
        else
          Dir.glob(File.join(path, "**", "*.rb"))
        end
      end

      files.reject { |f| excluded?(f) }
    end

    def excluded?(file)
      @config.exclude.any? do |pattern|
        File.fnmatch?(pattern, file, File::FNM_PATHNAME | File::FNM_DOTMATCH)
      end
    end

    def parse_file(file)
      @parser.parse_file(file)
    rescue ::Parser::SyntaxError
      []
    end

    def meets_thresholds?(result)
      return false if result.total < @config.thresholds[:total]

      %i[srp ocp lsp isp dip].all? do |principle|
        result.send(principle) >= @config.thresholds[principle]
      end
    end

    def build_formatter
      case @config.format
      when :json
        Formatters::JsonFormatter.new
      else
        Formatters::TextFormatter.new
      end
    end
  end
end
