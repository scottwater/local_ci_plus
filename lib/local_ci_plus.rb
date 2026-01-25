# frozen_string_literal: true

begin
  require "active_support/continuous_integration"
rescue LoadError
end

require_relative "local_ci_plus/continuous_integration"
require_relative "local_ci_plus/version"

module LocalCiPlus
  class Error < StandardError; end
end

if defined?(ActiveSupport)
  ActiveSupport.send(:remove_const, :ContinuousIntegration) if
    ActiveSupport.const_defined?(:ContinuousIntegration, false)
  ActiveSupport.const_set(:ContinuousIntegration, LocalCiPlus::ContinuousIntegration)
end
