# frozen_string_literal: true

module SolidScore
  module Analyzers
    class OcpAnalyzer < BaseAnalyzer
      TYPE_CHECK_METHODS = %i[is_a? kind_of? instance_of?].freeze
      MAX_TYPE_CHECK_PENALTY = 40
      MAX_EXTENSION_BONUS = 20

      def analyze(class_info)
        return 100 if class_info.methods.empty?

        score = 100.0

        score -= conditional_density_penalty(class_info)
        score -= type_check_penalty(class_info)
        score += extension_point_bonus(class_info)

        clamp_score(score)
      end

      private

      def conditional_density_penalty(class_info)
        method_count = class_info.methods.size.to_f
        return 0 if method_count.zero?

        branch_count = class_info.methods.sum { |m| m.cyclomatic_complexity - 1 }
        density = branch_count / method_count

        if density > 1.0
          40
        elsif density > 0.5
          20
        else
          0
        end
      end

      def type_check_penalty(class_info)
        type_checks = class_info.methods.sum do |method|
          method.called_methods.count { |m| TYPE_CHECK_METHODS.include?(m) }
        end

        [type_checks * 10, MAX_TYPE_CHECK_PENALTY].min
      end

      def extension_point_bonus(class_info)
        extension_points = class_info.methods.count do |method|
          method.raises.include?("NotImplementedError")
        end

        has_block_params = class_info.methods.count do |method|
          method.parameters.any? { |type, _| type == :block }
        end

        [(extension_points + has_block_params) * 10, MAX_EXTENSION_BONUS].min
      end
    end
  end
end
