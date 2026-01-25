local_ci_plus is a Ruby gem that improves Rails local CI for both developers and agents by adding:

- Parallel step execution.
- Plain output for non-interactive (agent) environments.
- Fail-fast behavior.
- Resume/continue after a failed step.

## Guidance for LLMs

- Prefer clear, short output suitable for non-TTY usage.
- When documenting or examples, highlight the defaults: `bin/ci` keeps working once the gem is required.
- Emphasize that `--parallel` is incompatible with `--fail-fast` and `--continue`.
- When updating docs, keep installation, generators, manual `bin/ci` patching, test, lint, and release steps in the README.
