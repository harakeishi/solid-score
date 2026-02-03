# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Analyzes Dependency Inversion Principle compliance.
    #
    # Phase 1 改善:
    # - 標準ライブラリのホワイトリスト導入
    # - Array.new, Hash.new 等の標準ライブラリインスタンス化を除外
    class DipAnalyzer < BaseAnalyzer
      DI_BONUS = 15

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
          count_non_standard_new_calls(method)
        end
      end

      # Phase 1 改善: 標準ライブラリ以外の .new 呼び出しをカウント
      #
      # @param method [MethodInfo] メソッド情報
      # @return [Integer] 標準ライブラリ以外の .new 呼び出し数
      def count_non_standard_new_calls(method)
        # method_calls が空の場合は後方互換性のため called_methods を使用
        if method.method_calls.empty?
          # 後方互換性: 従来の方式でカウント
          return method.called_methods.count { |m| m == :new }
        end

        # Phase 1: MethodCallInfo を使用してレシーバを判定
        method.method_calls.count do |call|
          next false unless call.method_name == :new
          next false unless call.receiver_type == :const

          # 標準ライブラリでない場合のみカウント
          !standard_library_class?(call.receiver)
        end
      end

      # Phase 1 改善: 標準ライブラリかどうかを判定
      #
      # @param class_name [String, nil] クラス名
      # @return [Boolean] 標準ライブラリかどうか
      def standard_library_class?(class_name)
        return false if class_name.nil?

        # 完全一致またはネームスペース付きで一致
        STANDARD_LIBRARY_WHITELIST.any? do |lib_class|
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
