#!/usr/bin/env bash
# run.sh global command installer — https://github.com/imgproxy/run-sh
#
# Installs a `run` command to ~/.local/bin that, when run from any
# subdirectory of a run.sh project, walks up to find the project root (like
# `git` finds `.git`) and execs its `run` with all passed arguments.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/imgproxy/run-sh/main/global/install-global.sh | bash
#
# For local development/testing, set RUN_SH_ROOT to the repo root so the
# template is read from disk instead of curled from GitHub.
set -euo pipefail

RUN_TEMPLATE_BASE_URL="${RUN_TEMPLATE_BASE_URL:-https://raw.githubusercontent.com/imgproxy/run-sh/main}"

run_colors_enabled() {
  [ -n "${NO_COLOR:-}" ] && return 1
  [ -t 1 ] || return 1
  local n
  n="$(tput colors 2>/dev/null || echo 0)"
  [ "$n" -ge 8 ] 2>/dev/null
}

msg_ok()   { run_colors_enabled && printf '\033[32m[ok]\033[0m %s\n' "$1" || printf '[ok] %s\n' "$1"; }
msg_info() { run_colors_enabled && printf '\033[33m[info]\033[0m %s\n' "$1" || printf '[info] %s\n' "$1"; }

fetch_template() {
  local name="$1"
  if [ -n "${RUN_SH_ROOT:-}" ]; then
    cat "$RUN_SH_ROOT/lib/$name"
  else
    curl -fsSL "$RUN_TEMPLATE_BASE_URL/lib/$name"
  fi
}

mkdir -p "$HOME/.local/bin"
fetch_template global-run.sh > "$HOME/.local/bin/run"
chmod +x "$HOME/.local/bin/run"
msg_ok "wrote $HOME/.local/bin/run"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *)
    cat >&2 <<EOF

run: ~/.local/bin is not on your PATH.
Add this line to your shell profile (~/.zshrc, ~/.bashrc, etc.):

  export PATH="\$HOME/.local/bin:\$PATH"

Then restart your shell or run: source ~/.zshrc
EOF
    ;;
esac

msg_info "run 'run <task>' from anywhere inside a run.sh project"
