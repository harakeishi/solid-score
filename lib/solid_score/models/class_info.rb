# frozen_string_literal: true

module SolidScore
  module Models
    class ClassInfo
      attr_reader :name, :file_path, :line_start, :line_end,
                  :methods, :superclass, :includes, :extends,
                  :instance_variables, :attr_readers, :attr_writers,
                  :kind, :dsl_calls

      def initialize(name:, file_path: "", line_start: 0, line_end: 0,
                     methods: [], superclass: nil, includes: [], extends: [],
                     instance_variables: [], attr_readers: [], attr_writers: [],
                     kind: :class, dsl_calls: [])
        @name = name
        @file_path = file_path
        @line_start = line_start
        @line_end = line_end
        @methods = methods
        @superclass = superclass
        @includes = includes
        @extends = extends
        @instance_variables = instance_variables
        @attr_readers = attr_readers
        @attr_writers = attr_writers
        @kind = kind
        @dsl_calls = dsl_calls
      end

      def module?
        kind == :module
      end

      def public_methods_list
        methods.select { |m| m.public? && m.name != :initialize }
      end

      def line_count
        line_end - line_start + 1
      end

      def has_superclass?
        !superclass.nil? && !superclass.empty?
      end

      def data_class?
        all_attrs = attr_readers + attr_writers
        return false if all_attrs.empty?

        non_init_methods = methods.reject { |m| m.name == :initialize }
        non_init_methods.all? { |m| all_attrs.include?(m.name) }
      end

      # Phase 2c: レイヤー判別
      # file_pathからRailsのレイヤーを自動判別する
      def layer
        @layer ||= determine_layer
      end

      # Phase 2c: フレームワーク基盤クラスかどうか
      # ApplicationController, ApplicationRecord 等
      def framework_base_class?
        return false unless has_superclass?

        FRAMEWORK_DIRECT_BASES.include?(superclass)
      end

      # Phase 2c: HTTPクライアントパターンかどうか
      # 全publicメソッドが共通のクライアント系インスタンス変数を参照する構造
      def http_client_pattern?
        client_ivars = instance_variables.select do |iv|
          iv.to_s.match?(/client|http|connection|api/)
        end
        return false if client_ivars.empty?

        pub = public_methods_list
        return false if pub.size < 2

        pub.all? do |method|
          client_ivars.any? { |iv| method.instance_variables.include?(iv) }
        end
      end

      private

      FRAMEWORK_DIRECT_BASES = %w[
        ActiveRecord::Base ActionController::Base ActionController::API
        ActiveJob::Base ActionMailer::Base
        ActionCable::Channel::Base ActionCable::Connection::Base
      ].freeze

      LAYER_PATH_PATTERNS = {
        controller: "/controllers/",
        model: "/models/",
        service: "/services/",
        job: "/jobs/",
        mailer: "/mailers/",
        form: "/forms/",
        presenter: "/presenters/",
        serializer: "/serializers/",
        validator: "/validators/",
        lib: "/lib/"
      }.freeze

      SUPERCLASS_LAYERS = {
        "ApplicationRecord" => :model,
        "ActiveRecord::Base" => :model,
        "ApplicationController" => :controller,
        "ActionController::Base" => :controller,
        "ActionController::API" => :controller,
        "ApplicationJob" => :job,
        "ActiveJob::Base" => :job,
        "ApplicationMailer" => :mailer,
        "ActionMailer::Base" => :mailer
      }.freeze

      def determine_layer
        # file_pathから判別（最も確実）
        LAYER_PATH_PATTERNS.each do |layer, pattern|
          return layer if file_path.include?(pattern)
        end

        # superclassから判別（file_pathで判別できない場合のフォールバック）
        if has_superclass?
          layer = SUPERCLASS_LAYERS[superclass]
          return layer if layer
        end

        :unknown
      end
    end
  end
end
