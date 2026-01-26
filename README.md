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

```
-f, --fail-fast   Stop immediately when a step fails
-c, --continue    Resume from the last failed step
-fc, -cf          Combine fail-fast and continue
-p, --parallel    Run all steps concurrently
--plain           Disable ANSI cursor updates/colors (also used for non-TTY)
-h, --help        Show this help

Compatibility:
  --parallel cannot be combined with --fail-fast or --continue
```

## Development

Run tests:

```bash
bundle exec ruby -Itest test/continuous_integration_test.rb
```

Run linting:

```bash
bundle exec standardrb
```

## Publishing

### One-time setup (RubyGems)

1. Create a RubyGems account if you do not have one.
2. Add your API key:

```bash
mkdir -p ~/.gem
printf "---\n:rubygems_api_key: YOUR_KEY\n" > ~/.gem/credentials
chmod 0600 ~/.gem/credentials
```

### Initial release

1. Update `local_ci_plus.gemspec` with the real `authors`, `email`, `homepage`, and `license`.
2. Build the gem:

```bash
gem build local_ci_plus.gemspec
```

3. Push to RubyGems:

```bash
gem push local_ci_plus-0.1.0.gem
```

### Updates

1. Bump the version in `lib/local_ci_plus/version.rb`.
2. Build and push:

```bash
gem build local_ci_plus.gemspec
gem push local_ci_plus-X.Y.Z.gem
```
