# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::SrpAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a cohesive class (good SRP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_srp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with a god class (bad SRP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_srp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be <= 60
      end
    end

    context "with a data class" do
      it "returns a high score (penalty mitigated)" do
        classes = parser.parse_file("#{fixtures_path}/data_class.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with a class with no methods" do
      it "returns 100 (trivial class)" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Empty", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end

    # Phase 2a: クラスメソッド対応
    context "with class methods" do
      it "analyzes classes with class methods" do
        classes = parser.parse_file("#{fixtures_path}/class_method_example.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be_between(0, 100)
      end
    end

    # Phase 2c: フレームワーク基盤クラス最低スコア保証
    context "with framework base class" do
      it "guarantees minimum score of 70 for ApplicationController-like classes" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "ApplicationController",
          superclass: "ActionController::Base",
          file_path: "app/controllers/application_controller.rb",
          methods: [
            SolidScore::Models::MethodInfo.new(name: :auth, visibility: :public, line_start: 1, line_end: 10,
                                                instance_variables: [:@user]),
            SolidScore::Models::MethodInfo.new(name: :error_handler, visibility: :public, line_start: 12, line_end: 20,
                                                instance_variables: [:@error]),
            SolidScore::Models::MethodInfo.new(name: :set_locale, visibility: :public, line_start: 22, line_end: 30,
                                                instance_variables: [:@locale]),
            SolidScore::Models::MethodInfo.new(name: :log_request, visibility: :public, line_start: 32, line_end: 40,
                                                instance_variables: [:@request])
          ]
        )
        score = analyzer.analyze(class_info)

        expect(score).to be >= 70
      end
    end

    # Phase 2c: 小規模クラスの補正
    context "with small class (<=3 methods)" do
      it "does not unfairly penalize small classes" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "SmallClass",
          methods: [
            SolidScore::Models::MethodInfo.new(name: :foo, visibility: :public, line_start: 1, line_end: 3,
                                                instance_variables: [:@a]),
            SolidScore::Models::MethodInfo.new(name: :bar, visibility: :public, line_start: 5, line_end: 7,
                                                instance_variables: [:@b])
          ]
        )
        score = analyzer.analyze(class_info)

        expect(score).to be >= 80
      end
    end
  end

  describe "#calculate_lcom4" do
    it "returns 1 for a fully cohesive class" do
      classes = parser.parse_file("#{fixtures_path}/good_srp.rb")
      lcom4 = analyzer.calculate_lcom4(classes.first)

      expect(lcom4).to eq(1)
    end

    it "returns >= 2 for a class with multiple responsibilities" do
      classes = parser.parse_file("#{fixtures_path}/bad_srp.rb")
      lcom4 = analyzer.calculate_lcom4(classes.first)

      expect(lcom4).to be >= 2
    end
  end
end
