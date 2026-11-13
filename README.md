<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg?sanitize=true" />
    <source media="(prefers-color-scheme: light)" srcset="assets/logo-light.svg?sanitize=true" />
    <img alt="run.sh logo" title="run.sh" src="assets/logo-light.svg?sanitize=true" />
  </picture>
</h1>

`run.sh` is a task runner written in pure bash. No DSL, no runtime dependencies, no build step — just scripts.

- It's bash, all the way down.
- No runtime dependency, no build step, no framework.
- `run` is a single file you download once and keep in your repo; your task logic lives in `bin/`, entirely yours to edit.
- Optional global shell command for running tasks from any subdirectory with tab completion.
- Useful pre-defined helpers and variables for your tasks.
- Custom project-wide helpers and variables go in `.runrc`.
- Easy task composition with `run::depends_on` and `run::run_task`.

![Demo of run.sh in action](assets/demo.gif)

**Table of Contents**

- [Install](#install)
- [Usage](#usage)
  - [Optional: global command](#optional-global-command)
- [Writing tasks](#writing-tasks)
- [Variables and helpers](#variables-and-helpers)
  - [Variables](#variables)
  - [Validation](#validation)
  - [User interaction](#user-interaction)
  - [Safety checks](#safety-checks)
  - [Output](#output)
  - [Composition](#composition)
  - [Adding custom variables and helpers](#adding-custom-variables-and-helpers)
- [License](#license)

## Install

To install run.sh, simply download the `run` script and make it executable:

```sh
curl -fsSL https://raw.githubusercontent.com/imgproxy/run.sh/main/run -o run && chmod +x run
```

Then:

- Create `bin/` directory and [add task files](#writing-tasks) (one file per task, `bin/<name>.sh`).
- Optionally [create `.runrc`](#adding-custom-variables-and-helpers) for shared helpers and variables (entirely optional; sourced before any task runs if present).
- Run `./run` to list tasks, or `./run <task>` to execute a task.

> [!TIP]
> We recommend committing the `run` script to your repository so that all collaborators have it available and consistent across environments.

## Usage

```sh
./run              # list available tasks
./run <task> [args...]
./run help <task>  # show a task's help text
```

`./run` with no arguments lists every task found in `bin/`, using each task's `description()` for the one-line summary. Task names are derived from the filename (`bin/deploy.sh` → `./run deploy`).

### Optional: global command

```sh
./run install-global [bash|zsh|fish] [--force]
```

Installs a `run` shell function to your shell rc file (`~/.bashrc`, `~/.zshrc`, or `~/.config/fish/config.fish`). The function walks up from your current directory to find the nearest run.sh project (like `git` finds `.git`), so you can run `run <task>` from any subdirectory instead of `../../run <task>`.

- With no argument, the shell is detected from `$SHELL`.
- Pass `bash`, `zsh`, or `fish` explicitly to override detection.
- Pass `--force` to reinstall without the "already installed" prompt (useful for picking up a newer version of the installed function). `--force` and the shell name can be given in either order, e.g. both `install-global --force zsh` and `install-global zsh --force` work.

It also registers tab completion for `run`: task names (from the filenames in `bin/`), plus `help` and `install-global`, and task names again after `help`. Completion only globs `bin/*.sh` — it never sources your tasks, so it stays instant.

The installation is idempotent — running `./run install-global` twice will only append the function once (you'll be prompted before it's overwritten, unless `--force` is given).

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
- `main()` — the task's actual logic. Required.

  CLI arguments are passed to `main()` and can be accessed as in any bash function:
    * `$@` — all arguments passed to the task, preserving spaces and quotes.
    * `$1`, `$2`, ... — individual positional arguments.
    * `$#` — number of arguments passed.

  Its exit code becomes `./run`'s
  exit code.

Task files are not executed in a subshell, so they have access to `PROJECT_ROOT`, `TASK_DIR`, `TASK_NAME`, every helper described below, and anything defined in `.runrc`.

See `examples/task.sh` for a fuller example demonstrating flags, positional args, validation, and task composition patterns. Copy it into `bin/` and trim it down to what you need.

## Variables and helpers

`./run` sets a few variables and provides these helpers before any task runs. They're all defined in the "available to your tasks" section at the top of the `run` script itself, ahead of a clearly marked divider, and named `run::<thing>`. Everything below that divider is internal dispatch machinery named `run::_<thing>` — tasks and `.runrc` shouldn't call it directly.

### Variables

- **`PROJECT_ROOT`** — absolute path to the project root (the directory containing `./run`). Use it to build paths that don't depend on the caller's current working directory, e.g. `"$PROJECT_ROOT/config/app.yml"`.
- **`TASK_DIR`** — absolute path to the task directory (`$PROJECT_ROOT/bin`).
- **`TASK_NAME`** — name of the task being run or sourced (`bin/<name>.sh` → `<name>`). Not set while `.runrc` is sourced.

### Validation

- **`run::require_tool <cmd> <message>`** — exits the whole `./run` invocation with `error: <message>` on stderr if `<cmd>` is not found on `$PATH`. Use it at the top of a task that shells out to an external program, so a missing dependency fails fast with a clear message instead of a raw "command not found" further down.

  ```sh
  run::require_tool jq "jq is required (https://jqlang.github.io/jq/)"
  run::require_tool docker "docker is required to build images"
  ```

- **`run::require_arg <flag-name> "$value"`** — returns 1 with `error: missing value for <flag-name>` on stderr if `<value>` is empty. Unlike `run::require_tool`, it returns instead of exiting, so it composes naturally with manual flag parsing in `main()`:

  ```sh
  --env=*) env="${1#*=}"; shift ;;
  --env) run::require_arg --env "${2:-}"; env="$2"; shift 2 ;;
  ```

### User interaction

- **`run::prompt <color> <question> [choices]`** — single-keypress prompt. Prints `<question>` in `<color>`, waits for one key (no Enter needed), and echoes the matched choice to stdout.
  - `choices` is a `/`-separated list of single letters, default `"y/n"`. Capitalize one letter to make it the default (picked by pressing Enter).
  - An unmatched key is ignored — no error, just waits for another keypress.
  - **2-way choices (`y/n`-style):** the exit code doubles as the answer — 0 if the match is the first-listed choice, 1 otherwise. That's what lets `run::prompt cyan "..." "y/N" && do_thing` read as "if yes, do the thing," with no need to capture or compare stdout.
  - **3+-way choices:** the exit code still follows the same rule (0 only for the first-listed choice) but isn't meaningful here — you have three-plus outcomes to distinguish, not two. Capture stdout and switch on it instead. Tasks run under `set -e`, so guard the capture with `|| true`; otherwise a non-first pick returns 1 and aborts the task before the `case` runs.

  ```sh
  run::prompt cyan "Deploy to production?" "y/N" && deploy   # default: no
  if run::prompt cyan "Overwrite existing file?" "Y/n"; then ...; fi

  choice="$(run::prompt magenta "Deploy to: (s)taging/(p)roduction/(c)anary" "s/p/c")" || true
  case "$choice" in
    s) ... ;;
    p) ... ;;
    c) ... ;;
  esac
  ```

- **`run::user_input <color> <label>`** — prints `<label>` in `<color>` and reads one line of free-form text from the user, echoing it to stdout. Use this instead of `run::prompt` when you need arbitrary text rather than a fixed choice.

  ```sh
  name="$(run::user_input cyan "Enter your name:")"
  echo "Hello, $name!"
  ```

### Safety checks

- **`run::friday_deploy`** — extra confirmation gate for deploy-like tasks. If today is Friday, Saturday, or Sunday, shows a colored warning banner and requires an explicit "REALLY sure?" confirmation before continuing (returns 1 if declined). Any other day, it's a silent no-op that returns 0 immediately.

  ```sh
  main() {
    run::friday_deploy || return 1
    run::depends_on build test
    echo "deploying..."
  }
  ```

### Output

- **`run::color_echo <color> <text>`** — prints `<text>` in `<color>` (no trailing newline), or plain `<text>` when colors are disabled. Supported colors: `red`, `green`, `blue`, `cyan`, `magenta`, `yellow`, `gray`, `neon`.

  ```sh
  run::color_echo green "OK"; printf '\n'
  ```

- **`run::colors_enabled`** — returns 0 when colored output should be used (stdout is a terminal, it supports at least 8 colors, and `NO_COLOR` is unset). `run::color_echo` and the `run::msg_*` helpers use this internally; call it yourself only if you're printing raw ANSI escapes.

- **`run::icon <name>`** — echoes the glyph for a status kind, with no trailing newline: `skip` → `◇`, `success` → `✓`, `error` → `✕`, `info` → `◆`, `warning` → `■`. This is the single source of truth for the glyphs the `run::msg_*` helpers print; call it directly when you want the bare glyph instead of a full formatted message.

  ```sh
  printf '%s deploy complete\n' "$(run::icon success)"
  run::color_echo green "$(run::icon success) done"; printf '\n'
  ```

- **`run::msg_ok <text>` / `run::msg_skip <text>` / `run::msg_info <text>` / `run::msg_warn <text>` / `run::msg_err <text>`** — print a status line with a colored icon (see `run::icon` above): `✓` (green, ok), `◇` (gray, skip), `◆` (yellow, info), `■` (yellow, warn), or `error:` (`run::msg_err`, uncolored). All but `run::msg_err` write to stdout; `run::msg_err` writes to stderr, matching `run::require_tool`/`run::require_arg`.

  ```sh
  run::require_tool git "git is required" && run::msg_ok "git found"
  [ -f dist/app ] && run::msg_skip "already built" || run::msg_info "building..."
  ```

- **`NO_COLOR`** — set this environment variable (to any non-empty value) to disable color output globally, regardless of terminal support.

### Composition

- **`run::run_task <task> [args...]`** — runs the named task with the given arguments in a subshell. Use it inside a task's `main()` to invoke other tasks.

  ```sh
  main() {
    run::run_task build -o /tmp/my_bin
    /tmp/my_bin
  }
  ```

- **`run::depends_on <task>...`** — runs each named task in order (as `run::run_task <task>`), stopping and propagating the exit code at the first failure. Use it inside a task's `main()` to build tasks out of other tasks.

  ```sh
  main() { run::depends_on build test; echo "deploying..."; }
  ```

### Adding custom variables and helpers

If you want to define shared variables or helper functions for your tasks, you can do so in a `.runrc` file at the project root. If present, it will be sourced before any task runs. It is entirely optional, and tasks will work fine without it.

```sh
# .runrc
export MY_SHARED_VARIABLE="value"
my_helper() {
  echo "This is a helper function"
}

# Task file
main() {
  echo "Using shared variable: $MY_SHARED_VARIABLE"
  my_helper
}
```

It's also a good place to load external libraries or other shared scripts that your tasks might depend on:

```sh
# .runrc
. "$PROJECT_ROOT/vendor/some-lib.sh"
```

## License

run.sh is licensed under the MIT License.

See [LICENSE](LICENSE) for the full license text.
