# frozen_string_literal: true

require "bundler/setup"
Bundler.require(:default)

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "minitest/autorun"
require "minitest/pride"
