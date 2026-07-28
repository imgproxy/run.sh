#!/usr/bin/env bash
# Sourced by ./run — do not execute directly.
# Example task demonstrating interactive input with run::prompt and run::user_input.

description() { echo "Interactive task demonstrating user input"; }

help() {
  cat <<'EOF'
Usage: ./run interactive

Demonstrates run::prompt() and run::user_input() helpers for interactive tasks.
EOF
}

main() {
  if run::prompt cyan "Do you want to continue?"; then
    name=$(run::user_input cyan "Enter your name: ")
    age=$(run::user_input cyan "Enter your age: ")

    echo "Hello, $name! You are $age years old."

    if run::prompt cyan "Save this information?" "y/N"; then
      echo "Information saved."
    else
      echo "Cancelled."
    fi
  else
    echo "Aborted."
    return 1
  fi
}
