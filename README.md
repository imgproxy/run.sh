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

`./run` with no arguments lists every task found in `bin/`, using each
task's `description()` for the one-line summary. Task names are derived
from the filename (`bin/deploy.sh` → `./run deploy`).

## Optional: global command

```sh
./run install-global [bash|zsh|fish] [--force]
```

Installs a `run` shell function to your shell rc file (`~/.bashrc`,
`~/.zshrc`, or `~/.config/fish/config.fish`). The function walks up from
your current directory to find the nearest run.sh project (like `git`
finds `.git`), so you can run `run <task>` from any subdirectory instead
of `../../run <task>`.

- With no argument, the shell is detected from `$SHELL`.
- Pass `bash`, `zsh`, or `fish` explicitly to override detection.
- Pass `--force` to reinstall without the "already installed" prompt (useful
  for picking up a newer version of the installed function). `--force` and
  the shell name can be given in either order, e.g. both
  `install-global --force zsh` and `install-global zsh --force` work.

The installation is idempotent — running `./run install-global` twice will
only append the function once (you'll be prompted before it's overwritten,
unless `--force` is given).

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

- `description()` — must echo a single line; shown next to the task name
  when you run `./run` with no arguments. Required — a task missing it
  fails at listing time with a clear error.
- `help()` — must print (usually via `cat <<'EOF' ... EOF'`) a usage
  message; shown by `./run help <name>`. Required.
- `main()` — the task's actual logic; receives the task's arguments as
  `"$@"`, exactly as typed after the task name (e.g. `./run deploy --env=prod`
  → `main` receives `--env=prod`). Required. Its exit code becomes `./run`'s
  exit code.

Task files are `source`d, not executed as subprocesses, so they run in the
same shell as `./run` and have access to `PROJECT_ROOT`, `TASK_DIR`, every
helper described below, and anything defined in `.runrc`.

See `examples/task.sh` for a fuller example demonstrating flags, positional
args, validation, and task composition patterns. Copy it into `bin/` and
trim it down to what you need.

## Variables and helpers

`./run` sets a few variables and provides these helpers before any task runs.
They're all defined in the "available to your tasks" section at the top of
the `run` script itself, ahead of a clearly marked divider, and named
`run::<thing>`. Everything below that divider is internal dispatch
machinery named `run::_<thing>` — tasks and `.runrc` shouldn't call it
directly.

### Variables

- **`PROJECT_ROOT`** — absolute path to the project root (the directory
  containing `./run`). Use it to build paths that don't depend on the
  caller's current working directory, e.g. `"$PROJECT_ROOT/config/app.yml"`.
- **`TASK_DIR`** — absolute path to the task directory (`$PROJECT_ROOT/bin`).

### Validation

- **`run::require_tool <cmd> <message>`** — exits the whole `./run` invocation
  with `error: <message>` on stderr if `<cmd>` is not found on `$PATH`.
  Use it at the top of a task that shells out to an external program, so a
  missing dependency fails fast with a clear message instead of a raw
  "command not found" further down.

  ```sh
  run::require_tool jq "jq is required (https://jqlang.github.io/jq/)"
  run::require_tool docker "docker is required to build images"
  ```

- **`run::require_arg <flag-name> "$value"`** — returns 1 with `error: missing
  value for <flag-name>` on stderr if `<value>` is empty. Unlike
  `run::require_tool`, it returns instead of exiting, so it composes naturally
  with manual flag parsing in `main()`:

  ```sh
  --env=*) env="${1#*=}"; shift ;;
  --env) run::require_arg --env "${2:-}"; env="$2"; shift 2 ;;
  ```

### User interaction

