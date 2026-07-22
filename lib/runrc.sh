#!/usr/bin/env bash
# .runrc — sourced once by ./run before any task executes.
# This file is yours: re-running install.sh will NOT overwrite it.
# shellcheck disable=SC2034  # some names here are consumed only by sourced task files

# Usage: require_arg <flag-name> "$value"
require_arg() {
  local name="$1" value="${2:-}"
  if [ -z "$value" ]; then
    echo "error: missing value for $name" >&2
    return 1
  fi
}

# --- terminal color helpers (used by ./run and available to tasks) ---

run_colors_enabled() {
  [ -n "${NO_COLOR:-}" ] && return 1
  [ -t 1 ] || return 1
  local n
  n="$(tput colors 2>/dev/null || echo 0)"
  [ "$n" -ge 8 ] 2>/dev/null
}

run_color_echo() {
  local color="$1" text="$2"
  if ! run_colors_enabled; then
    printf '%s' "$text"
    return
  fi
  local ncolors
  ncolors="$(tput colors 2>/dev/null || echo 0)"
  if [ "$ncolors" -ge 256 ]; then
    case "$color" in
      red)     printf '\033[38;5;196m%s' "$text" ;;
      green)   printf '\033[38;5;34m%s'  "$text" ;;
      blue)    printf '\033[38;5;21m%s'  "$text" ;;
      cyan)    printf '\033[38;5;45m%s'  "$text" ;;
      magenta) printf '\033[38;5;201m%s' "$text" ;;
      neon)    printf '\033[38;5;82m%s'  "$text" ;;
      *)       printf '%s' "$text" ;;
    esac
  else
    case "$color" in
      red)     printf '\033[31m%s'  "$text" ;;
      green)   printf '\033[32m%s'  "$text" ;;
      blue)    printf '\033[34m%s'  "$text" ;;
      cyan)    printf '\033[36m%s'  "$text" ;;
      magenta) printf '\033[35m%s'  "$text" ;;
      neon)    printf '\033[1;32m%s' "$text" ;;
      *)       printf '%s' "$text" ;;
    esac
  fi
  printf '%s' "$(tput sgr0)"
}
