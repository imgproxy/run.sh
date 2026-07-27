#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.
# Copy this file into bin/<name>.sh and trim it down to what you need.

description() { echo "Example task demonstrating flags, args, and composition"; }

help() {
  cat <<'EOF'
Usage: ./run deploy [--env=<name>] [--dry-run] [POSITIONAL_ARG]

  --env=<name>   deployment environment (staging, production, etc.)
  --env <name>   alternative form for the --env flag
  --dry-run      show what would happen without actually doing it
  POSITIONAL_ARG example positional argument (required in this example)
EOF
}

main() {
  local env="staging" dry_run=0 version=""

  # Parse flags.
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

  # Require positional arg (example of validation).
  version="${1:-}"
  if [ -z "$version" ]; then
    echo "error: missing required argument VERSION (e.g. 1.2.3)" >&2
    help >&2
    return 1
  fi

  # Validate semver format (example pattern from greet.sh).
  case "$version" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "error: '$version' is not a valid semver (expected X.Y.Z)" >&2; return 1 ;;
  esac

  # Optionally require a tool (uncomment if needed).
  # require_tool docker "docker is required (https://docker.com)"

  # Optionally depend on other tasks (uncomment if needed).
  # depends_on build test

  # Execute.
  if [ "$dry_run" -eq 1 ]; then
    echo "[dry-run] would deploy version $version to $env"
  else
    echo "deploying version $version to $env"
  fi
}
