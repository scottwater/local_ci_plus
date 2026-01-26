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

  def test_interrupt_parallel_called_on_int_and_term_in_parallel_mode
    with_argv("--parallel") do
      outer = LocalCiPlus::ContinuousIntegration.new
      inner = LocalCiPlus::ContinuousIntegration.new
      interrupt_calls = 0

      inner.define_singleton_method(:interrupt_parallel!) do
        interrupt_calls += 1
      end

      handlers = {}
      signal_stub = lambda do |signal, handler = nil, &block|
        handler = block if block
        handlers[signal] = handler if handler.is_a?(Proc)
        "DEFAULT"
      end

      with_stubbed_singleton_method(LocalCiPlus::ContinuousIntegration, :new, ->(*_args, &_block) { inner }) do
        with_stubbed_singleton_method(Signal, :trap, signal_stub) do
          outer.report("CI") {}
        end
      end

      assert_raises(SystemExit) do
        capture_io { handlers.fetch("INT").call }
      end
      assert_equal 1, interrupt_calls

      assert_raises(SystemExit) do
        capture_io { handlers.fetch("TERM").call }
      end
      assert_equal 2, interrupt_calls
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
    with_env("TERM" => "xterm-256color", "NO_COLOR" => nil, "CI_PLAIN" => nil) do
      with_argv do
        with_stdout_tty(true) do
          refute LocalCiPlus::ContinuousIntegration.new.plain?
        end
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

  def with_env(values)
    originals = {}
    values.each_key do |key|
      originals[key] = ENV.key?(key) ? ENV[key] : :__undefined__
    end

    values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    originals.each do |key, value|
      value == :__undefined__ ? ENV.delete(key) : ENV[key] = value
    end
  end

  def with_stubbed_singleton_method(klass, method_name, replacement)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name, replacement)
    yield
  ensure
    klass.singleton_class.define_method(method_name, original)
  end
end
