#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.

description() { echo "Greet a named version (positional arg + validation example)"; }

help() {
  cat <<'EOF'
Usage: ./run greet <version>
  <version>  semver-style, e.g. 1.2.3
EOF
}

main() {
  local version="${1:-}"
  if [ -z "$version" ]; then
    echo "error: missing required argument <version>" >&2
    help >&2
    return 1
  fi
  case "$version" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "error: '$version' is not a valid semver (expected X.Y.Z)" >&2; return 1 ;;
  esac
  echo "Hello, version $version!"
}
