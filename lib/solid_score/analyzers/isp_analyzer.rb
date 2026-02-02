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

      def include_penalty(class_info)
        include_count = class_info.includes.size + class_info.extends.size

        if include_count >= 7
          20
        elsif include_count >= 4
          10
        else
          0
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
