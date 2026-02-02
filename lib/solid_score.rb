# frozen_string_literal: true

require_relative "solid_score/version"
require_relative "solid_score/models/method_info"
require_relative "solid_score/models/class_info"
require_relative "solid_score/models/score_result"
require_relative "solid_score/parser/ruby_parser"
require_relative "solid_score/analyzers/base_analyzer"
require_relative "solid_score/analyzers/srp_analyzer"
require_relative "solid_score/analyzers/ocp_analyzer"
require_relative "solid_score/analyzers/lsp_analyzer"
require_relative "solid_score/analyzers/isp_analyzer"
require_relative "solid_score/analyzers/dip_analyzer"
require_relative "solid_score/scorer"
require_relative "solid_score/configuration"
require_relative "solid_score/formatters/base_formatter"
require_relative "solid_score/formatters/text_formatter"
require_relative "solid_score/formatters/json_formatter"
require_relative "solid_score/runner"
require_relative "solid_score/cli"

module SolidScore
end
