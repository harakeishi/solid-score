# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Analyzers::IspAnalyzer do
  let(:parser) { SolidScore::Parser::RubyParser.new }
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with a small focused interface (good ISP)" do
      it "returns a high score" do
        classes = parser.parse_file("#{fixtures_path}/good_isp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be >= 80
      end
    end

    context "with a bloated interface (bad ISP)" do
      it "returns a low score" do
        classes = parser.parse_file("#{fixtures_path}/bad_isp.rb")
        score = analyzer.analyze(classes.first)

        expect(score).to be <= 40
      end
    end

    context "with no methods" do
      it "returns 100" do
        class_info = SolidScore::Models::ClassInfo.new(name: "Empty", methods: [])
        score = analyzer.analyze(class_info)

        expect(score).to eq(100)
      end
    end
    
    # Issue #8: symmetric method pair detection
    describe "#effective_public_method_count" do
      def make_class(method_names)
        methods = method_names.each_with_index.map do |name, i|
          SolidScore::Models::MethodInfo.new(
            name: name.to_sym, visibility: :public, line_start: i, line_end: i + 1
          )
        end
        SolidScore::Models::ClassInfo.new(name: "Demo", methods: methods)
      end

      it "discounts one method from each matched symmetric pair" do
        class_info = make_class(%i[enable_user disable_user start_job stop_job process])
        # 5 methods, 2 pairs detected -> effective count = 3
        expect(analyzer.send(:effective_public_method_count, class_info)).to eq(3)
      end

      it "requires the suffix to match exactly" do
        class_info = make_class(%i[enable_user disable_admin])
        expect(analyzer.send(:effective_public_method_count, class_info)).to eq(2)
      end

      it "supports the documented prefix list" do
        names = %i[
          encrypt_payload decrypt_payload
          compress_blob decompress_blob
          serialize_value deserialize_value
          connect_db disconnect_db
        ]
        class_info = make_class(names)
        expect(analyzer.send(:effective_public_method_count, class_info)).to eq(4)
      end

      it "leaves unrelated methods untouched" do
        class_info = make_class(%i[foo bar baz])
        expect(analyzer.send(:effective_public_method_count, class_info)).to eq(3)
      end

      it "does not pair bare prefixes without an underscore" do
        # `enable` and `disable` (no suffix) must not pair with each other
        class_info = make_class(%i[enable disable])
        expect(analyzer.send(:effective_public_method_count, class_info)).to eq(2)
      end

      it "discounts each pair-prefix independently when suffixes overlap" do
        # add_user / remove_user is one pair, create_user / delete_user is another.
        # Both pairs should be detected, so 4 raw methods -> 2 effective.
        class_info = make_class(%i[add_user remove_user create_user delete_user])
        expect(analyzer.send(:effective_public_method_count, class_info)).to eq(2)
      end
    end

    context "when symmetric pairs prevent the public-method-count penalty" do
      it "scores higher than the equivalent unpaired class" do
        paired_names = (1..5).flat_map { |i| [:"enable_resource_#{i}", :"disable_resource_#{i}"] }
        paired_methods = paired_names.each_with_index.map do |n, i|
          SolidScore::Models::MethodInfo.new(name: n, visibility: :public, line_start: i, line_end: i + 1)
        end
        paired_class = SolidScore::Models::ClassInfo.new(name: "Paired", methods: paired_methods)

        unpaired_names = (1..10).map { |i| :"action_#{i}" }
        unpaired_methods = unpaired_names.each_with_index.map do |n, i|
          SolidScore::Models::MethodInfo.new(name: n, visibility: :public, line_start: i, line_end: i + 1)
        end
        unpaired_class = SolidScore::Models::ClassInfo.new(name: "Unpaired", methods: unpaired_methods)

        expect(analyzer.analyze(paired_class)).to be > analyzer.analyze(unpaired_class)
      end
    end

    # Issue #9: inspection class mitigation
    context "with inspection class" do
      it "guarantees minimum score of 80 regardless of public method count" do
        methods = (1..15).map do |i|
          SolidScore::Models::MethodInfo.new(
            name: :"check_#{i}", visibility: :public, line_start: i, line_end: i + 1
          )
        end
        class_info = SolidScore::Models::ClassInfo.new(
          name: "Muumuu::GoogleCloudChannel::Client::Inspect",
          methods: methods
        )
        score = analyzer.analyze(class_info)
        expect(score).to be >= 80
      end
    end

    # Issue #7: linear public method scoring curve
    describe "#public_method_score (linear curve)" do
      context "when count <= 5" do
        it "returns the ceiling" do
          (0..5).each do |n|
            expect(analyzer.send(:public_method_score, n)).to eq(100)
          end
        end
      end

      context "when count is between 6 and 24" do
        it "applies a -4pt slope per method" do
          expect(analyzer.send(:public_method_score, 6)).to eq(96)
          expect(analyzer.send(:public_method_score, 7)).to eq(92)
          expect(analyzer.send(:public_method_score, 10)).to eq(80)
          expect(analyzer.send(:public_method_score, 24)).to eq(24)
        end
      end

      context "when count >= 25" do
        it "floors at 20" do
          expect(analyzer.send(:public_method_score, 25)).to eq(20)
          expect(analyzer.send(:public_method_score, 50)).to eq(20)
          expect(analyzer.send(:public_method_score, 200)).to eq(20)
        end
      end

      it "does not exhibit a 20pt cliff when crossing 5 -> 6" do
        score5 = analyzer.send(:public_method_score, 5)
        score6 = analyzer.send(:public_method_score, 6)
        expect(score5 - score6).to eq(4)
      end
    end

    # Phase 2a: フレームワークConcernの緩和
    context "with framework module includes" do
      it "applies reduced penalty for framework modules" do
        class_info = SolidScore::Models::ClassInfo.new(
          name: "AuditableRecord",
          includes: %w[Comparable ActiveModel::Validations ActiveModel::Dirty ActiveSupport::Callbacks],
          methods: [
            SolidScore::Models::MethodInfo.new(name: :audit, visibility: :public, line_start: 1, line_end: 3)
          ]
        )
        score_with_framework = analyzer.analyze(class_info)

        class_info_custom = SolidScore::Models::ClassInfo.new(
          name: "CustomRecord",
          includes: %w[MyModule1 MyModule2 MyModule3 MyModule4],
          methods: [
            SolidScore::Models::MethodInfo.new(name: :audit, visibility: :public, line_start: 1, line_end: 3)
          ]
        )
        score_with_custom = analyzer.analyze(class_info_custom)

        # Framework includes should result in higher score than custom includes
        expect(score_with_framework).to be > score_with_custom
      end
    end
  end
end
