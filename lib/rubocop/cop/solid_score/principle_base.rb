# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Abstract base for per-principle cops.
      # Subclasses must define `principle_key` (e.g. :srp) and `principle_name` (e.g. "SRP").
      class PrincipleBase < Base
        include Helpers

        def on_class(node)
          check_principle(node)
        end

        def on_module(node)
          check_principle(node)
        end

        private

        def check_principle(node)
          results = score_results_for(node)
          results.each do |result|
            target_node = find_class_node_for(result) || node
            next unless same_node?(target_node, node)

            score = result.send(principle_key)
            threshold = score_threshold
            next unless score < threshold

            add_offense(node, message: format(
              "%s score %.1f is below minimum %g",
              principle_name, score, threshold
            ))
          end
        end

        def same_node?(target, current)
          target.loc.keyword.line == current.loc.keyword.line
        end

        def principle_key
          raise NotImplementedError
        end

        def principle_name
          raise NotImplementedError
        end
      end
    end
  end
end
