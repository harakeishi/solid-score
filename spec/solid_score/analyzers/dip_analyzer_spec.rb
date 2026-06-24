# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SolidScore::Analyzers::DipAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with dependency injection (good DIP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_dip.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with hardcoded dependencies (bad DIP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_dip.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be <= 50
      end
    end

    context "with no dependencies" do
      it "returns 100" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Pure",
          methods: [SolidScore::Models::MethodInfo.new(name: :compute)]
        )
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end

    # 絶対数ベースの逓減スコアリング（比率ベース廃止）の境界値を eq で固定する。
    # 緩い区間ではなく具体値を固定することで、CONCRETE_DEP_PENALTY_PER /
    # MAX_CONCRETE_DEP_PENALTY / MAX_SCORE_WITH_CONCRETE_DEP の変更を回帰
    # として検出できるようにする。
    context "concrete-dependency penalty curve (regression guard)" do
      def class_with_concrete_deps(count, injected: 0)
        calls = (1..count).map do |i|
          SolidScore::Models::MethodCallInfo.new(
            method_name: :new, receiver: "Service#{i}", receiver_type: :const
          )
        end
        methods = [SolidScore::Models::MethodInfo.new(name: :run, method_calls: calls)]
        if injected.positive?
          params = (1..injected).map { |i| [:kwarg, :"dep#{i}"] }
          methods.unshift(
            SolidScore::Models::MethodInfo.new(name: :initialize, parameters: params)
          )
        end
        SolidScore::Models::ClassInfo.new(name: "Demo", methods: methods)
      end

      it "scores 1 concrete dependency at 88" do
        expect(analyzer.analyze(class_with_concrete_deps(1))).to eq(88)
      end

      it "scores 2 concrete dependencies at 76" do
        expect(analyzer.analyze(class_with_concrete_deps(2))).to eq(76)
      end

      it "scores 3 concrete dependencies at 64" do
        expect(analyzer.analyze(class_with_concrete_deps(3))).to eq(64)
      end

      it "caps the penalty so 5 dependencies score 40" do
        expect(analyzer.analyze(class_with_concrete_deps(5))).to eq(40)
      end

      it "keeps the floor flat once the penalty is capped (6 deps also 40)" do
        expect(analyzer.analyze(class_with_concrete_deps(6))).to eq(40)
      end

      # 最重要: 具象依存が残るクラスは DI ボーナスを加点しても満点に届かない。
      it "caps the score at 95 when a concrete dep remains despite injection" do
        expect(analyzer.analyze(class_with_concrete_deps(1, injected: 1))).to eq(95)
      end
    end

    # Phase 1 改善: 標準ライブラリホワイトリストのテスト
    context "with standard library classes" do
      it "does not penalize standard library instantiations" do
        classes = parser.parse_file("#{fixtures_path}/dip_standard_library.rb")
        data_processor = classes.find { |c| c.name == "DataProcessor" }
        score = analyzer.analyze(data_processor)

        # Standard library classes (Array, Hash, Time, Mutex) should not be penalized
        expect(score).to eq(100)
      end

      it "penalizes custom class instantiations" do
        classes = parser.parse_file("#{fixtures_path}/dip_standard_library.rb")
        order_processor = classes.find { |c| c.name == "OrderProcessor" }
        score = analyzer.analyze(order_processor)

        # Custom classes (OrderRepository, EmailNotifier, AuditLogger) should be penalized
        expect(score).to be < 100
      end

      it "correctly handles mixed standard and custom classes" do
        classes = parser.parse_file("#{fixtures_path}/dip_standard_library.rb")
        mixed_processor = classes.find { |c| c.name == "MixedProcessor" }
        score = analyzer.analyze(mixed_processor)

        # MixedProcessor has:
        # - 1 injected dependency (service:)        → DI_BONUS(15)
        # - Hash.new, Time.new are standard library → not counted
        # - ProcessingHelper.new is custom          → 1 concrete dep (-12)
        # 100 - 12 + 15 = 103 だが、具象依存が残るため MAX_SCORE_WITH_CONCRETE_DEP(95)
        # でキャップされる。DI を使っても具象結合が残る限り満点にはしない。
        expect(score).to eq(95)
      end
    end

    # Phase 2b: ファクトリメソッド検出
    context "with factory methods" do
      it "detects ClassName.create as concrete dependency" do
        classes = parser.parse_file("#{fixtures_path}/factory_method_example.rb")
        score = analyzer.analyze(classes.first)

        # Order.create, Receipt.build, NotificationService.call = 3 concrete deps
        # File.open は標準ライブラリなのでカウントしない
        expect(score).to be < 100
      end

      it "does not count standard library factory methods" do
        method_call = SolidScore::Models::MethodCallInfo.new(
          method_name: :open,
          receiver: "File",
          receiver_type: :const
        )
        method_info = SolidScore::Models::MethodInfo.new(
          name: :test,
          method_calls: [method_call]
        )
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Test",
          methods: [method_info]
        )

        score = analyzer.analyze(class_info)
        expect(score).to eq(100)
      end
    end

    # Phase 2b: ユーザー定義ホワイトリスト
    context "with user-defined whitelist" do
      it "excludes user-whitelisted classes from penalty" do
        custom_analyzer = described_class.new(user_whitelist: ["Redis"])

        method_call = SolidScore::Models::MethodCallInfo.new(
          method_name: :new,
          receiver: "Redis",
          receiver_type: :const
        )
        method_info = SolidScore::Models::MethodInfo.new(
          name: :test,
          method_calls: [method_call]
        )
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Test",
          methods: [method_info]
        )

        score = custom_analyzer.analyze(class_info)
        expect(score).to eq(100)
      end

      it "still penalizes non-whitelisted classes" do
        custom_analyzer = described_class.new(user_whitelist: ["Redis"])

        method_call = SolidScore::Models::MethodCallInfo.new(
          method_name: :new,
          receiver: "CustomService",
          receiver_type: :const
        )
        method_info = SolidScore::Models::MethodInfo.new(
          name: :test,
          method_calls: [method_call]
        )
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Test",
          methods: [method_info]
        )

        score = custom_analyzer.analyze(class_info)
        expect(score).to be < 100
      end
    end

    # Issue #12: memoized factory bonus
    context "with memoized factory pattern" do
      it "rewards @service ||= ServiceClass.new patterns" do
        classes = parser.parse_file("#{fixtures_path}/memoized_factory.rb")
        controller = classes.first

        # Controller has 2 memoized factories with cyclomatic_complexity 1
        # → 2 * 5pt = 10pt bonus
        # Without bonus the controller would be penalised for the
        # ProvisioningService.new / CustomerRepository.new concrete deps.
        bonus = analyzer.send(:memoized_factory_bonus, controller)
        expect(bonus).to eq(10)
      end

      it "caps the bonus at 15pt" do
        methods = (1..5).map do |i|
          SolidScore::Models::MethodInfo.new(
            name: :"service_#{i}", visibility: :private,
            cyclomatic_complexity: 1, memoized_factory: true
          )
        end
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: methods)
        expect(analyzer.send(:memoized_factory_bonus, class_info)).to eq(15)
      end

      it "ignores non-memoized methods" do
        method = SolidScore::Models::MethodInfo.new(
          name: :ordinary, cyclomatic_complexity: 1, memoized_factory: false
        )
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        expect(analyzer.send(:memoized_factory_bonus, class_info)).to eq(0)
      end

      it "ignores memoized methods with cyclomatic complexity > 1" do
        method = SolidScore::Models::MethodInfo.new(
          name: :complex, cyclomatic_complexity: 3, memoized_factory: true
        )
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        expect(analyzer.send(:memoized_factory_bonus, class_info)).to eq(0)
      end

      # Issue #12 follow-up: stdlib classes must not earn a DI-style bonus.
      it "does not reward standard-library factories" do
        method = SolidScore::Models::MethodInfo.new(
          name: :queue, cyclomatic_complexity: 1,
          memoized_factory_receiver: "Queue"
        )
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        expect(analyzer.send(:memoized_factory_bonus, class_info)).to eq(0)
      end

      it "does not reward namespaced standard-library factories" do
        method = SolidScore::Models::MethodInfo.new(
          name: :http, cyclomatic_complexity: 1,
          memoized_factory_receiver: "Net::HTTP"
        )
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        expect(analyzer.send(:memoized_factory_bonus, class_info)).to eq(0)
      end

      it "respects user_whitelist for memoized factories" do
        custom_analyzer = described_class.new(user_whitelist: ["Redis"])
        method = SolidScore::Models::MethodInfo.new(
          name: :redis, cyclomatic_complexity: 1,
          memoized_factory_receiver: "Redis"
        )
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        expect(custom_analyzer.send(:memoized_factory_bonus, class_info)).to eq(0)
      end

      it "rewards namespaced custom service factories" do
        method = SolidScore::Models::MethodInfo.new(
          name: :svc, cyclomatic_complexity: 1,
          memoized_factory_receiver: "Foo::Bar"
        )
        class_info = SolidScore::Models::ClassInfo.new(name: "Demo", methods: [method])
        expect(analyzer.send(:memoized_factory_bonus, class_info)).to eq(5)
      end
    end

    # Issue #12 follow-up: parser-level coverage for the broader factory set.
    context "memoized factory parser detection" do
      def parse_method(source)
        Dir.mktmpdir do |dir|
          path = File.join(dir, "tmp.rb")
          File.write(path, source)
          parser.parse_file(path).first.methods.first
        end
      end

      it "detects @x ||= Foo.create style factories" do
        m = parse_method(<<~RUBY)
          class Demo
            def factory
              @x ||= Order.create(params)
            end
          end
        RUBY
        expect(m.memoized_factory?).to be true
        expect(m.memoized_factory_receiver).to eq("Order")
      end

      it "detects @x ||= Foo::Bar.new style factories" do
        m = parse_method(<<~RUBY)
          class Demo
            def factory
              @x ||= Foo::Bar.new
            end
          end
        RUBY
        expect(m.memoized_factory?).to be true
        expect(m.memoized_factory_receiver).to eq("Foo::Bar")
      end

      it "ignores non-factory method names like update" do
        m = parse_method(<<~RUBY)
          class Demo
            def factory
              @x ||= Order.update(params)
            end
          end
        RUBY
        expect(m.memoized_factory?).to be false
      end
    end

    # Phase 2c: レイヤー別ペナルティ
    context "with layer-specific evaluation" do
      it "applies reduced penalty for controller layer" do
        method_call = SolidScore::Models::MethodCallInfo.new(
          method_name: :new, receiver: "UserService", receiver_type: :const
        )
        method_info = SolidScore::Models::MethodInfo.new(
          name: :create, method_calls: [method_call]
        )

        # Controller（file_path判別）
        ctrl_class = SolidScore::Models::ClassInfo.new(
          name: "UsersController",
          file_path: "app/controllers/users_controller.rb",
          methods: [method_info]
        )

        # Service（file_path判別）
        svc_class = SolidScore::Models::ClassInfo.new(
          name: "OrderService",
          file_path: "app/services/order_service.rb",
          methods: [method_info]
        )

        ctrl_score = analyzer.analyze(ctrl_class)
        svc_score = analyzer.analyze(svc_class)

        # Controllerの方がペナルティ緩和されるのでスコアが高い
        expect(ctrl_score).to be > svc_score
      end

      it "applies reduced penalty for model layer" do
        method_call = SolidScore::Models::MethodCallInfo.new(
          method_name: :create, receiver: "AuditLog", receiver_type: :const
        )
        method_info = SolidScore::Models::MethodInfo.new(
          name: :save_with_log, method_calls: [method_call]
        )

        model_class = SolidScore::Models::ClassInfo.new(
          name: "User",
          file_path: "app/models/user.rb",
          methods: [method_info]
        )

        score = analyzer.analyze(model_class)
        # Modelは緩和されるのでスコアが0にはならない (weight 0.5 → 50点)
        expect(score).to be >= 50
      end
    end

    context "with standard library whitelist" do
      it "recognizes common standard library classes" do
        whitelisted = %w[Array Hash Set Time Date Mutex Thread Logger]
        whitelisted.each do |klass|
          method_call = SolidScore::Models::MethodCallInfo.new(
            method_name: :new,
            receiver: klass,
            receiver_type: :const
          )
          method_info = SolidScore::Models::MethodInfo.new(
            name: :test,
            method_calls: [method_call]
          )
          class_info = SolidScore::Models::ClassInfo.new(
            name: "Test",
            methods: [method_info]
          )

          score = analyzer.analyze(class_info)
          expect(score).to eq(100), "Expected #{klass} to be whitelisted"
        end
      end

      it "does not whitelist custom classes" do
        custom_classes = %w[UserService OrderRepository CustomLogger]
        custom_classes.each do |klass|
          method_call = SolidScore::Models::MethodCallInfo.new(
            method_name: :new,
            receiver: klass,
            receiver_type: :const
          )
          method_info = SolidScore::Models::MethodInfo.new(
            name: :test,
            method_calls: [method_call]
          )
          class_info = SolidScore::Models::ClassInfo.new(
            name: "Test",
            methods: [method_info]
          )

          score = analyzer.analyze(class_info)
          expect(score).to be < 100, "Expected #{klass} to NOT be whitelisted"
        end
      end
    end
  end
end
