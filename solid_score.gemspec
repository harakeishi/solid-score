# frozen_string_literal: true

require_relative "lib/solid_score/version"

Gem::Specification.new do |spec|
  spec.name = "solid_score"
  spec.version = SolidScore::VERSION
  spec.authors = ["harachan"]
  spec.email = ["44335168+harakeishi@users.noreply.github.com"]

  spec.summary = "SOLID principles scoring tool for Ruby code"
  spec.description = "Static analysis tool that scores Ruby classes/modules against SOLID principles using AST analysis"
  spec.homepage = "https://github.com/harakeishi/solid-score"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["solid-score"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ast", "~> 2.4"
  spec.add_dependency "parser", "~> 3.3"
end
