# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Parser::RubyParser do
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }

  describe "#parse_file" do
    it "extracts class info from a simple class" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")

      expect(classes.size).to eq(1)
      calc = classes.first
      expect(calc.name).to eq("Calculator")
      expect(calc.superclass).to be_nil
      expect(calc.methods.size).to eq(3)
    end

    it "detects method visibility" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")
      calc = classes.first

      public_names = calc.methods.select(&:public?).map(&:name)
      expect(public_names).to contain_exactly(:initialize, :calculate)

      private_names = calc.methods.reject(&:public?).map(&:name)
      expect(private_names).to contain_exactly(:tax_amount)
    end

    it "detects instance variables" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")
      calc = classes.first

      init = calc.methods.find { |m| m.name == :initialize }
      expect(init.instance_variables).to include(:@tax_rate)
    end

    it "detects inheritance" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/class_with_inheritance.rb")

      dog = classes.find { |c| c.name == "Dog" }
      expect(dog.superclass).to eq("Animal")
    end

    it "extracts multiple classes from one file" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/multiple_classes.rb")

      expect(classes.size).to eq(2)
      names = classes.map(&:name)
      expect(names).to contain_exactly("Foo", "Baz")
    end

    it "detects includes" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/multiple_classes.rb")

      baz = classes.find { |c| c.name == "Baz" }
      expect(baz.includes).to include("Comparable")
    end

    it "detects method calls within methods" do
      parser = described_class.new
      classes = parser.parse_file("#{fixtures_path}/simple_class.rb")
      calc = classes.first

      calculate_method = calc.methods.find { |m| m.name == :calculate }
      expect(calculate_method.called_methods).to include(:tax_amount)
    end

    # Phase 1 改善: case/when 分岐カウントのテスト
    context "case/when branch counting" do
      it "counts case/when branches in methods" do
        parser = described_class.new
        classes = parser.parse_file("#{fixtures_path}/bad_ocp.rb")
        calc = classes.first

        # bad_ocp.rb has case/when with 3 branches
        area_method = calc.methods.find { |m| m.name == :area }
        expect(area_method.case_when_count).to eq(3)
      end

      it "returns 0 for methods without case/when" do
        parser = described_class.new
        classes = parser.parse_file("#{fixtures_path}/good_dip.rb")
        order_service = classes.first

        create_method = order_service.methods.find { |m| m.name == :create }
        expect(create_method.case_when_count).to eq(0)
      end
    end

    # Phase 1 改善: レシーバ情報収集のテスト
    context "receiver info collection" do
      it "collects method calls with receiver information" do
        parser = described_class.new
        classes = parser.parse_file("#{fixtures_path}/bad_dip.rb")
        order_service = classes.first

        create_method = order_service.methods.find { |m| m.name == :create }
        expect(create_method.method_calls).not_to be_empty

        # Find .new calls
        new_calls = create_method.method_calls.select { |mc| mc.method_name == :new }
        expect(new_calls).not_to be_empty

        # Check receiver information
        new_call = new_calls.first
        expect(new_call.receiver_type).to eq(:const)
        expect(new_call.receiver).not_to be_nil
      end

      it "identifies receiver types correctly" do
        parser = described_class.new
        classes = parser.parse_file("#{fixtures_path}/good_dip.rb")
        order_service = classes.first

        create_method = order_service.methods.find { |m| m.name == :create }
        method_calls = create_method.method_calls

        # Calls on instance variables should have :ivar receiver type
        ivar_calls = method_calls.select { |mc| mc.receiver_type == :ivar }
        expect(ivar_calls).not_to be_empty
      end
    end
  end
end
