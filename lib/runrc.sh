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

# --- terminal color/gradient helpers (used by ./run and available to tasks) ---

run_colors_enabled() {
  [ -n "${NO_COLOR:-}" ] && return 1
  [ -t 1 ] || return 1
  local n
  n="$(tput colors 2>/dev/null || echo 0)"
  [ "$n" -ge 8 ] 2>/dev/null
}

run_gradient_text() {
  local text="$1"
  if ! run_colors_enabled; then
    printf '%s' "$text"
    return
  fi
  local ncolors
  ncolors="$(tput colors 2>/dev/null || echo 0)"
  if [ "$ncolors" -lt 256 ]; then
    printf '%s%s%s' "$(tput bold)" "$text" "$(tput sgr0)"
    return
  fi
  local i=0 len=${#text} start=63 end=201
  local span=$((end - start))
  while [ "$i" -lt "$len" ]; do
    local ch="${text:$i:1}"
    local denom=$((len > 1 ? len - 1 : 1))
    local color=$((start + (span * i) / denom))
    printf '\033[38;5;%sm%s' "$color" "$ch"
    i=$((i + 1))
  done
  printf '%s' "$(tput sgr0)"
}
