#!/usr/bin/env bats

setup() {
  RUN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FAKE_ROOT="$(mktemp -d)"
  FAKE_HOME="$FAKE_ROOT/home/testuser"
  mkdir -p "$FAKE_HOME"
  RUN_SH_ROOT="$RUN_ROOT" HOME="$FAKE_HOME" bash "$RUN_ROOT/global/install-global.sh" >/dev/null
}

teardown() {
  cd "$RUN_ROOT"
  rm -rf "$FAKE_ROOT"
}

@test "install-global.sh writes an executable run to ~/.local/bin" {
  [ -x "$FAKE_HOME/.local/bin/run" ]
}

@test "global run finds the project root from a deeply nested subdirectory" {
  mkdir -p "$FAKE_HOME/projects/app/src/deep/nested"
  ( cd "$FAKE_HOME/projects/app" && RUN_SH_ROOT="$RUN_ROOT" bash "$RUN_ROOT/install.sh" --examples >/dev/null )

  cd "$FAKE_HOME/projects/app/src/deep/nested"
  HOME="$FAKE_HOME" run "$FAKE_HOME/.local/bin/run" hello
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello from run.sh!"* ]]
}

@test "global run reports a clean error when no project is found" {
  mkdir -p "$FAKE_HOME/empty-dir"
  cd "$FAKE_HOME/empty-dir"
  HOME="$FAKE_HOME" run "$FAKE_HOME/.local/bin/run"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no run.sh project found"* ]]
}

@test "global run never matches a decoy project placed at or above \$HOME" {
  mkdir -p "$FAKE_HOME/bin" "$FAKE_ROOT/bin"
  touch "$FAKE_HOME/run" "$FAKE_HOME/.runrc"
  touch "$FAKE_ROOT/run" "$FAKE_ROOT/.runrc"
  mkdir -p "$FAKE_HOME/no-project-subdir"

  cd "$FAKE_HOME/no-project-subdir"
  HOME="$FAKE_HOME" run "$FAKE_HOME/.local/bin/run"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no run.sh project found"* ]]
}

@test "install.sh --global also installs the global command" {
  local_root="$FAKE_ROOT/local-project"
  mkdir -p "$local_root"
  ( cd "$local_root" && RUN_SH_ROOT="$RUN_ROOT" HOME="$FAKE_HOME" bash "$RUN_ROOT/install.sh" --global >/dev/null )
  [ -x "$FAKE_HOME/.local/bin/run" ]
  [ -f "$local_root/run" ]
}
