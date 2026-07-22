#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.

description() { echo "Run build and hello in order (depends_on example)"; }

help() {
  cat <<'EOF'
Usage: ./run release
EOF
}

main() { depends_on build hello; }
