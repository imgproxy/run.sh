#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.

description() { echo "Show help for a task"; }

help() {
  cat <<'EOF'
Usage: ./run help <task>
Show the help text for <task>.
EOF
}

main() {
  local task="${1:-}"
  if [ -z "$task" ]; then
    echo "error: missing task name" >&2
    help >&2
    return 1
  fi
  if [ ! -f "$TASK_DIR/$task.sh" ]; then
    echo "error: unknown task '$task'" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  . "$TASK_DIR/$task.sh"
  help
}
