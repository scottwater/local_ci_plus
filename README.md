# local_ci_plus

local_ci_plus improves Rails local CI for both developers and agents with parallel execution, fail-fast,
resume, and plain output.

https://github.com/user-attachments/assets/cf8d8c01-ddee-4154-bdb3-0a77cb5c1f53

## Installation

Add to your Gemfile:

```ruby
gem "local_ci_plus"
```

Then run:

```bash
bundle install
```

## Usage

`local_ci_plus` overrides `ActiveSupport::ContinuousIntegration` when it is loaded, so the default Rails `bin/ci`
continues to work without changes. In plain/non-TTY mode, output is ASCII-only.

```bash
bin/ci
```

If your app does not already require the gem in `bin/ci`, run the installer generator:

```bash
bin/rails generate local_ci_plus:install
```

If you already have a `bin/ci` and want to patch it in place, run:

```bash
bin/rails generate local_ci_plus:update
```

If you want to edit `bin/ci` manually, add `require "local_ci_plus"` right after the boot file:

```ruby
#!/usr/bin/env ruby
require_relative "../config/boot"
require "local_ci_plus"
require_relative "../config/ci"
```

### Options

Runs all CI steps in parallel by default.

```
-f, --fail-fast   Stop immediately when a step fails (runs inline)
-c, --continue    Resume from the last failed step (runs inline)
-fc, -cf          Combine fail-fast and continue
-i, --inline      Run steps sequentially instead of parallel
--plain           Disable ANSI cursor updates/colors (also used for non-TTY)
-h, --help        Show this help
```

### State file

By default, the first failing step is stored in `tmp/ci_state`. Set `CI_STATE_FILE` to override the path. To reset the resume point, delete the file.

## Development

Run tests:

```bash
bundle exec ruby -Itest test/continuous_integration_test.rb
```

Run linting:

```bash
bundle exec standardrb
```

Or run them both:

```bash
bin/ci
```

### Publishing Updates

1. Bump the version in `lib/local_ci_plus/version.rb`.
2. Build and push:

```bash
gem build local_ci_plus.gemspec
gem push local_ci_plus-X.Y.Z.gem
```

## Prior Work

This  project is based off of ActiveSupport::ContinuousIntegration. 

Many thanks to the Rails team for shipping the original work.
