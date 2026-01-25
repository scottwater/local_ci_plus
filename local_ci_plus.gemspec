# frozen_string_literal: true

require_relative "lib/local_ci_plus/version"

Gem::Specification.new do |spec|
  spec.name = "local_ci_plus"
  spec.version = LocalCiPlus::VERSION
  spec.authors = ["Scott Watermasysk"]
  spec.email = ["gems@scottw.com"]

  spec.summary = "Enhanced local CI runner for Rails apps"
  spec.description = "Adds parallel execution, fail-fast, resume, and plain output to Rails' local CI runner."
  spec.homepage = "https://github.com/scottwater/local_ci_plus"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path = "lib"
end
