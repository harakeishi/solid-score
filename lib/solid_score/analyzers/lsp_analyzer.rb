# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Analyzes Liskov Substitution Principle compliance.
    #
    # Phase 1 改善:
    # - simple_implementation? による単純実装の検出（ペナルティ免除）
    # - abstract_parent_pattern? による抽象親パターンの検出（ペナルティ免除）
    # - それ以外のケースではペナルティを半減（10点→5点）
    class LspAnalyzer < BaseAnalyzer
      SIGNATURE_CHANGE_PENALTY = 20
      EXTRA_RAISE_PENALTY = 15
      NO_SUPER_PENALTY = 10
      NO_SUPER_PENALTY_REDUCED = 5

      # Maximum lines for a method to be considered "simple"
      SIMPLE_IMPLEMENTATION_MAX_LINES = 3

      def analyze(class_info)
        return 100 unless class_info.has_superclass?

        score = 100.0

        class_info.methods.each do |method|
          next if method.name == :initialize

          score -= extra_raise_penalty(method)
          score -= no_super_penalty(method, class_info)
        end

        clamp_score(score)
      end

      private

      def extra_raise_penalty(method)
        standard_raises = ["NotImplementedError"]
        extra_raises = method.raises.reject { |r| standard_raises.include?(r) }

        extra_raises.any? ? EXTRA_RAISE_PENALTY : 0
      end

      # Calculates penalty for methods that don't call super.
      #
      # Phase 1 改善: 以下の条件でペナルティを緩和
      # 1. 単純な実装（cyclomatic_complexity == 1 かつ 行数 <= 3）→ ペナルティなし
      # 2. 抽象親パターン（親クラスがNotImplementedErrorをraiseする）→ ペナルティなし
      # 3. それ以外 → ペナルティ半減（5点）
      #
      # @param method [MethodInfo] 評価対象のメソッド
      # @param class_info [ClassInfo] クラス情報（親クラス判定用）
      # @return [Integer] ペナルティポイント
      def no_super_penalty(method, class_info)
        return 0 if method.calls_super

        # Case 1: Simple implementation (likely a complete override or hook)
        return 0 if simple_implementation?(method)

        # Case 2: Abstract parent pattern (Template Method, etc.)
        return 0 if abstract_parent_pattern?(class_info)

        # Case 3: Reduce penalty for other cases
        NO_SUPER_PENALTY_REDUCED
      end

      # Checks if the method is a simple implementation.
      #
      # A simple implementation is defined as:
      # - cyclomatic_complexity == 1 (no branching)
      # - method body is 3 lines or less
      #
      # This pattern often indicates:
      # - Complete override of parent behavior
      # - Hook method implementation
      # - Simple value return
      #
      # @param method [MethodInfo] 評価対象のメソッド
      # @return [Boolean] 単純な実装かどうか
      def simple_implementation?(method)
        method.cyclomatic_complexity == 1 &&
          method_line_count(method) <= SIMPLE_IMPLEMENTATION_MAX_LINES
      end

      # Checks if the class has an abstract parent pattern.
      #
      # Abstract parent pattern is detected when the parent class
      # has methods that raise NotImplementedError (Template Method pattern).
      #
      # Note: In Phase 1, this only works within the same file analysis.
      # Cross-file analysis requires runtime information (Phase 3).
      #
      # @param class_info [ClassInfo] クラス情報
      # @return [Boolean] 抽象親パターンかどうか
      def abstract_parent_pattern?(class_info)
        # Phase 1: Basic implementation
        # 同一ファイル内での親クラス解析は現状のパーサーでは難しいため、
        # 親クラス名に "Base" や "Abstract" が含まれる場合にヒューリスティックで判定
        return false unless class_info.superclass

        superclass_name = class_info.superclass.to_s
        superclass_name.include?("Base") || superclass_name.include?("Abstract")
      end

      # Calculates the number of lines in a method body.
      #
      # @param method [MethodInfo] 評価対象のメソッド
      # @return [Integer] メソッドの行数
      def method_line_count(method)
        method.line_end - method.line_start
      end
    end
  end
end
