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
  end
end
