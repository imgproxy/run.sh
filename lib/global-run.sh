#!/usr/bin/env bash
set -euo pipefail

find_run_root() {
  local dir="$PWD"
  while :; do
    if [ "$dir" = "$HOME" ] || [ "$dir" = "/" ]; then
      return 1
    fi
    if [ -f "$dir/run" ] && [ -f "$dir/.runrc" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    local parent
    parent="$(dirname "$dir")"
    [ "$parent" = "$dir" ] && return 1
    dir="$parent"
  done
}

root="$(find_run_root)" || {
  echo "run: no run.sh project found in this directory or its parents" >&2
  echo "run: (looked for 'run' + '.runrc', stopping at \$HOME or /)" >&2
  exit 1
}

exec "$root/run" "$@"
