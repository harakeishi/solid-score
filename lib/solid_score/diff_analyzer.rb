# frozen_string_literal: true

module SolidScore
  class DiffAnalyzer
    attr_reader :base_ref

    def initialize(base_ref)
      @base_ref = base_ref
    end

    def changed_files
      git_diff_names.split("\n").select { |f| f.end_with?(".rb") }
    end

    def changed_line_ranges
      ranges = Hash.new { |h, k| h[k] = [] }
      current_file = nil

      git_diff_output.each_line do |line|
        if line.start_with?("+++ b/")
          current_file = line.sub("+++ b/", "").strip
        elsif line.match?(/^@@ .+ @@/) || line.match?(/^\s+@@ .+ @@/)
          match = line.match(/@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
          if match && current_file
            start_line = match[1].to_i
            count = (match[2] || "1").to_i
            ranges[current_file] << (start_line..(start_line + count - 1))
          end
        end
      end

      ranges
    end

    def filter_classes(classes, file_ranges)
      classes.select do |class_info|
        file_ranges.key?(class_info.file_path) &&
          file_ranges[class_info.file_path].any? do |range|
            ranges_overlap?(range, class_info.line_start..class_info.line_end)
          end
      end
    end

    private

    def ranges_overlap?(a, b)
      a.begin <= b.end && b.begin <= a.end
    end

    def git_diff_names
      `git diff --name-only #{base_ref}`.strip
    end

    def git_diff_output
      `git diff #{base_ref}`
    end
  end
end
