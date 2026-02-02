# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Models::ClassInfo do
  let(:public_method) { SolidScore::Models::MethodInfo.new(name: :process, visibility: :public) }
  let(:private_method) { SolidScore::Models::MethodInfo.new(name: :validate, visibility: :private) }
  let(:init_method) { SolidScore::Models::MethodInfo.new(name: :initialize, visibility: :public) }

  describe "#initialize" do
    it "stores class attributes" do
      class_info = described_class.new(
        name: "OrderService",
        file_path: "app/services/order_service.rb",
        line_start: 1,
        line_end: 50,
        methods: [public_method, private_method],
        superclass: "BaseService",
        includes: ["Validatable"],
        instance_variables: %i[@order @user]
      )

      expect(class_info.name).to eq("OrderService")
      expect(class_info.superclass).to eq("BaseService")
      expect(class_info.methods).to have_attributes(size: 2)
    end
  end

  describe "#public_methods_list" do
    it "returns only public methods excluding initialize" do
      class_info = described_class.new(
        name: "Foo",
        methods: [init_method, public_method, private_method]
      )

      expect(class_info.public_methods_list.map(&:name)).to eq([:process])
    end
  end

  describe "#line_count" do
    it "calculates lines from start to end" do
      class_info = described_class.new(name: "Foo", line_start: 1, line_end: 50)
      expect(class_info.line_count).to eq(50)
    end
  end

  describe "#has_superclass?" do
    it "returns true when superclass is present" do
      class_info = described_class.new(name: "Foo", superclass: "Bar")
      expect(class_info.has_superclass?).to be true
    end

    it "returns false when no superclass" do
      class_info = described_class.new(name: "Foo")
      expect(class_info.has_superclass?).to be false
    end
  end

  describe "#data_class?" do
    it "returns true when all methods are attr readers/writers" do
      attr_method = SolidScore::Models::MethodInfo.new(
        name: :name, visibility: :public, line_start: 2, line_end: 2
      )
      class_info = described_class.new(
        name: "Foo",
        methods: [init_method, attr_method],
        attr_readers: [:name],
        attr_writers: []
      )
      expect(class_info.data_class?).to be true
    end
  end
end
