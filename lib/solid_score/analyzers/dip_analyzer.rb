# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Analyzes Dependency Inversion Principle compliance.
    #
    # Phase 1 改善: 標準ライブラリのホワイトリスト導入
    # Phase 2b 改善: ファクトリメソッド検出、ユーザー定義ホワイトリスト
    class DipAnalyzer < BaseAnalyzer
      DI_BONUS = 15

      # Phase 2b: .new 以外のファクトリメソッドも具象依存として検出
      FACTORY_METHODS = %i[new create build call open].freeze

      # Ruby標準ライブラリおよびコアクラスのホワイトリスト
      # これらのクラスの .new 呼び出しは具象依存としてカウントしない
      STANDARD_LIBRARY_WHITELIST = %w[
        Array Hash Set SortedSet
        Thread Mutex Monitor ConditionVariable Queue SizedQueue
        Time Date DateTime
        BigDecimal Rational Complex
        String StringIO Regexp
        File Dir IO Tempfile
        Struct OpenStruct
        StandardError RuntimeError ArgumentError TypeError
        Range Enumerator Proc Method
        Logger
        URI
        JSON
        CSV
        Socket
        Net::HTTP
      ].freeze

      def initialize(user_whitelist: [])
        @user_whitelist = user_whitelist
      end

      def analyze(class_info)
        concrete_deps = count_concrete_instantiations(class_info)
        injected_deps = count_injected_dependencies(class_info)
        total_deps = concrete_deps + injected_deps

        return 100 if total_deps.zero?

        concrete_ratio = concrete_deps.to_f / total_deps
        score = 100 - (concrete_ratio * 100)

        score += DI_BONUS if injected_deps.positive?
        score -= ce_penalty(class_info)

        clamp_score(score)
      end

      private

      # Phase 1 改善: 標準ライブラリを除外した具象依存カウント
      #
      # method_calls (MethodCallInfo) を使用してレシーバ情報を取得し、
      # 標準ライブラリのインスタンス化を除外します。
      #
      # @param class_info [ClassInfo] クラス情報
      # @return [Integer] 具象依存の数
      def count_concrete_instantiations(class_info)
        class_info.methods.sum do |method|
          count_concrete_deps_in_method(method)
        end
      end

      # Phase 2b: ファクトリメソッドも含めて具象依存をカウント
      def count_concrete_deps_in_method(method)
        method.method_calls.count do |call|
          next false unless FACTORY_METHODS.include?(call.method_name)
          next false unless call.receiver_type == :const

          !whitelisted_class?(call.receiver)
        end
      end

      # 標準ライブラリまたはユーザー定義ホワイトリストに含まれるかを判定
      def whitelisted_class?(class_name)
        return false if class_name.nil?

        all_whitelist = STANDARD_LIBRARY_WHITELIST + @user_whitelist
        all_whitelist.any? do |lib_class|
          class_name == lib_class || class_name.end_with?("::#{lib_class}")
        end
      end

      def count_injected_dependencies(class_info)
        init = class_info.methods.find { |m| m.name == :initialize }
        return 0 unless init

        # Parser gem returns:
        # :kwarg = required keyword argument (def foo(bar:))
        # :kwoptarg = optional keyword argument (def foo(bar: default))
        # :kwrestarg = keyword rest argument (def foo(**kwargs))
        # Also check :key and :keyreq for backward compatibility
        init.parameters.count { |type, _| %i[key keyreq kwarg kwoptarg kwrestarg].include?(type) }
      end

      def ce_penalty(class_info)
        ce = count_concrete_instantiations(class_info)

        if ce > 20
          20
        elsif ce > 10
          10
        else
          0
        end
      end
    end
  end
end
