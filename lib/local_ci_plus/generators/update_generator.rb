# frozen_string_literal: true

require "rails/generators"

module LocalCiPlus
  module Generators
    class UpdateGenerator < Rails::Generators::Base
      def update_ci_runner
        if File.exist?(File.join(destination_root, "bin/ci"))
          unless ci_requires_local_ci_plus?
            inject_into_file "bin/ci", "require \"local_ci_plus\"\n", after: "require_relative \"../config/boot\"\n"
          end
        else
          say_status :skipped, "bin/ci does not exist", :yellow
        end
      end

      private

      def ci_requires_local_ci_plus?
        File.read(File.join(destination_root, "bin/ci")).include?("require \"local_ci_plus\"")
      end
    end
  end
end
