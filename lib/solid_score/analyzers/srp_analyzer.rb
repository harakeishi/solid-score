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

        # Phase 2c: フレームワーク基盤クラスの最低スコア保証
        score = mitigate_framework_base(score, class_info)

        # Phase 2c: APIクライアントパターンの最低スコア保証
        score = mitigate_api_client(score, class_info)

        clamp_score(score)
      end

      # LCOM4（Lack of Cohesion of Methods）を計算する。
      # インスタンスメソッドのみを対象とする。クラスメソッドは
      # インスタンス変数を共有しないため凝集度の概念が異なり、
      # 含めるとスコアが不当に低下する。
      # NOTE: ISP Analyzerからも呼ばれるためpublic
      def calculate_lcom4(class_info)
        methods = analyzable_methods(class_info).select(&:instance_method?)
        return 1 if methods.size <= 1

        # Phase 2c: 小規模クラス（メソッド数≤3）はLCOM4を1に固定
        # 少ないメソッドで凝集度を測定しても統計的に意味がない
        return 1 if methods.size <= 3

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

      # Phase 2c: フレームワーク基盤クラス (ApplicationController等) の最低スコア保証
      # Railsの規約として共通ロジック集約は許容される
      def mitigate_framework_base(score, class_info)
        return score unless class_info.framework_base_class?

        [score, 70].max
      end

      # Phase 2c: APIクライアントパターンの最低スコア保証
      # 全publicメソッドが共通のHTTPクライアント変数を参照する構造は
      # 「1つの外部サービスとの通信」という単一責務
      def mitigate_api_client(score, class_info)
        return score unless class_info.http_client_pattern?

        [score, 80].max
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
