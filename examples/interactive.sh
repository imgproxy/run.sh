#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.
# Example task demonstrating interactive input with prompt and user_input.

description() { echo "Interactive task demonstrating user input"; }

help() {
  cat <<'EOF'
Usage: ./run interactive

Demonstrates prompt() and user_input() helpers for interactive tasks.
EOF
}

main() {
  if prompt "Do you want to continue?"; then
    name=$(user_input "Enter your name: ")
    age=$(user_input "Enter your age: ")

    echo "Hello, $name! You are $age years old."

    if prompt "Save this information?" "y/N"; then
      echo "Information saved."
    else
      echo "Cancelled."
    fi
  else
    echo "Aborted."
    return 1
  fi
}
