# frozen_string_literal: true

module SolidScore
  module Analyzers
    class IspAnalyzer < BaseAnalyzer
      PUBLIC_METHOD_SCORES = [
        [5, 100],
        [10, 80],
        [15, 60],
        [20, 40]
      ].freeze

      # Phase 2a: フレームワークConcern/標準ライブラリモジュール
      # これらのincludeはペナルティを緩和する
      FRAMEWORK_MODULES = %w[
        ActiveModel::Validations ActiveModel::Callbacks
        ActiveModel::Dirty ActiveModel::Serialization
        ActiveModel::Model ActiveModel::Attributes
        ActiveSupport::Concern ActiveSupport::Callbacks
        Comparable Enumerable Singleton
      ].freeze

      def analyze(class_info)
        public_methods = class_info.public_methods_list
        return 100 if public_methods.empty?

        score = public_method_score(public_methods.size)
        score -= include_penalty(class_info)
        score -= cohesion_penalty(class_info)

        clamp_score(score)
      end

      private

      def public_method_score(count)
        PUBLIC_METHOD_SCORES.each do |threshold, score|
          return score if count <= threshold
        end

        20
      end

      # Phase 2a: フレームワークConcernを区別してペナルティを計算
      def include_penalty(class_info)
        all_includes = class_info.includes + class_info.extends
        custom_count = all_includes.count { |mod| !framework_module?(mod) }
        framework_count = all_includes.size - custom_count

        # カスタムモジュールはフルペナルティ、フレームワークモジュールは半減
        penalty = custom_penalty(custom_count) + framework_penalty(framework_count)
        [penalty, 20].min
      end

      def custom_penalty(count)
        if count >= 7
          20
        elsif count >= 4
          10
        else
          0
        end
      end

      def framework_penalty(count)
        if count >= 7
          10
        elsif count >= 4
          5
        else
          0
        end
      end

      def framework_module?(module_name)
        return false if module_name.nil?

        FRAMEWORK_MODULES.any? do |fm|
          module_name == fm || module_name.end_with?("::#{fm}")
        end
      end

      def cohesion_penalty(class_info)
        public_methods = class_info.public_methods_list
        return 0 if public_methods.size <= 2

        srp = SrpAnalyzer.new
        public_only_class = Models::ClassInfo.new(
          name: class_info.name,
          methods: public_methods
        )
        lcom4 = srp.calculate_lcom4(public_only_class)

        lcom4 > 2 ? 15 : 0
      end
    end
  end
end
