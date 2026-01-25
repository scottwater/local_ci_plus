# frozen_string_literal: true

require "test_helper"
require "local_ci_plus"

class ContinuousIntegrationTest < Minitest::Test
  def test_parallel_incompatible_with_fail_fast
    with_argv("--parallel", "--fail-fast") do
      _stdout, _stderr = capture_io do
        error = assert_raises(SystemExit) do
          LocalCiPlus::ContinuousIntegration.new.validate_mode_compatibility!
        end

        assert_match(/Cannot combine --parallel with --fail-fast/, error.message)
      end
    end
  end

  def test_parallel_incompatible_with_continue
    with_argv("--parallel", "--continue") do
      _stdout, _stderr = capture_io do
        error = assert_raises(SystemExit) do
          LocalCiPlus::ContinuousIntegration.new.validate_mode_compatibility!
        end

        assert_match(/Cannot combine --parallel with --continue/, error.message)
      end
    end
  end

  def test_plain_mode_enabled_by_flag
    with_argv("--plain") do
      with_stdout_tty(true) do
        assert LocalCiPlus::ContinuousIntegration.new.plain?
      end
    end
  end

  def test_plain_mode_enabled_when_not_tty
    with_argv do
      with_stdout_tty(false) do
        assert LocalCiPlus::ContinuousIntegration.new.plain?
      end
    end
  end

  def test_plain_mode_disabled_when_tty_and_no_flag
    with_argv do
      with_stdout_tty(true) do
        refute LocalCiPlus::ContinuousIntegration.new.plain?
      end
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

  def with_stdout_tty(value)
    original_stdout = $stdout
    stubbed = StringIO.new
    stubbed.define_singleton_method(:tty?) { value }
    $stdout = stubbed
    yield
  ensure
    $stdout = original_stdout
  end
end
