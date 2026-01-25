# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "local_ci_plus"
require "local_ci_plus/generators/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests LocalCiPlus::Generators::InstallGenerator
  destination File.expand_path("../../tmp/install_generator", __dir__)

  setup do
    prepare_destination
  end

  def test_install_copies_bin_ci
    run_generator

    assert_file "bin/ci", /require "local_ci_plus"/
  end

  def test_install_skips_without_force
    create_file "bin/ci", "#!/usr/bin/env ruby\n"

    run_generator

    assert_file "bin/ci", /\A#!\/usr\/bin\/env ruby\n\z/
  end

  def test_install_overwrites_with_force
    create_file "bin/ci", "#!/usr/bin/env ruby\n"

    run_generator ["--force"]

    assert_file "bin/ci", /require "local_ci_plus"/
  end

  private

  def create_file(path, contents)
    full_path = File.join(destination_root, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, contents)
  end
end
