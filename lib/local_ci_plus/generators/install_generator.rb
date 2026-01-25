# frozen_string_literal: true

require "rails/generators"

module LocalCiPlus
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_ci_runner
        if File.exist?(File.join(destination_root, "bin/ci")) && !options[:force]
          say_status :skipped, "bin/ci already exists (use --force to overwrite)", :yellow
          return
        end

        template "bin_ci", "bin/ci"
      end
    end
  end
end
