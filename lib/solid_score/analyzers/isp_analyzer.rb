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

      # Issue #8: Symmetric prefix pairs.
      # Methods like `enable_X` / `disable_X` describe one capability and should
      # not double-count toward the public surface. Each prefix pair contributes
      # at most one discount per matching suffix.
      SYMMETRIC_PREFIXES = [
        %w[enable disable], %w[start stop], %w[open close],
        %w[add remove], %w[create delete], %w[show hide],
        %w[lock unlock], %w[mount unmount], %w[register unregister],
        %w[encrypt decrypt], %w[compress decompress],
        %w[serialize deserialize], %w[connect disconnect],
        %w[attach detach], %w[subscribe unsubscribe]
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

        score = public_method_score(effective_public_method_count(class_info))
        score -= include_penalty(class_info)
        score -= cohesion_penalty(class_info)

        clamp_score(score)
      end

      private

      def effective_public_method_count(class_info)
        names = class_info.public_methods_list.map { |m| m.name.to_s }
        names.size - symmetric_pair_count(names)
      end

      def symmetric_pair_count(names)
        SYMMETRIC_PREFIXES.sum do |a, b|
          a_suffixes = names.grep(/\A#{a}_/).map { |n| n.sub(/\A#{a}_/, "") }
          b_suffixes = names.grep(/\A#{b}_/).map { |n| n.sub(/\A#{b}_/, "") }
          (a_suffixes & b_suffixes).size
        end
      end

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
