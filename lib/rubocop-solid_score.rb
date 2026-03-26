# frozen_string_literal: true

require "rubocop"
require "solid_score"
require_relative "rubocop/solid_score/inject"

require_relative "rubocop/cop/solid_score/helpers"
require_relative "rubocop/cop/solid_score/total_score"
require_relative "rubocop/cop/solid_score/principle_base"
require_relative "rubocop/cop/solid_score/single_responsibility"
require_relative "rubocop/cop/solid_score/open_closed"
require_relative "rubocop/cop/solid_score/liskov_substitution"
require_relative "rubocop/cop/solid_score/interface_segregation"
require_relative "rubocop/cop/solid_score/dependency_inversion"

RuboCop::SolidScore::Inject.defaults!
