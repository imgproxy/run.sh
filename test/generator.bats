#!/usr/bin/env bats

setup() {
  RUN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  RUN_SH_ROOT="$RUN_ROOT" bash "$RUN_ROOT/install.sh" >/dev/null
}

teardown() {
  cd "$RUN_ROOT"
  rm -rf "$TEST_DIR"
}

@test "./run new <name> creates a task file with the expected skeleton" {
  run ./run new foo
  [ "$status" -eq 0 ]
  [ -f bin/foo.sh ]
  grep -q "description()" bin/foo.sh
  grep -q "help()" bin/foo.sh
  grep -q "main()" bin/foo.sh
  grep -q "TODO: implement foo" bin/foo.sh
}

@test "new task file is not executable (sourced, not run directly)" {
  ./run new foo
  [ ! -x bin/foo.sh ]
}

@test "./run new <name> fails on missing name" {
  run ./run new
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: ./run new <task-name>"* ]]
}

@test "./run new <name> rejects invalid characters" {
  run ./run new "bad name"
  [ "$status" -ne 0 ]
  [[ "$output" == *"alnum/underscore/hyphen"* ]]
}

@test "./run new run is rejected as reserved" {
  run ./run new run
  [ "$status" -ne 0 ]
  [[ "$output" == *"reserved"* ]]
}

@test "./run new <name> refuses to overwrite an existing task without --force" {
  ./run new foo
  run ./run new foo
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "./run new <name> --force overwrites an existing task" {
  ./run new foo
  echo "# marker" >> bin/foo.sh
  run ./run new foo --force
  [ "$status" -eq 0 ]
  ! grep -q "# marker" bin/foo.sh
}
