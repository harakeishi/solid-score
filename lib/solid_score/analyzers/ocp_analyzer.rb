# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Analyzes Open/Closed Principle compliance.
    #
    # Phase 1 改善:
    # - case/when 分岐へのペナルティ追加
    # - case/when分岐はOCP違反の強い兆候として追加ペナルティを与える
    class OcpAnalyzer < BaseAnalyzer
      TYPE_CHECK_METHODS = %i[is_a? kind_of? instance_of?].freeze
      MAX_TYPE_CHECK_PENALTY = 40
      MAX_EXTENSION_BONUS = 20

      # Phase 1 改善: case/when ペナルティ設定
      CASE_WHEN_PENALTY_PER_BRANCH = 5
      MAX_CASE_WHEN_PENALTY = 30

      def analyze(class_info)
        return 100 if class_info.methods.empty?

        score = 100.0

        score -= conditional_density_penalty(class_info)
        score -= type_check_penalty(class_info)
        score -= case_when_penalty(class_info) # Phase 1 改善
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

      # Phase 1 改善: case/when 分岐へのペナルティ
      #
      # case/when分岐はOCP違反の強い兆候です。
      # 新しい型やケースを追加するたびにコードの修正が必要になるため、
      # ポリモーフィズムへのリファクタリングを推奨します。
      #
      # @param class_info [ClassInfo] クラス情報
      # @return [Integer] ペナルティポイント
      def case_when_penalty(class_info)
        total_case_when_branches = class_info.methods.sum(&:case_when_count)

        [total_case_when_branches * CASE_WHEN_PENALTY_PER_BRANCH, MAX_CASE_WHEN_PENALTY].min
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
