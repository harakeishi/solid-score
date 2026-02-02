# frozen_string_literal: true

module SolidScore
  module Formatters
    class BaseFormatter
      def format(results)
        raise NotImplementedError
      end
    end
  end
end
