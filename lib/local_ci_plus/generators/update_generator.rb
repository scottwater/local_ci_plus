# frozen_string_literal: true

require "rails/generators"

module LocalCiPlus
  module Generators
    class UpdateGenerator < Rails::Generators::Base
      def update_ci_runner
        ci_path = File.join(destination_root, "bin/ci")

        unless File.exist?(ci_path)
          say_status :skipped, "bin/ci does not exist", :yellow
          return
        end

        return if ci_requires_local_ci_plus?

        lines = File.read(ci_path).lines
        boot_index = lines.find_index { |line| line.match?(boot_require_regex) }

        unless boot_index
          say_status :skipped, "bin/ci does not require config/boot", :yellow
          return
        end

        lines.insert(boot_index + 1, "require \"local_ci_plus\"\n")
        File.write(ci_path, lines.join)
      end

      private

      def ci_requires_local_ci_plus?
        File.read(File.join(destination_root, "bin/ci")).match?(/require\s+["']local_ci_plus["']/)
      end

      def boot_require_regex
        /^\s*require_relative\s+\(?\s*["']\.\.\/config\/boot["']/
      end
    end
  end
end
