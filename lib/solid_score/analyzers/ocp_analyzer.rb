# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Analyzes Open/Closed Principle compliance.
    #
    # Phase 1 改善: case/when 分岐へのペナルティ追加
    # Phase 2b 改善: respond_to? を弱い型チェックとして追加
    class OcpAnalyzer < BaseAnalyzer
      # 強い型チェック: 直接的な型判定 → 10点/回
      STRONG_TYPE_CHECK_METHODS = %i[is_a? kind_of? instance_of?].freeze
      # 弱い型チェック: ダックタイピング分岐 → 5点/回
      WEAK_TYPE_CHECK_METHODS = %i[respond_to?].freeze

      MAX_TYPE_CHECK_PENALTY = 40
      MAX_EXTENSION_BONUS = 20

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

      # Phase 2b: 強い型チェックと弱い型チェックで差別化
      def type_check_penalty(class_info)
        strong_checks = count_type_checks(class_info, STRONG_TYPE_CHECK_METHODS)
        weak_checks = count_type_checks(class_info, WEAK_TYPE_CHECK_METHODS)

        [strong_checks * 10 + weak_checks * 5, MAX_TYPE_CHECK_PENALTY].min
      end

      def count_type_checks(class_info, check_methods)
        class_info.methods.sum do |method|
          method.called_methods.count { |m| check_methods.include?(m) }
        end
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
