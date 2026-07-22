#!/usr/bin/env bash
# run.sh installer — https://github.com/imgproxy/run-sh
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/imgproxy/run-sh/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/imgproxy/run-sh/main/install.sh | bash -s -- --global
#   curl -fsSL https://raw.githubusercontent.com/imgproxy/run-sh/main/install.sh | bash -s -- --examples
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

msg_ok()   { run_colors_enabled && printf '\033[32m[ok]\033[0m %s\n' "$1" || printf '[ok] %s\n' "$1"; }
msg_skip() { run_colors_enabled && printf '\033[90m[skip]\033[0m %s\n' "$1" || printf '[skip] %s\n' "$1"; }
msg_info() { run_colors_enabled && printf '\033[33m[info]\033[0m %s\n' "$1" || printf '[info] %s\n' "$1"; }
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
  for name in hello greet deploy build release; do
    fetch_template "examples/$name.sh" > "$task_dir/$name.sh"
  done
}

# --- installer flow --------------------------------------------------------

prompt_task_dir_name() {
  local project_root="$1"
  local name
  while :; do
    printf './bin already exists. Enter a different folder for tasks: ' >&2
    read -r name
    [ -z "$name" ] && continue
    case "$name" in
      */*)
        printf 'error: folder name cannot contain a path separator\n' >&2
        continue
        ;;
      .*)
        printf 'error: folder name cannot start with "."\n' >&2
        continue
        ;;
      run)
        printf 'error: "run" is reserved by the dispatcher script\n' >&2
        continue
        ;;
    esac
    if [ -e "$project_root/$name" ]; then
      printf 'error: ./%s already exists\n' "$name" >&2
      continue
    fi
    printf '%s\n' "$name"
    return
  done
}

fallback_task_dir_name() {
  local project_root="$1"
  local name="tasks" i=1
  while [ -e "$project_root/$name" ]; do
    name="tasks-$i"
    i=$((i + 1))
  done
  printf '%s\n' "$name"
}

choose_task_dir_name() {
  local project_root="$1"
  local default="bin"
  if [ ! -e "$project_root/$default" ]; then
    printf '%s\n' "$default"
    return
  fi
  if [ -t 0 ]; then
    prompt_task_dir_name "$project_root"
  else
    fallback_task_dir_name "$project_root"
  fi
}

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
  # existing dispatcher so we don't silently migrate tasks to a fallback
  # folder (e.g., when ./bin exists and the script is non-interactive).
  if [ -f "$project_root/run" ]; then
    local line
    # shellcheck disable=SC2016
    line="$(grep '^TASK_DIR="\$TASK_ROOT/' "$project_root/run" | head -n1)" || true
    # shellcheck disable=SC2016
    RUN_TASK_DIR_NAME="${line#*TASK_DIR=\"\$TASK_ROOT/}"
    RUN_TASK_DIR_NAME="${RUN_TASK_DIR_NAME%\"*}"
  fi

  if [ -z "${RUN_TASK_DIR_NAME:-}" ]; then
    RUN_TASK_DIR_NAME="$(choose_task_dir_name "$project_root")"
  fi

  local task_dir="$project_root/$RUN_TASK_DIR_NAME"

  mkdir -p "$task_dir"

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

  if [ "$RUN_INSTALL_EXAMPLES" = "1" ]; then
    local has_tasks=0
    local f name
    for f in "$task_dir"/*.sh; do
      [ -e "$f" ] || continue
      has_tasks=1
      break
    done
    if [ "$has_tasks" -eq 0 ]; then
      write_example_tasks "$task_dir"
      msg_ok "wrote example tasks: hello, greet, deploy, build, release"
    else
      msg_skip "$RUN_TASK_DIR_NAME/ already has task files, skipping --examples"
    fi
  fi

  printf '\n'
  run_gradient_text "run.sh $RUN_VERSION installed"
  printf '\n\nNext: ./run\n'
}

RUN_INSTALL_EXAMPLES=0
RUN_INSTALL_GLOBAL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --examples) RUN_INSTALL_EXAMPLES=1; shift ;;
    --global) RUN_INSTALL_GLOBAL=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [--examples] [--global]
  --examples  scaffold hello/greet/deploy/build/release example tasks if the task dir has none yet
  --global    also install the ~/.local/bin/run upward-search command
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
