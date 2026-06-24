# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Analyzes Dependency Inversion Principle compliance.
    #
    # Phase 1 改善: 標準ライブラリのホワイトリスト導入
    # Phase 2b 改善: ファクトリメソッド検出、ユーザー定義ホワイトリスト
    class DipAnalyzer < BaseAnalyzer
      DI_BONUS = 15

      # 具象依存1件あたりのペナルティと、その上限。
      #
      # 旧実装は concrete / (concrete + injected) の「比率」でスコアを決めて
      # いたため、注入依存が0件のクラスは比率が必ず 1.0 になり、具象依存が
      # 1件でも10件でも一律0点に潰れていた（著名OSSの13%が0点・中間スコア
      # ほぼ消滅という二極化が実測された）。
      #
      # DIPで本来効くのは「いくつの具象クラスに直接結合しているか」という
      # 絶対数なので、依存件数に比例した逓減ペナルティへ変更する。
      # 1件=12pt … 5件以上で上限60ptに到達し、件数が増えるほど低スコアに
      # なるが、1〜2件程度の素朴な `Foo.new` は中〜高スコアに留まる。
      CONCRETE_DEP_PENALTY_PER = 12
      MAX_CONCRETE_DEP_PENALTY = 60

      # Issue #12: memoized factory bonus
      MEMOIZED_FACTORY_BONUS_PER = 5
      MEMOIZED_FACTORY_BONUS_MAX = 15

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

      # 具象依存が1件でも残るクラスは、DIボーナス等を加点しても満点には
      # 到達させない上限。100点は「具象依存ゼロの真にクリーンなクラス」に
      # 限定し、DI採用は加点しつつも「具象結合が残る＝DIPは完璧ではない」
      # を表現する（具象1件 + 注入1件のような構成が100点に潰れるのを防ぐ）。
      MAX_SCORE_WITH_CONCRETE_DEP = 95

      # Phase 2c: レイヤー別のDIPペナルティ重み
      # Controller/Model ではDIP違反の影響度を軽減
      # (Railsの標準パターンである Service.new.call, OtherModel.create を許容)
      LAYER_DIP_WEIGHT = {
        controller: 0.4,  # Service.new.call は標準パターン
        model: 0.5,       # OtherModel.create は標準パターン
        service: 1.0,     # DIが推奨される層
        job: 0.6,         # Service呼び出しは許容
        mailer: 0.5,      # Model参照は許容
        lib: 1.0,         # DIが推奨される層
        unknown: 1.0
      }.freeze

      def analyze(class_info)
        concrete_deps = count_concrete_instantiations(class_info)
        injected_deps = count_injected_dependencies(class_info)
        total_deps = concrete_deps + injected_deps
        bonus = memoized_factory_bonus(class_info)

        if total_deps.zero?
          return clamp_score(100 + bonus)
        end

        # Phase 2c: レイヤー別にペナルティの重みを調整
        weight = layer_weight(class_info)

        # 具象依存の「絶対数」に応じた逓減ペナルティ（比率ベースを廃止）。
        # これにより具象1件のクラスが0点に潰れず、多依存クラスとの差が出る。
        score = 100 - (concrete_dep_penalty(concrete_deps) * weight)

        score += DI_BONUS if injected_deps.positive?
        score += bonus

        # 具象依存が残る限り、加点しても満点には届かせない。
        score = [score, MAX_SCORE_WITH_CONCRETE_DEP].min if concrete_deps.positive?

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

      # Issue #12: Reward `@svc ||= ServiceClass.new(...)` style memoised
      # factories, but skip standard-library / user-whitelisted classes so
      # `@queue ||= Queue.new` doesn't earn a DI-style bonus.
      def memoized_factory_bonus(class_info)
        count = class_info.methods.count do |m|
          next false unless m.memoized_factory? && m.cyclomatic_complexity == 1
          next false if m.memoized_factory_receiver.nil?

          !whitelisted_class?(m.memoized_factory_receiver)
        end
        [count * MEMOIZED_FACTORY_BONUS_PER, MEMOIZED_FACTORY_BONUS_MAX].min
      end

      # 具象依存の件数に比例した逓減ペナルティ（上限あり）。
      # 0件=0, 1件=12, 2件=24 ... 5件以上は60で頭打ち。
      def concrete_dep_penalty(concrete_deps)
        [concrete_deps * CONCRETE_DEP_PENALTY_PER, MAX_CONCRETE_DEP_PENALTY].min
      end

      def layer_weight(class_info)
        LAYER_DIP_WEIGHT.fetch(class_info.layer, 1.0)
      end
    end
  end
end
