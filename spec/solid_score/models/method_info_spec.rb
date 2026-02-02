# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Models::MethodInfo do
  describe "#initialize" do
    it "stores method attributes" do
      method_info = described_class.new(
        name: :calculate,
        visibility: :public,
        line_start: 10,
        line_end: 20,
        instance_variables: %i[@total @tax],
        called_methods: [:validate],
        parameters: [%i[req amount]],
        cyclomatic_complexity: 3,
        raises: [],
        calls_super: false
      )

      expect(method_info.name).to eq(:calculate)
      expect(method_info.visibility).to eq(:public)
      expect(method_info.instance_variables).to eq(%i[@total @tax])
      expect(method_info.called_methods).to eq([:validate])
      expect(method_info.cyclomatic_complexity).to eq(3)
    end
  end

  describe "#public?" do
    it "returns true for public methods" do
      method_info = described_class.new(name: :foo, visibility: :public)
      expect(method_info.public?).to be true
    end

    it "returns false for private methods" do
      method_info = described_class.new(name: :foo, visibility: :private)
      expect(method_info.public?).to be false
    end
  end

  describe "#empty?" do
    it "returns true when line_start equals line_end" do
      method_info = described_class.new(name: :foo, line_start: 5, line_end: 5)
      expect(method_info.empty?).to be true
    end
  end
end
