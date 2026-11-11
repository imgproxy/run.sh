#!/usr/bin/env bats

setup() {
  RUN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FAKE_ROOT="$(mktemp -d)"
  FAKE_HOME="$FAKE_ROOT/home/testuser"
  mkdir -p "$FAKE_HOME"
  # Sandbox: never let a test touch the real shell rc files.
  export HOME="$FAKE_HOME"
  export SHELL=/bin/bash
}

teardown() {
  cd "$RUN_ROOT"
  rm -rf "$FAKE_ROOT"
}

# Build a project at $PROJECT with a bin/ dir and an executable copy of `run`.
# Extra args are additional directories to create.
make_project() {
  PROJECT="$FAKE_HOME/projects/app"
  mkdir -p "$PROJECT/bin" "$@"
  cp "$RUN_ROOT/run" "$PROJECT/run"
  chmod +x "$PROJECT/run"
}

@test "install-global writes a run function to ~/.bashrc" {
  make_project

  cd "$PROJECT"
  HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global >/dev/null
  [ -f "$FAKE_HOME/.bashrc" ]
  grep -qF "# >>> run.sh install-global >>>" "$FAKE_HOME/.bashrc"
  grep -q "run() {" "$FAKE_HOME/.bashrc"
}

@test "install-global reports what it detected" {
  make_project

  cd "$PROJECT"
  run env HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"detected shell: bash"* ]]
  [[ "$output" == *"target rc file:"* ]]
  [[ "$output" == *"✓ wrote run() function"* ]]
}

@test "install-global is idempotent (second run skips)" {
  make_project

  cd "$PROJECT"
  HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global >/dev/null
  run env HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"◇"* ]]
  [[ "$output" == *"already installed"* ]]

  # Verify marker appears exactly once
  local count
  count=$(grep -c "# >>> run.sh install-global >>>" "$FAKE_HOME/.bashrc")
  [ "$count" -eq 1 ]
}

@test "the sourced function finds a nested project" {
  make_project "$FAKE_HOME/projects/app/src/deep/nested"

  cat > "$PROJECT/bin/hello.sh" <<'EOF'
#!/usr/bin/env bash
description() { echo "Hello task"; }
help() { echo "Usage: ./run hello"; }
main() { echo "Hello from nested!"; }
EOF

  HOME="$FAKE_HOME" SHELL=/bin/bash "$FAKE_HOME/projects/app/run" install-global >/dev/null

  # Test within a nested subprocess to avoid shadowing bats' own run() function
  run bash -c "HOME='$FAKE_HOME' SHELL=/bin/bash; source '$FAKE_HOME/.bashrc'; cd '$FAKE_HOME/projects/app/src/deep/nested' && run hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello from nested!"* ]]
}

@test "global run reports a clean error when no project is found" {
  mkdir -p "$FAKE_HOME/empty-dir"
  HOME="$FAKE_HOME" SHELL=/bin/bash "$RUN_ROOT/run" install-global >/dev/null 2>&1 || true

  run bash -c "HOME='$FAKE_HOME' SHELL=/bin/bash; source '$FAKE_HOME/.bashrc' 2>/dev/null; cd '$FAKE_HOME/empty-dir' && run 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no run.sh project found"* ]]
}

@test "global run never matches a decoy project at or above \$HOME" {
  mkdir -p "$FAKE_HOME/bin" "$FAKE_ROOT/bin"
  touch "$FAKE_HOME/run" "$FAKE_ROOT/run"
  chmod +x "$FAKE_HOME/run" "$FAKE_ROOT/run"
  mkdir -p "$FAKE_HOME/no-project-subdir"

  HOME="$FAKE_HOME" SHELL=/bin/bash "$RUN_ROOT/run" install-global >/dev/null 2>&1 || true

  run bash -c "HOME='$FAKE_HOME' SHELL=/bin/bash; source '$FAKE_HOME/.bashrc' 2>/dev/null; cd '$FAKE_HOME/no-project-subdir' && run 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no run.sh project found"* ]]
}

# Shell matrix: each shell is detected purely from a faked $SHELL (no argument)
# and must write only its own rc file, inside the fake $HOME.
check_shell_install() {
  local shell_path="$1" rc_rel="$2" fn_pat="$3" comp_pat="$4"
  local rc all_rcs=".bashrc .zshrc .config/fish/config.fish" other

  make_project
  cd "$PROJECT"

  HOME="$FAKE_HOME" SHELL="$shell_path" ./run install-global >/dev/null </dev/null
  rc="$FAKE_HOME/$rc_rel"
  [ -f "$rc" ]
  grep -qF "# >>> run.sh install-global >>>" "$rc"
  grep -q "$fn_pat" "$rc"
  grep -q "$comp_pat" "$rc"

  for other in $all_rcs; do
    [ "$other" = "$rc_rel" ] && continue
    [ ! -e "$FAKE_HOME/$other" ]
  done
}

@test "install-global detects bash from \$SHELL (rc, function, completion)" {
  check_shell_install /bin/bash .bashrc "run() {" "complete -F _run_complete run"
}

@test "install-global detects zsh from \$SHELL (rc, function, completion)" {
  check_shell_install /bin/zsh .zshrc "run() {" "compdef _run run"
}

@test "install-global detects fish from \$SHELL (rc, function, completion)" {
  check_shell_install /usr/bin/fish .config/fish/config.fish "function run" "complete -c run"
}

@test "install-global with unsupported shell errors gracefully" {
  make_project

  cd "$PROJECT"
  run env HOME="$FAKE_HOME" SHELL=/usr/bin/ksh ./run install-global
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported"* ]]
}

@test "install-global registers tab completion for each shell" {
  make_project

  cd "$PROJECT"
  HOME="$FAKE_HOME" ./run install-global bash >/dev/null
  HOME="$FAKE_HOME" ./run install-global zsh >/dev/null
  HOME="$FAKE_HOME" ./run install-global fish >/dev/null
  grep -q "complete -F _run_complete run" "$FAKE_HOME/.bashrc"
  grep -q "compdef _run run" "$FAKE_HOME/.zshrc"
  grep -q "complete -c run" "$FAKE_HOME/.config/fish/config.fish"
}

@test "bash completion lists tasks from a nested directory" {
  make_project "$FAKE_HOME/projects/app/src"
  touch "$PROJECT/bin/deploy.sh" "$PROJECT/bin/dev.sh"

  cd "$PROJECT"
  HOME="$FAKE_HOME" ./run install-global bash >/dev/null
  cd src
  run env HOME="$FAKE_HOME" bash -c '
    source "$HOME/.bashrc"
    COMP_WORDS=(run de); COMP_CWORD=1; _run_complete
    echo "${COMPREPLY[*]}"
    COMP_WORDS=(run help ""); COMP_CWORD=2; _run_complete
    echo "${COMPREPLY[*]}"'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "deploy dev" ]
  [ "${lines[1]}" = "deploy dev" ]
}
