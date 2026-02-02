# frozen_string_literal: true

require "optparse"

module SolidScore
  class CLI
    def run(args)
      options = parse_options(args)
      return 0 if options[:exit]

      config = load_config(options)
      config.merge_cli_options(options)

      paths = args.reject { |a| a.start_with?("-") }
      config.paths = paths unless paths.empty?

      runner = Runner.new(config)
      runner.run

      puts runner.formatted_output

      runner.passing? ? 0 : 1
    end

    private

    def parse_options(args)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: solid-score [path] [options]"

        opts.on("--format FORMAT", %w[text json], "Output format (text|json)") do |f|
          options[:format] = f.to_sym
        end

        opts.on("--config FILE", "Config file path") do |f|
          options[:config] = f
        end

        opts.on("--min-score SCORE", Integer, "Minimum total score (CI)") do |s|
          options[:min_score] = s
        end

        %w[srp ocp lsp isp dip].each do |principle|
          opts.on("--min-#{principle} SCORE", Integer, "Minimum #{principle.upcase} score") do |s|
            options[:"min_#{principle}"] = s
          end
        end

        opts.on("--diff REF", "Diff base reference") do |r|
          options[:diff_ref] = r
        end

        opts.on("--max-decrease SCORE", Integer, "Max score decrease per class") do |s|
          options[:max_decrease] = s
        end

        opts.on("--exclude PATTERN", "Exclude patterns (comma-separated)") do |p|
          options[:exclude] = p
        end

        opts.on("--version", "Show version") do
          puts "solid-score v#{VERSION}"
          options[:exit] = true
        end

        opts.on("-h", "--help", "Show help") do
          puts opts
          options[:exit] = true
        end
      end

      parser.parse!(args)
      options
    end

    def load_config(options)
      config_path = options[:config] || ".solid-score.yml"
      Configuration.from_file(config_path)
    end
  end
end
