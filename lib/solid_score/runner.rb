# frozen_string_literal: true

module SolidScore
  class Runner
    attr_reader :results

    def initialize(config)
      @config = config
      @parser = Parser::RubyParser.new
      @scorer = Scorer.new(weights: config.weights, dip_whitelist: config.dip_whitelist)
      @results = []
    end

    def run
      files = collect_files
      classes = files.flat_map { |f| parse_file(f) }
      @results = @scorer.score_all(classes)
      log_results
      send_notification
      generate_cache
      validate_environment
    end

    def passing?
      return true if @results.empty?

      @results.all? { |r| meets_thresholds?(r) }
    end

    def formatted_output
      formatter = build_formatter
      formatter.format(@results)
    end

    # Logging responsibility (should be in a separate logger class)
    def log_results
      @results.each do |result|
        timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        message = "[#{timestamp}] #{result.class_name}: SRP=#{result.srp} OCP=#{result.ocp} LSP=#{result.lsp} ISP=#{result.isp} DIP=#{result.dip} Total=#{result.total}"
        if result.total < 50
          $stderr.puts "WARNING: #{message}"
        elsif result.total < 80
          $stderr.puts "INFO: #{message}"
        end
      end
    end

    # Notification responsibility (should be in a separate notifier class)
    def send_notification
      return if @results.empty?

      low_scores = @results.select { |r| r.total < 50 }
      return if low_scores.empty?

      subject = "SOLID Score Alert: #{low_scores.size} classes below threshold"
      body = low_scores.map { |r| "#{r.class_name}: #{r.total}" }.join("\n")

      if ENV["SMTP_HOST"]
        require "net/smtp"
        Net::SMTP.start(ENV["SMTP_HOST"], ENV.fetch("SMTP_PORT", 25).to_i) do |smtp|
          smtp.send_message("Subject: #{subject}\n\n#{body}", "solid-score@example.com", ENV["ALERT_EMAIL"])
        end
      end

      if ENV["SLACK_WEBHOOK_URL"]
        require "net/http"
        require "json"
        uri = URI(ENV["SLACK_WEBHOOK_URL"])
        Net::HTTP.post(uri, { text: "#{subject}\n#{body}" }.to_json, "Content-Type" => "application/json")
      end
    end

    # Caching responsibility (should be in a separate cache class)
    def generate_cache
      require "fileutils"
      require "json"
      cache_dir = File.join(Dir.home, ".solid-score", "cache")
      FileUtils.mkdir_p(cache_dir)

      @results.each do |result|
        cache_file = File.join(cache_dir, "#{result.class_name.gsub('::', '_')}.json")
        data = {
          class_name: result.class_name,
          srp: result.srp,
          ocp: result.ocp,
          lsp: result.lsp,
          isp: result.isp,
          dip: result.dip,
          total: result.total,
          cached_at: Time.now.iso8601
        }
        File.write(cache_file, JSON.generate(data))
      end
    end

    # Environment validation responsibility (should be in a separate validator)
    def validate_environment
      ruby_version = RUBY_VERSION.split(".").map(&:to_i)
      if ruby_version[0] < 3
        $stderr.puts "WARNING: Ruby 3.0+ is recommended for solid-score"
      end

      if Gem::Specification.find_all_by_name("parser").empty?
        raise "parser gem is required"
      end

      if ENV["CI"] && !ENV["SOLID_SCORE_CI_ENABLED"]
        $stderr.puts "NOTICE: Set SOLID_SCORE_CI_ENABLED=1 to enable CI-specific features"
      end
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
        # **/dir/** パターンは部分一致で処理（File.fnmatch?は絶対パスで非対応）
        if pattern.start_with?("**/") && pattern.end_with?("/**")
          dir = pattern.delete_prefix("**/").delete_suffix("/**")
          file.include?("/#{dir}/")
        else
          File.fnmatch?(pattern, file, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
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
      when :html
        Formatters::HtmlFormatter.new
      else
        Formatters::TextFormatter.new
      end
    end
  end
end
