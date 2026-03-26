# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Shared helper for all SolidScore cops.
      # Parses the file once per cop run and caches scored results.
      module Helpers
        private

        def score_results_for(node)
          file_path = processed_source.file_path
          @solid_score_results ||= compute_scores(file_path)
        end

        def compute_scores(file_path)
          parser = ::SolidScore::Parser::RubyParser.new
          scorer = ::SolidScore::Scorer.new(
            weights: cop_config_weights,
            dip_whitelist: cop_config_dip_whitelist
          )

          class_infos = parser.parse_file(file_path)
          scorer.score_all(class_infos)
        rescue ::Parser::SyntaxError
          []
        end

        def cop_config_weights
          weights = ::SolidScore::Models::ScoreResult::DEFAULT_WEIGHTS.dup
          config_weights = cop_config["Weights"]
          return weights unless config_weights

          config_weights.each { |k, v| weights[k.to_sym] = v.to_f }
          weights
        end

        def cop_config_dip_whitelist
          cop_config["DipWhitelist"] || []
        end

        def score_threshold
          cop_config["MinScore"]&.to_f || 70.0
        end

        def find_class_node_for(result)
          find_node_at_line(processed_source.ast, result.file_path, result.class_info&.line_start)
        end

        def find_node_at_line(ast, _file_path, target_line)
          return nil unless ast && target_line

          if %i[class module].include?(ast.type) && ast.loc.keyword.line == target_line
            return ast
          end

          return nil unless ast.respond_to?(:children)

          ast.children.each do |child|
            next unless child.is_a?(::RuboCop::AST::Node)

            found = find_node_at_line(child, _file_path, target_line)
            return found if found
          end

          nil
        end
      end
    end
  end
end
