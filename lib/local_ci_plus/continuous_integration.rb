# frozen_string_literal: true

# Extended version of Rails' ActiveSupport::ContinuousIntegration with:
# - bin/ci -f (--fail-fast): Stop immediately when a step fails
# - bin/ci -c (--continue): Resume from the last failed step
# - bin/ci -fc: Both options combined
# - bin/ci -p (--parallel): Run all steps concurrently

require "tempfile"

module LocalCiPlus
  class ContinuousIntegration
  COLORS = {
    banner: "\033[1;32m",   # Green
    title: "\033[1;35m",    # Purple
    subtitle: "\033[1;90m", # Medium Gray
    error: "\033[1;31m",    # Red
    success: "\033[1;32m",  # Green
    skip: "\033[1;33m",     # Yellow
    pending: "\033[1;34m"   # Blue
  }

  STATE_FILE = ".ci_state"

  attr_reader :results

  def self.run(title = "Continuous Integration", subtitle = "Running tests, style checks, and security audits", &block)
    new.tap do |ci|
      if ci.help?
        ci.print_help
        exit 0
      end
      ENV["CI"] = "true"
      ci.validate_mode_compatibility!
      ci.heading title, subtitle, padding: false
      ci.show_mode_info
      ci.report(title, &block)
      abort unless ci.success?
    end
  end

  def initialize
    @results = []
    @step_names = []
    @parallel_steps = []
    @skip_until = continue_mode? ? load_failed_step : nil
    @skipping = !!@skip_until
  end

  def validate_mode_compatibility!
    if parallel? && fail_fast?
      abort colorize("❌ Cannot combine --parallel with --fail-fast", :error)
    end
    if parallel? && continue_mode?
      abort colorize("❌ Cannot combine --parallel with --continue", :error)
    end
  end

  def help?
    ARGV.include?("-h") || ARGV.include?("--help")
  end

  def print_help
    $stdout.puts <<~HELP
      Usage: bin/ci [options]

      Options:
        -f, --fail-fast   Stop immediately when a step fails
        -c, --continue    Resume from the last failed step
        -fc, -cf          Combine fail-fast and continue
        -p, --parallel    Run all steps concurrently
        --plain           Disable ANSI cursor updates/colors (also used for non-TTY)
        -h, --help        Show this help

      Compatibility:
        --parallel cannot be combined with --fail-fast or --continue
    HELP
  end

  def step(title, *command)
    @step_names << title

    if @skipping
      if title == @skip_until
        @skipping = false
        clear_state
      else
        heading title, "skipped (resuming from: #{@skip_until})", type: :skip
        results << [true, title]
        return
      end
    end

    if parallel?
      @parallel_steps << {title: title, command: command}
      return
    end

    heading title, command.join(" "), type: :title
    report(title) do
      success = system(*command)
      results << [success, title]

      if !success && fail_fast?
        save_failed_step(title)
        abort colorize("\n❌ #{title} failed (fail-fast enabled)", :error)
      end
    end
  end

  def success?
    results.map(&:first).all?
  end

  def failure(title, subtitle = nil)
    heading title, subtitle, type: :error
  end

  def heading(heading, subtitle = nil, type: :banner, padding: true)
    echo "#{"\n\n" if padding}#{heading}", type: type
    echo "#{subtitle}#{"\n" if padding}", type: :subtitle if subtitle
  end

  def echo(text, type:)
    puts colorize(text, type)
  end

  def show_mode_info
    modes = []
    modes << "fail-fast" if fail_fast?
    modes << "continue from '#{@skip_until}'" if @skip_until
    modes << "parallel" if parallel?
    echo "Mode: #{modes.join(", ")}\n", type: :subtitle if modes.any?
  end

  def report(title, &block)
    prev_int = Signal.trap("INT") {
      interrupt_parallel! if parallel?
      abort colorize("\n❌ #{title} interrupted", :error)
    }
    prev_term = Signal.trap("TERM") {
      interrupt_parallel! if parallel?
      abort colorize("\n❌ #{title} terminated", :error)
    }

    ci = self.class.new
    ci.instance_variable_set(:@skip_until, @skip_until)
    ci.instance_variable_set(:@skipping, @skipping)

    elapsed = timing do
      ci.instance_eval(&block)
      ci.run_parallel_steps! if ci.parallel? && ci.parallel_steps.any?
    end

    @skip_until = ci.instance_variable_get(:@skip_until)
    @skipping = ci.instance_variable_get(:@skipping)

    if ci.success?
      echo "\n✅ #{title} passed in #{elapsed}", type: :success
      clear_state
    else
      echo "\n❌ #{title} failed in #{elapsed}", type: :error

      if ci.multiple_results?
        ci.failures.each do |success, step_title|
          echo "   ↳ #{step_title} failed", type: :error
        end
      end
    end

    results.concat ci.results
  ensure
    Signal.trap("INT", prev_int || "DEFAULT")
    Signal.trap("TERM", prev_term || "DEFAULT")
  end

  def failures
    results.reject(&:first)
  end

  def multiple_results?
    results.size > 1
  end

  def fail_fast?
    ARGV.include?("-f") || ARGV.include?("--fail-fast") ||
      ARGV.include?("-fc") || ARGV.include?("-cf")
  end

  def continue_mode?
    ARGV.include?("-c") || ARGV.include?("--continue") ||
      ARGV.include?("-fc") || ARGV.include?("-cf")
  end

  def parallel?
    ARGV.include?("-p") || ARGV.include?("--parallel")
  end

  def plain?
    return true if ARGV.include?("--plain")
    return true if !$stdout.tty?
    return true if ENV["TERM"] == "dumb"
    return true if ENV["NO_COLOR"]
    return true if ENV["CI_PLAIN"] == "1" || ENV["CI_PLAIN"] == "true"

    false
  end

  attr_reader :parallel_steps

  MAX_OUTPUT_BYTES = 100 * 1024  # 100KB max per output stream

  def run_parallel_steps!
    total = @parallel_steps.size
    @running_jobs = []
    completed = []
    completed_by_index = {}

    echo "\n⏳ Running #{total} steps in parallel:", type: :subtitle
    unless plain?
      @parallel_steps.each do |step|
        echo format_parallel_line(step[:title], :pending), type: :pending
      end
    end

    @parallel_steps.each_with_index do |step_info, idx|
      title = step_info[:title]
      command = step_info[:command]

      stdout_file = Tempfile.new(["ci_stdout_#{idx}_", ".log"])
      stderr_file = Tempfile.new(["ci_stderr_#{idx}_", ".log"])

      # Commands are defined in config/ci.rb, not user input
      pid = Process.spawn(*command, out: stdout_file.path, err: stderr_file.path, pgroup: true) # brakeman:disable:Execute

      @running_jobs << {
        pid: pid,
        index: idx,
        title: title,
        command: command,
        stdout_file: stdout_file,
        stderr_file: stderr_file,
        started_at: Time.now.to_f
      }
    end

    while @running_jobs.any?
      reaped_any = false

      @running_jobs.dup.each do |job|
        pid, status = Process.waitpid2(job[:pid], Process::WNOHANG)
        next unless pid

        reaped_any = true
        @running_jobs.delete(job)

        duration = Time.now.to_f - job[:started_at]
        success = status.success?

        completed << job.merge(success: success, duration: duration, exit_code: status.exitstatus)
        completed_by_index[job[:index]] = completed.last

        type = success ? :success : :error
        line = format_parallel_line(job[:title], type, duration: duration)
        update_parallel_line(job[:index], line, type) unless plain?

        results << [success, job[:title]]

        cleanup_job_files!(job) if success
      rescue Errno::ECHILD
        @running_jobs.delete(job)
      end

      sleep 0.1 unless reaped_any
    end

    if plain?
      @parallel_steps.each_with_index do |step, idx|
        job = completed_by_index[idx]
        type = job[:success] ? :success : :error
        echo format_parallel_line(step[:title], type, duration: job[:duration]), type: type
      end
    end

    print_parallel_summary(completed)
  ensure
    cleanup_all_jobs!
  end

  def interrupt_parallel!
    return unless defined?(@running_jobs) && @running_jobs&.any?

    @running_jobs.each do |job|
      Process.kill("TERM", -job[:pid])
    rescue Errno::ESRCH
    end

    sleep 1.0

    @running_jobs.each do |job|
      Process.kill("KILL", -job[:pid])
    rescue Errno::ESRCH
    end

    @running_jobs.each do |job|
      Process.wait(job[:pid])
    rescue Errno::ECHILD
    end

    cleanup_all_jobs!
  end

  def cleanup_job_files!(job)
    job[:stdout_file]&.close!
    job[:stderr_file]&.close!
  rescue
  end

  def cleanup_all_jobs!
    return unless defined?(@running_jobs)
    @running_jobs&.each { |job| cleanup_job_files!(job) }
  end

  def truncated_file_content(file, max_bytes: MAX_OUTPUT_BYTES)
    file.rewind
    size = file.size
    content = if size > max_bytes
      file.seek(-max_bytes, IO::SEEK_END)
      "[... truncated #{size - max_bytes} bytes ...]\n" + file.read
    else
      file.read
    end
    content.strip
  end

  private

  def print_parallel_summary(completed)
    failed_jobs = completed.reject { |j| j[:success] }
    return if failed_jobs.empty?

    echo "\n" + ("─" * 60), type: :error
    echo "Failed step output:", type: :error
    echo ("─" * 60), type: :error

    failed_jobs.each do |job|
      echo "\n┌── #{job[:title]} (exit #{job[:exit_code]})", type: :error
      echo "│   Command: #{job[:command].join(" ")}", type: :subtitle

      stdout_content = truncated_file_content(job[:stdout_file])
      stderr_content = truncated_file_content(job[:stderr_file])

      if stdout_content.empty? && stderr_content.empty?
        echo "│   (no output)", type: :subtitle
      else
        unless stdout_content.empty?
          echo "│", type: :subtitle
          echo "│   ── stdout ──", type: :subtitle
          stdout_content.each_line { |line| echo "│   #{line.chomp}", type: :subtitle }
        end

        unless stderr_content.empty?
          echo "│", type: :subtitle
          echo "│   ── stderr ──", type: :error
          stderr_content.each_line { |line| echo "│   #{line.chomp}", type: :error }
        end
      end

      echo "└" + ("─" * 59), type: :error

      cleanup_job_files!(job)
    end
  end

  def format_duration(seconds)
    min, sec = seconds.divmod(60)
    "#{"#{min.to_i}m" if min > 0}%.2fs" % sec
  end

  def format_parallel_line(title, status, duration: nil)
    indicator = parallel_indicator(status)
    if duration
      "   #{indicator} #{title} (#{format_duration(duration)})"
    else
      "   #{indicator} #{title}"
    end
  end

  def parallel_indicator(status)
    return {pending: "-", success: "OK", error: "FAIL"}[status] if plain?

    {pending: "•", success: "✅", error: "❌"}[status]
  end

  def update_parallel_line(index, text, type)
    return echo(text, type: type) if plain?

    lines_up = @parallel_steps.size - index
    print "\033[s"
    print "\033[#{lines_up}A" if lines_up > 0
    print "\r\033[2K"
    print colorize(text, type)
    print "\033[u"
  end

  def state_file_path
    File.join(Dir.pwd, STATE_FILE)
  end

  def save_failed_step(title)
    File.write(state_file_path, title)
  end

  def load_failed_step
    return nil unless File.exist?(state_file_path)
    File.read(state_file_path).strip
  end

  def clear_state
    File.delete(state_file_path) if File.exist?(state_file_path)
  end

  def timing
    started_at = Time.now.to_f
    yield
    min, sec = (Time.now.to_f - started_at).divmod(60)
    "#{"#{min}m" if min > 0}%.2fs" % sec
  end

  def colorize(text, type)
    return text if plain?

    "#{COLORS.fetch(type)}#{text}\033[0m"
  end
end
end
