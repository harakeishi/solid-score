# frozen_string_literal: true

module SolidScore
  module Analyzers
    class SrpAnalyzer < BaseAnalyzer
      LCOM4_SCORES = {
        1 => 100,
        2 => 60,
        3 => 30
      }.freeze

      def analyze(class_info)
        methods = analyzable_methods(class_info)
        return 100 if methods.empty?

        lcom4 = calculate_lcom4(class_info)
        base_score = lcom4_to_score(lcom4)

        base_score = mitigate_data_class(base_score, class_info) if class_info.data_class?

        score = base_score
        score -= wmc_penalty(class_info)
        score -= line_count_penalty(class_info)

        clamp_score(score)
      end

      def calculate_lcom4(class_info)
        methods = analyzable_methods(class_info)
        return 1 if methods.size <= 1

        graph = build_method_graph(methods)
        count_connected_components(graph, methods)
      end

      private

      def analyzable_methods(class_info)
        class_info.methods.reject { |m| m.name == :initialize || m.empty? }
      end

      def build_method_graph(methods)
        adjacency = Hash.new { |h, k| h[k] = Set.new }

        methods.each_with_index do |m1, i|
          methods[(i + 1)..].each do |m2|
            if share_instance_variables?(m1, m2) || call_each_other?(m1, m2)
              adjacency[m1.name] << m2.name
              adjacency[m2.name] << m1.name
            end
          end
        end

        adjacency
      end

      def share_instance_variables?(m1, m2)
        m1.instance_variables.intersect?(m2.instance_variables)
      end

      def call_each_other?(m1, m2)
        m1.called_methods.include?(m2.name) || m2.called_methods.include?(m1.name)
      end

      def count_connected_components(graph, methods)
        visited = Set.new
        components = 0

        methods.each do |method|
          next if visited.include?(method.name)

          bfs(method.name, graph, visited)
          components += 1
        end

        components
      end

      def bfs(start, graph, visited)
        queue = [start]

        while (current = queue.shift)
          next if visited.include?(current)

          visited << current
          graph[current].each { |neighbor| queue << neighbor unless visited.include?(neighbor) }
        end
      end

      def lcom4_to_score(lcom4)
        LCOM4_SCORES.fetch(lcom4, 0)
      end

      def mitigate_data_class(score, _class_info)
        [score, 90].max
      end

      def wmc_penalty(class_info)
        wmc = class_info.methods.sum(&:cyclomatic_complexity)

        if wmc > 40
          20
        elsif wmc > 20
          10
        else
          0
        end
      end

      def line_count_penalty(class_info)
        lines = class_info.line_count

        if lines > 400
          20
        elsif lines > 200
          10
        else
          0
        end
      end
    end
  end
end
