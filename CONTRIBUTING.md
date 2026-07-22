# Contributing

## Dev setup

```sh
brew install shellcheck bats-core
```

(On Linux: `apt-get install shellcheck bats`.)

## Running checks

```sh
shellcheck install.sh global/install-global.sh examples/*.sh
bats test/
```

Both also run in CI (`.github/workflows/ci.yml`) on Ubuntu and macOS.

## Manual smoke test

Useful for a quick sanity check without the full bats suite, and for
eyeballing colored output (bats captures stdout non-interactively, so it
never exercises the gradient/color code paths):

```sh
mkdir -p /tmp/run-smoke && cd /tmp/run-smoke
bash /path/to/run-sh/install.sh --examples
./run
./run hello
```

## Design notes

- Target bash is 3.2 (stock macOS) — avoid associative arrays, `${var,,}`,
  `mapfile`, and other bash-4+ features.
- `render_run_file` writes its heredoc straight to a temp file rather than
  capturing it via `content="$(cat <<'EOF' ... EOF)"`. That pattern breaks
  on bash 3.2 when the heredoc body contains literal, non-nested-looking
  parentheses (e.g. `(use --force to overwrite)`) — bash's `$(...)` parser
  scans the heredoc body for paren balance even though the delimiter is
  quoted, and throws a spurious syntax error. Writing to a file first and
  reading it back via `$(<file)` sidesteps this entirely. Keep this in
  mind if you add more `$(cat <<'EOF' ...)`-style captures.
- `.runrc` sits at the project root, separate from task files in the
  configured task directory (default `bin/`), so every place that globs
  `<task-dir>/*.sh` (the task list, the `--examples` has-tasks check, task
  dispatch) no longer needs to skip an env file.
