# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "local_ci_plus"
require "local_ci_plus/generators/update_generator"

class UpdateGeneratorTest < Rails::Generators::TestCase
  tests LocalCiPlus::Generators::UpdateGenerator
  destination File.expand_path("../../tmp/update_generator", __dir__)

  setup do
    prepare_destination
  end

  def test_update_injects_once
    create_file "bin/ci", <<~RUBY
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      require_relative "../config/boot"
      require "active_support/continuous_integration"
    RUBY

    run_generator

    assert_file "bin/ci", /require "local_ci_plus"/
    assert_equal 1, File.read(destination_root + "/bin/ci").scan('require "local_ci_plus"').size
  end

  def test_update_is_idempotent
    create_file "bin/ci", <<~RUBY
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      require_relative "../config/boot"
      require "local_ci_plus"
      require "active_support/continuous_integration"
    RUBY

    run_generator

    assert_equal 1, File.read(destination_root + "/bin/ci").scan('require "local_ci_plus"').size
  end

  private

  def create_file(path, contents)
    full_path = File.join(destination_root, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, contents)
  end
end
