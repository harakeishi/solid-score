# frozen_string_literal: true

module RuboCop
  module SolidScore
    # Injects default configuration from config/default.yml
    module Inject
      def self.defaults!
        path = File.expand_path("../../../config/default.yml", __dir__)
        hash = ::RuboCop::ConfigLoader.load_yaml_configuration(path)
        config = ::RuboCop::Config.new(hash, path)
        puts "configuration from #{path}" if ::RuboCop::ConfigLoader.debug?
        config = ::RuboCop::ConfigLoader.merge_with_default(config, path)
        ::RuboCop::ConfigLoader.instance_variable_set(:@default_configuration, config)
      end
    end
  end
end
