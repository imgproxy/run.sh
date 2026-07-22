#!/usr/bin/env bats

setup() {
  RUN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  RUN_SH_ROOT="$RUN_ROOT" bash "$RUN_ROOT/install.sh" >/dev/null

  cat > bin/greet.sh <<'EOF'
#!/usr/bin/env bash
description() { echo "Greet a name"; }
help() { echo "Usage: ./run greet <name>"; }
main() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "error: missing name" >&2; return 1; }
  echo "Hello, $name!"
}
EOF
}

teardown() {
  cd "$RUN_ROOT"
  rm -rf "$TEST_DIR"
}

@test "no-arg listing shows task name and description" {
  run ./run
  [ "$status" -eq 0 ]
  [[ "$output" == *"greet"* ]]
  [[ "$output" == *"Greet a name"* ]]
}

@test "no-arg listing does not list .runrc as a task" {
  run ./run
  [ "$status" -eq 0 ]
  [[ "$output" != *"  env "* ]]
}

@test "./run help <task> prints description and help" {
  run ./run help greet
  [ "$status" -eq 0 ]
  [[ "$output" == *"Greet a name"* ]]
  [[ "$output" == *"Usage: ./run greet <name>"* ]]
}

@test "./run <task> <args> passes args through to main" {
  run ./run greet World
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, World!"* ]]
}

@test "./run <task> with missing required arg fails via task's own validation" {
  run ./run greet
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing name"* ]]
}

@test "unknown task exits non-zero and lists tasks on stderr" {
  run ./run bogus-task
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown task 'bogus-task'"* ]]
  [[ "$output" == *"greet"* ]]
}

@test "non-existent task name 'env' is rejected" {
  run ./run env
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown task 'env'"* ]]
}

@test "./run help env is rejected" {
  run ./run help env
  [ "$status" -ne 0 ]
}
