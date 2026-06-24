# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Analyzes Liskov Substitution Principle compliance.
    #
    # LSP違反の静的に検出可能な真のシグナルは「サブクラスが親の契約を破る
    # 例外を投げる（NotImplementedError 以外の raise）」こと。
    #
    # 旧実装は「super を呼ばないメソッドごとに減点（no_super_penalty）」も
    # していたが、静的解析では「親をオーバーライドしたメソッド」と「子で
    # 新規追加しただけのメソッド」を区別できないため、Visitor/Adapter
    # パターンの完全オーバーライドや、単に独自メソッドを多く持つだけの
    # 継承クラスまで一律に減点していた（実測: LSP<100 の継承クラスの84%が
    # この誤検出由来）。super を呼ばないこと自体は LSP 違反ではないため、
    # このペナルティは廃止した。
    #
    # 既知の限界:
    # 現在の判定軸は extra_raise（契約破りの例外）1軸のみで、契約破りの
    # raise を含まない継承クラスは一律 100 点になる。これは「誤検出ゼロを
    # 優先した意図的な縮退」であり、LSP の重み(0.10)が低いことと併せて
    # 許容している。AST だけでは「親メソッドの存在」「事前/事後条件」
    # 「戻り値の共変/反変」を確認できないため、これらの検出軸を追加するには
    # クロスファイル/実行時の型情報が必要になる。将来の拡張候補（共変戻り値・
    # 事前条件強化・シグネチャ変更の検出など）は Issue #24 を参照。
    class LspAnalyzer < BaseAnalyzer
      SIGNATURE_CHANGE_PENALTY = 20
      EXTRA_RAISE_PENALTY = 15

      def analyze(class_info)
        return 100 unless class_info.has_superclass?

        score = 100.0

        class_info.methods.each do |method|
          next if method.name == :initialize

          score -= extra_raise_penalty(method)
        end

        clamp_score(score)
      end

      private

      def extra_raise_penalty(method)
        standard_raises = ["NotImplementedError"]
        extra_raises = method.raises.reject { |r| standard_raises.include?(r) }

        extra_raises.any? ? EXTRA_RAISE_PENALTY : 0
      end
    end
  end
end
