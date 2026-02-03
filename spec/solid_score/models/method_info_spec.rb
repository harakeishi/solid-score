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

    # Phase 1 改善: 新しいフィールドのテスト
    it "stores method_calls and case_when_count" do
      method_call = SolidScore::Models::MethodCallInfo.new(
        method_name: :new,
        receiver: "Array",
        receiver_type: :const
      )
      method_info = described_class.new(
        name: :process,
        method_calls: [method_call],
        case_when_count: 3
      )

      expect(method_info.method_calls).to eq([method_call])
      expect(method_info.case_when_count).to eq(3)
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

RSpec.describe SolidScore::Models::MethodCallInfo do
  describe "#initialize" do
    it "stores method call attributes" do
      method_call = described_class.new(
        method_name: :new,
        receiver: "UserService",
        receiver_type: :const
      )

      expect(method_call.method_name).to eq(:new)
      expect(method_call.receiver).to eq("UserService")
      expect(method_call.receiver_type).to eq(:const)
    end

    it "defaults receiver_type to :unknown" do
      method_call = described_class.new(method_name: :foo)

      expect(method_call.receiver_type).to eq(:unknown)
      expect(method_call.receiver).to be_nil
    end
  end

  describe "#new_call_on_const?" do
    it "returns true for .new calls on constants" do
      method_call = described_class.new(
        method_name: :new,
        receiver: "Array",
        receiver_type: :const
      )

      expect(method_call.new_call_on_const?).to be true
    end

    it "returns false for non-.new calls" do
      method_call = described_class.new(
        method_name: :create,
        receiver: "User",
        receiver_type: :const
      )

      expect(method_call.new_call_on_const?).to be false
    end

    it "returns false for .new on non-constants" do
      method_call = described_class.new(
        method_name: :new,
        receiver: "@service",
        receiver_type: :ivar
      )

      expect(method_call.new_call_on_const?).to be false
    end
  end
end
