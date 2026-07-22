#!/usr/bin/env bash
# run.sh installer — https://github.com/imgproxy/run-sh
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/imgproxy/run-sh/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/imgproxy/run-sh/main/install.sh | bash -s -- -g
#   curl -fsSL https://raw.githubusercontent.com/imgproxy/run-sh/main/install.sh | bash -s -- -e
#
# For local development/testing, set RUN_SH_ROOT to the repo root so templates
# are read from disk instead of curled from GitHub.
set -euo pipefail

RUN_VERSION="0.1.0"
RUN_TEMPLATE_BASE_URL="${RUN_TEMPLATE_BASE_URL:-https://raw.githubusercontent.com/imgproxy/run-sh/main}"

# --- output helpers (private installer copy) --------------------------------

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

msg_ok()   { run_colors_enabled && printf '\033[32m[ok]\033[0m %s\n' "$1" || printf '[ok] %s\n' "$1"; }
msg_skip() { run_colors_enabled && printf '\033[90m[skip]\033[0m %s\n' "$1" || printf '[skip] %s\n' "$1"; }
msg_info() { run_colors_enabled && printf '\033[33m[info]\033[0m %s\n' "$1" || printf '[info] %s\n' "$1"; }
msg_warn() { run_colors_enabled && printf '\033[33m[warn]\033[0m %s\n' "$1" || printf '[warn] %s\n' "$1"; }
msg_err()  { printf 'error: %s\n' "$1" >&2; }

# --- template fetching ------------------------------------------------------

fetch_template() {
  local name="$1"
  if [ -n "${RUN_SH_ROOT:-}" ]; then
    cat "$RUN_SH_ROOT/lib/$name"
  else
    curl -fsSL "$RUN_TEMPLATE_BASE_URL/lib/$name"
  fi
}

render_run_file() {
  local content
  content="$(fetch_template run.sh)"
  content="${content//__RUN_VERSION__/$RUN_VERSION}"
  content="${content//__RUN_GENERATED_AT__/$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  content="${content//__RUN_TASK_DIR_NAME__/$RUN_TASK_DIR_NAME}"
  printf '%s\n' "$content"
}

write_runrc() {
  fetch_template runrc.sh > "$1"
}

render_global_run() {
  fetch_template global-run.sh
}

write_example_tasks() {
  local task_dir="$1"
  local name
  for name in hello greet deploy build release help; do
    fetch_template "examples/$name.sh" > "$task_dir/$name.sh"
  done
}

task_dir_has_contents() {
  local dir="$1" f
  [ -e "$dir" ] || return 1
  [ -d "$dir" ] || return 0
  for f in "$dir"/.* "$dir"/*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    case "$f" in
      "$dir/."|"$dir/..") continue ;;
    esac
    return 0
  done
  return 1
}

# --- installer flow --------------------------------------------------------

install_global() {
  mkdir -p "$HOME/.local/bin"
  render_global_run > "$HOME/.local/bin/run"
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
}

install_local() {
  local project_root="$PWD"

  # On re-install, preserve the task directory already recorded in the
  # existing dispatcher so we don't silently migrate tasks to a new folder.
  if [ -f "$project_root/run" ]; then
    local line
    # shellcheck disable=SC2016
    line="$(grep '^TASK_DIR="\$PROJECT_ROOT/' "$project_root/run" | head -n1)" || true
    # shellcheck disable=SC2016
    RUN_TASK_DIR_NAME="${line#*TASK_DIR=\"\$PROJECT_ROOT/}"
    RUN_TASK_DIR_NAME="${RUN_TASK_DIR_NAME%\"*}"
  fi

  if [ -z "${RUN_TASK_DIR_NAME:-}" ]; then
    RUN_TASK_DIR_NAME="bin"
  fi

  local task_dir="$project_root/$RUN_TASK_DIR_NAME"

  if task_dir_has_contents "$task_dir"; then
    msg_warn "$RUN_TASK_DIR_NAME/ is not empty, skipping creation and example tasks"
  else
    mkdir -p "$task_dir"
    if [ "$RUN_INSTALL_EXAMPLES" = "1" ]; then
      write_example_tasks "$task_dir"
      msg_ok "wrote example tasks: hello, greet, deploy, build, release, help"
    fi
  fi

  if [ -f "$project_root/.runrc" ]; then
    msg_skip ".runrc already exists, leaving it alone"
  else
    write_runrc "$project_root/.runrc"
    msg_ok "wrote .runrc"
  fi

  local rendered tmp_new
  rendered="$(render_run_file)"
  tmp_new="$(mktemp)"
  printf '%s' "$rendered" > "$tmp_new"

  if [ -f "$project_root/run" ]; then
    local tmp_old_stripped tmp_new_stripped
    tmp_old_stripped="$(mktemp)"
    tmp_new_stripped="$(mktemp)"
    grep -v '^# Generated by run.sh ' "$project_root/run" > "$tmp_old_stripped" || true
    grep -v '^# Generated by run.sh ' "$tmp_new" > "$tmp_new_stripped" || true
    if cmp -s "$tmp_old_stripped" "$tmp_new_stripped"; then
      msg_skip "run is already up to date"
    else
      cp "$project_root/run" "$project_root/run.bak"
      msg_info "existing run differs from the generated version, backed up to run.bak"
      cp "$tmp_new" "$project_root/run"
      chmod +x "$project_root/run"
      msg_ok "wrote run"
    fi
    rm -f "$tmp_old_stripped" "$tmp_new_stripped"
  else
    cp "$tmp_new" "$project_root/run"
    chmod +x "$project_root/run"
    msg_ok "wrote run"
  fi
  rm -f "$tmp_new"

  printf '\n'
  run_color_echo neon "run.sh $RUN_VERSION installed"
  printf '\n\nNext: ./run\n'
}

RUN_INSTALL_EXAMPLES=0
RUN_INSTALL_GLOBAL=0

while [ $# -gt 0 ]; do
  case "$1" in
    -e|--examples) RUN_INSTALL_EXAMPLES=1; shift ;;
    -g|--global)   RUN_INSTALL_GLOBAL=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [-e] [-g]
  -e  scaffold hello/greet/deploy/build/release example tasks when the task dir is empty
  -g  also install the ~/.local/bin/run upward-search command
EOF
      exit 0
      ;;
    *) msg_err "unknown option: $1"; exit 1 ;;
  esac
done

install_local

if [ "$RUN_INSTALL_GLOBAL" -eq 1 ]; then
  printf '\n'
  install_global
fi
