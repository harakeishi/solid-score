# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::OcpAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a class using polymorphism (good OCP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_ocp.rb")
        shape = classes.find { |c| c.name == "Shape" }
        score = analyzer.analyze(shape)

        expect(score).to be >= 80
      end
    end

    context "with a class using case/when and type checks (bad OCP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_ocp.rb")
        calc = classes.first
        score = analyzer.analyze(calc)

        expect(score).to be <= 50
      end
    end

    context "with a class with no methods" do
      it "returns 100" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Empty", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end
  end
end