- **`run::prompt <color> <question> [choices]`** — prints `<question>` in
  `<color>` (any color `run::color_echo` accepts), waits for a single
  keypress (no Enter required), and echoes the matched choice to stdout.
  `choices` is a `/`-separated list, default `"y/n"`. Capitalize exactly
  one letter to make it the default, selected by pressing Enter with no
  other input. Returns 0 if the matched choice is the first one listed, 1
  otherwise — so `run::prompt cyan "..." "y/N" && do_thing` reads
  naturally as "if yes, do the thing."

  ```sh
  run::prompt cyan "Deploy to production?" "y/N" && deploy   # default: no
  if run::prompt cyan "Overwrite existing file?" "Y/n"; then ...; fi
  choice="$(run::prompt magenta "Pick one" "staging/production")"
  ```

- **`run::user_input <color> <label>`** — prints `<label>` in `<color>` and
  reads one line of free-form text from the user, echoing it to stdout.
  Use this instead of `run::prompt` when you need arbitrary text rather
  than a fixed choice.

  ```sh
  name="$(run::user_input cyan "Enter your name:")"
  echo "Hello, $name!"
  ```

### Output

- **`run::color_echo <color> <text>`** — prints `<text>` in `<color>` (no
  trailing newline), or plain `<text>` when colors are disabled. Supported
  colors: `red`, `green`, `blue`, `cyan`, `magenta`, `yellow`, `gray`, `neon`.

  ```sh
  run::color_echo green "OK"; printf '\n'
  ```

- **`run::colors_enabled`** — returns 0 when colored output should be used
  (stdout is a terminal, it supports at least 8 colors, and `NO_COLOR` is
  unset). `run::color_echo` and the `run::msg_*` helpers use this internally;
  call it yourself only if you're printing raw ANSI escapes.

- **`run::icon <name>`** — echoes the glyph for a status kind, with no trailing
  newline: `skip` → `◇`, `success` → `✓`, `error` → `✕`, `info` → `◆`,
  `warning` → `■`. This is the single source of truth for the glyphs the
  `run::msg_*` helpers print; call it directly when you want the bare glyph
  instead of a full formatted message.

  ```sh
  printf '%s deploy complete\n' "$(run::icon success)"
  run::color_echo green "$(run::icon success) done"; printf '\n'
  ```

- **`run::msg_ok <text>` / `run::msg_skip <text>` / `run::msg_info <text>` / `run::msg_warn <text>` / `run::msg_err <text>`**
  — print a status line with a colored icon (see `run::icon` above): `✓`
  (green, ok), `◇` (gray, skip), `◆` (yellow, info), `■` (yellow, warn), or
  `error:` (`run::msg_err`, uncolored). All but `run::msg_err` write to stdout;
  `run::msg_err` writes to stderr, matching `run::require_tool`/`run::require_arg`.

  ```sh
  run::require_tool git "git is required" && run::msg_ok "git found"
  [ -f dist/app ] && run::msg_skip "already built" || run::msg_info "building..."
  ```

- **`NO_COLOR`** — set this environment variable (to any non-empty value)
  to disable color output globally, regardless of terminal support.

### Composition

- **`run::depends_on <task>...`** — runs each named task in order (as
  `$PROJECT_ROOT/run <task>`), stopping and propagating the exit code at
  the first failure. Use it inside a task's `main()` to build tasks out of
  other tasks.

  ```sh
  main() { run::depends_on build test; echo "deploying..."; }
  ```

`.runrc`, if present at the project root, is sourced once before any task
runs, so helpers and variables defined there are also available to tasks.
`.runrc` is entirely optional — tasks work fine without it.

## External libraries

run.sh itself has no runtime dependencies, but your tasks can use any tool you
already have installed. Install libraries the same way you normally would
(Homebrew, apt, npm, pip, etc.) and call them from your task files.

For reusable helpers, source them from `.runrc`:

```sh
# .runrc
. "$PROJECT_ROOT/vendor/some-lib.sh"
```

Use the built-in `run::require_tool` helper to fail early with a friendly message
when a required command is missing:

```sh
main() {
  run::require_tool jq "jq is required (https://jqlang.github.io/jq/)"
  jq '.version' package.json
}
```

## Philosophy

- No external dependencies — it's bash, all the way down.
- `run` is a single file you download once and keep; your logic lives in `bin/` and
  (optionally) `.runrc`.

## License

MIT
