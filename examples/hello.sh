#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.

description() { echo "Print a friendly greeting (no arguments)"; }

help() {
  cat <<'EOF'
Usage: ./run hello
Prints a friendly greeting. The simplest possible task.
EOF
}

main() { echo "Hello from run.sh!"; }
