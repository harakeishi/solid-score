# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::LspAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a class without inheritance" do
      it "returns 100 (LSP not applicable)" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Standalone", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end

    context "with good LSP compliance" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_lsp.rb")
        csv_processor = classes.find { |c| c.name == "CsvProcessor" }
        score = analyzer.analyze(csv_processor)

        expect(score).to be >= 80
      end
    end

    context "with LSP violations (extra raises, signature change)" do
      it "returns a lower score" do
        classes = parser.parse_file("#{fixtures_path}/bad_lsp.rb")
        strict_logger = classes.find { |c| c.name == "StrictLogger" }
        score = analyzer.analyze(strict_logger)

        expect(score).to be < 100
      end
    end
  end
end
