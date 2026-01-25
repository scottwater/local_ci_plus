# frozen_string_literal: true

require "test_helper"
require "local_ci_plus"

class ContinuousIntegrationTest < Minitest::Test
  def test_parallel_incompatible_with_fail_fast
    with_argv("--parallel", "--fail-fast") do
      error = assert_raises(SystemExit) do
        LocalCiPlus::ContinuousIntegration.new.validate_mode_compatibility!
      end

      assert_match(/Cannot combine --parallel with --fail-fast/, error.message)
    end
  end

  def test_parallel_incompatible_with_continue
    with_argv("--parallel", "--continue") do
      error = assert_raises(SystemExit) do
        LocalCiPlus::ContinuousIntegration.new.validate_mode_compatibility!
      end

      assert_match(/Cannot combine --parallel with --continue/, error.message)
    end
  end

  private

  def with_argv(*args)
    original = ARGV.dup
    ARGV.replace(args)
    yield
  ensure
    ARGV.replace(original)
  end
end
