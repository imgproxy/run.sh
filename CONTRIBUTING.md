# Contributing

## Dev setup

```sh
brew install shellcheck bats-core
```

(On Linux: `apt-get install shellcheck bats`.)

## Running checks

```sh
shellcheck run examples/*.sh
bats test/
```

Both also run in CI (`.github/workflows/ci.yml`) on Ubuntu and macOS.

## Manual smoke test

Useful for a quick sanity check without the full bats suite, and for
eyeballing colored output (bats captures stdout non-interactively, so it
never exercises the color code paths):

```sh
mkdir -p /tmp/run-smoke && cd /tmp/run-smoke
cp /path/to/run-sh/run .
chmod +x run
mkdir bin && cp /path/to/run-sh/examples/task.sh bin/task.sh
./run
./run task 1.2.3 --dry-run
./run help task
./run install-global
```

## Design notes

- Target bash is 3.2 (stock macOS) — avoid associative arrays, `${var,,}`,
  `mapfile`, and other bash-4+ features.
- Avoid `content="$(cat <<'EOF' ... EOF)"`-style captures when the heredoc
  body contains literal parentheses (e.g., fish function definitions with
  `(pwd)`). That pattern breaks on bash 3.2 — bash's `$(...)` parser scans
  the heredoc body for paren balance even though the delimiter is quoted,
  and throws a spurious syntax error. Instead, write directly to a file via
  `cat <<'EOF' >> file` (direct redirect, no capture). This is the pattern
  used in `cmd_install_global`; keep it in mind if you add more heredocs.
- `.runrc` sits at the project root, separate from task files in `bin/`, so
  the task-listing glob and task dispatch never need to skip an env file.
