#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.

description() { echo "Example flag parsing (--env, --dry-run, passthrough args)"; }

help() {
  cat <<'EOF'
Usage: ./run deploy [--env=<name>] [--dry-run] [-- <extra args>]
EOF
}

main() {
  local env="staging" dry_run=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --env=*) env="${1#*=}"; shift ;;
      --env) require_arg --env "${2:-}"; env="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      --) shift; break ;;
      -*) echo "error: unknown flag $1" >&2; return 1 ;;
      *) break ;;
    esac
  done
  if [ "$dry_run" -eq 1 ]; then
    echo "[dry-run] would deploy to $env with args: $*"
  else
    echo "deploying to $env with args: $*"
  fi
}
