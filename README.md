> [!CAUTION]
> This is work in progress, use on your own risk.

# run.sh

A Makefile replacement written in pure bash. No DSL, no runtime dependencies,
no build step — just scripts.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/imgproxy/run.sh/main/run -o run && chmod +x run
```

This downloads the task dispatcher. Then:

- Create `bin/` directory and add task files (one file per task, `bin/<name>.sh`).
- Optionally create `.runrc` for shared helpers and variables (entirely optional; sourced before any task runs if present).
- Run `./run` to list tasks, or `./run <task>` to execute a task.

## Usage

```sh
./run              # list available tasks
./run <task> [args...]
./run help <task>  # show a task's help text
```

## Optional: global command

```sh
./run install-global
```

Installs a `run` shell function to your shell rc file (`~/.bashrc`, `~/.zshrc`,
or `~/.config/fish/config.fish`, depending on `$SHELL`). The function walks
up from your current directory to find the nearest run.sh project (like `git`
finds `.git`), so you can run `run <task>` from any subdirectory instead of
`../../run <task>`.

The installation is idempotent — running `./run install-global` twice will
only append the function once.

## Writing tasks

A task is a file at `bin/<name>.sh` defining three functions:

```sh
#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.

description() { echo "One-line summary shown in ./run's task list"; }

help() {
  cat <<'EOF'
Usage: ./run <name> [args...]
EOF
}

main() {
  echo "task logic goes here, receives \"\$@\""
}
```

See `examples/task.sh` for a fuller example demonstrating flags, positional
args, validation, and task composition patterns. Copy it into `bin/` and
trim it down to what you need.

## Variables and helpers

`./run` sets a few variables and provides these helpers before any task runs:

- `PROJECT_ROOT` — absolute path to the project root (the directory containing `./run`).
- `TASK_DIR` — absolute path to the task directory (`$PROJECT_ROOT/bin`).
- `require_tool <cmd> <message>` — exit with a friendly error if `<cmd>` is not on `PATH`.
- `require_arg <flag-name> "$value"` — fail if a required flag value is missing.
- `prompt <question> [choices]` — print a colored question with `choices` (default `y/n`) and wait for a single keypress (no Enter needed); prints the chosen letter and returns 0 on a match, 1 otherwise. Capitalize one letter to make it the default, selected by pressing Enter, e.g. `prompt "Deploy?" "y/N"`.
- `user_input <label>` — print a colored label and wait for user input; outputs the input value.
- `depends_on <task>...` — run the named tasks in order and stop at the first failure.
- `run_color_echo <color> <text>` — print colored text (when the terminal supports it).
- `NO_COLOR` — set this environment variable to disable color output globally.

`.runrc`, if present at the project root, is sourced once before any task runs, so
helpers and variables defined there are also available to tasks. `.runrc` is entirely
optional — tasks work fine without it.

## Dependencies

Compose tasks with `depends_on` inside a task's `main()`:

```sh
main() {
  depends_on build test
  echo "deploying..."
}
```

`depends_on` runs each named task in order and stops at the first failure.

## External libraries

run.sh itself has no runtime dependencies, but your tasks can use any tool you
already have installed. Install libraries the same way you normally would
(Homebrew, apt, npm, pip, etc.) and call them from your task files.

For reusable helpers, source them from `.runrc`:

```sh
# .runrc
. "$PROJECT_ROOT/vendor/some-lib.sh"
```

Use the built-in `require_tool` helper to fail early with a friendly message
when a required command is missing:

```sh
main() {
  require_tool jq "jq is required (https://jqlang.github.io/jq/)"
  jq '.version' package.json
}
```

## Philosophy

- No external dependencies — it's bash, all the way down.
- `run` is a single file you download once and keep; your logic lives in `bin/` and
  (optionally) `.runrc`.

## License

MIT
