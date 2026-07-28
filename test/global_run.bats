#!/usr/bin/env bats

setup() {
  RUN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FAKE_ROOT="$(mktemp -d)"
  FAKE_HOME="$FAKE_ROOT/home/testuser"
  mkdir -p "$FAKE_HOME"
}

teardown() {
  cd "$RUN_ROOT"
  rm -rf "$FAKE_ROOT"
}

@test "install-global writes a run function to ~/.bashrc" {
  mkdir -p "$FAKE_HOME/projects/app"
  cp "$RUN_ROOT/run" "$FAKE_HOME/projects/app/run"
  chmod +x "$FAKE_HOME/projects/app/run"
  mkdir "$FAKE_HOME/projects/app/bin"

  cd "$FAKE_HOME/projects/app"
  HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global >/dev/null
  [ -f "$FAKE_HOME/.bashrc" ]
  grep -qF "# >>> run.sh install-global >>>" "$FAKE_HOME/.bashrc"
  grep -q "run() {" "$FAKE_HOME/.bashrc"
}

@test "install-global reports what it detected" {
  mkdir -p "$FAKE_HOME/projects/app/bin"
  cp "$RUN_ROOT/run" "$FAKE_HOME/projects/app/run"
  chmod +x "$FAKE_HOME/projects/app/run"

  cd "$FAKE_HOME/projects/app"
  run env HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global
  [ "$status" -eq 0 ]
  [[ "$output" == *"detected shell: bash"* ]]
  [[ "$output" == *"target rc file:"* ]]
  [[ "$output" == *"✓ wrote run() function"* ]]
}

@test "install-global is idempotent (second run skips)" {
  mkdir -p "$FAKE_HOME/projects/app/bin"
  cp "$RUN_ROOT/run" "$FAKE_HOME/projects/app/run"
  chmod +x "$FAKE_HOME/projects/app/run"

  cd "$FAKE_HOME/projects/app"
  HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global >/dev/null
  run env HOME="$FAKE_HOME" SHELL=/bin/bash ./run install-global
  [ "$status" -eq 0 ]
  [[ "$output" == *"◇"* ]]
  [[ "$output" == *"already installed"* ]]

  # Verify marker appears exactly once
  local count
  count=$(grep -c "# >>> run.sh install-global >>>" "$FAKE_HOME/.bashrc")
  [ "$count" -eq 1 ]
}

@test "the sourced function finds a nested project" {
  mkdir -p "$FAKE_HOME/projects/app/src/deep/nested"
  cp "$RUN_ROOT/run" "$FAKE_HOME/projects/app/run"
  chmod +x "$FAKE_HOME/projects/app/run"
  mkdir "$FAKE_HOME/projects/app/bin"

  cat > "$FAKE_HOME/projects/app/bin/hello.sh" <<'EOF'
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

@test "install-global with zsh rc file" {
  mkdir -p "$FAKE_HOME/projects/app/bin"
  cp "$RUN_ROOT/run" "$FAKE_HOME/projects/app/run"
  chmod +x "$FAKE_HOME/projects/app/run"

  cd "$FAKE_HOME/projects/app"
  HOME="$FAKE_HOME" SHELL=/bin/zsh ./run install-global >/dev/null
  [ -f "$FAKE_HOME/.zshrc" ]
  grep -qF "# >>> run.sh install-global >>>" "$FAKE_HOME/.zshrc"
  grep -q "run() {" "$FAKE_HOME/.zshrc"
}

@test "install-global with fish rc file (content assertion only)" {
  mkdir -p "$FAKE_HOME/projects/app/bin"
  cp "$RUN_ROOT/run" "$FAKE_HOME/projects/app/run"
  chmod +x "$FAKE_HOME/projects/app/run"

  cd "$FAKE_HOME/projects/app"
  HOME="$FAKE_HOME" SHELL=/usr/bin/fish ./run install-global >/dev/null
  [ -f "$FAKE_HOME/.config/fish/config.fish" ]
  grep -qF "# >>> run.sh install-global >>>" "$FAKE_HOME/.config/fish/config.fish"
  grep -q "function run" "$FAKE_HOME/.config/fish/config.fish"
  grep -q "end" "$FAKE_HOME/.config/fish/config.fish"
}

@test "install-global with unsupported shell errors gracefully" {
  mkdir -p "$FAKE_HOME/projects/app/bin"
  cp "$RUN_ROOT/run" "$FAKE_HOME/projects/app/run"
  chmod +x "$FAKE_HOME/projects/app/run"

  cd "$FAKE_HOME/projects/app"
  run env HOME="$FAKE_HOME" SHELL=/usr/bin/ksh ./run install-global
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported"* ]]
}
