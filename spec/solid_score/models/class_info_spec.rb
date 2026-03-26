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

  # Phase 2c: レイヤー判別
  describe "#layer" do
    it "detects controller layer from file_path" do
      ci = described_class.new(name: "UsersController", file_path: "app/controllers/users_controller.rb")
      expect(ci.layer).to eq(:controller)
    end

    it "detects model layer from file_path" do
      ci = described_class.new(name: "User", file_path: "app/models/user.rb")
      expect(ci.layer).to eq(:model)
    end

    it "detects service layer from file_path" do
      ci = described_class.new(name: "UserService", file_path: "app/services/user_service.rb")
      expect(ci.layer).to eq(:service)
    end

    it "detects lib layer from file_path" do
      ci = described_class.new(name: "Client", file_path: "project/lib/api/client.rb")
      expect(ci.layer).to eq(:lib)
    end

    it "falls back to superclass detection" do
      ci = described_class.new(name: "User", file_path: "unknown/user.rb", superclass: "ApplicationRecord")
      expect(ci.layer).to eq(:model)
    end

    it "returns :unknown when no match" do
      ci = described_class.new(name: "Foo", file_path: "unknown/foo.rb")
      expect(ci.layer).to eq(:unknown)
    end
  end

  describe "#framework_base_class?" do
    it "returns true for ApplicationRecord direct subclass" do
      ci = described_class.new(name: "User", superclass: "ActiveRecord::Base")
      expect(ci.framework_base_class?).to be true
    end

    it "returns true for ApplicationController direct subclass" do
      ci = described_class.new(name: "Users", superclass: "ActionController::Base")
      expect(ci.framework_base_class?).to be true
    end

    it "returns false for regular superclass" do
      ci = described_class.new(name: "UserService", superclass: "BaseService")
      expect(ci.framework_base_class?).to be false
    end

    it "returns false for ApplicationRecord subclass (indirect)" do
      ci = described_class.new(name: "User", superclass: "ApplicationRecord")
      expect(ci.framework_base_class?).to be false
    end
  end

  describe "#http_client_pattern?" do
    it "returns true when all public methods share a client ivar" do
      m1 = SolidScore::Models::MethodInfo.new(
        name: :get_user, visibility: :public,
        instance_variables: [:@client], line_start: 1, line_end: 3
      )
      m2 = SolidScore::Models::MethodInfo.new(
        name: :create_user, visibility: :public,
        instance_variables: [:@client], line_start: 5, line_end: 7
      )
      ci = described_class.new(
        name: "ApiClient",
        methods: [init_method, m1, m2],
        instance_variables: [:@client]
      )
      expect(ci.http_client_pattern?).to be true
    end

    it "returns false when methods don't share client ivar" do
      m1 = SolidScore::Models::MethodInfo.new(
        name: :process, visibility: :public,
        instance_variables: [:@data], line_start: 1, line_end: 3
      )
      ci = described_class.new(
        name: "Processor",
        methods: [m1],
        instance_variables: [:@data]
      )
      expect(ci.http_client_pattern?).to be false
    end
  end
end
