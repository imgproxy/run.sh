#!/usr/bin/env bats

setup() {
  RUN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  cp "$RUN_ROOT/run" "$TEST_DIR/run"
  chmod +x "$TEST_DIR/run"
  mkdir bin

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

@test "no-arg listing shows built-in 'help' task" {
  run ./run
  [ "$status" -eq 0 ]
  [[ "$output" == *"help"* ]]
  [[ "$output" == *"show a task"* ]]
}

@test "no-arg listing shows built-in 'install-global' task" {
  run ./run
  [ "$status" -eq 0 ]
  [[ "$output" == *"install-global"* ]]
}

@test "no-arg listing does not list .runrc as a task" {
  run ./run
  [ "$status" -eq 0 ]
  [[ "$output" != *"  env "* ]]
}

@test "./run works with no .runrc present" {
  [ ! -f .runrc ]
  run ./run greet World
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, World!"* ]]
}

@test ".runrc is sourced when present" {
  cat > .runrc <<'EOF'
RUNRC_MARKER="from-runrc"
greet_wrapper() {
  echo "called from .runrc"
}
EOF

  cat > bin/uses-runrc.sh <<'EOF'
#!/usr/bin/env bash
description() { echo "Task that uses .runrc"; }
help() { echo "Usage: ./run uses-runrc"; }
main() {
  echo "marker=$RUNRC_MARKER"
  greet_wrapper
}
EOF

  run ./run uses-runrc
  [ "$status" -eq 0 ]
  [[ "$output" == *"marker=from-runrc"* ]]
  [[ "$output" == *"called from .runrc"* ]]
}

@test "./run help <task> shows the task's help text" {
  run ./run help greet
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./run greet <name>"* ]]
}

@test "./run help with no task name errors" {
  run ./run help
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing task name"* ]]
}

@test "./run help <unknown-task> errors" {
  run ./run help bogus-task
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown task 'bogus-task'"* ]]
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

@test "./run help (built-in) is permanently reserved" {
  cat > bin/help.sh <<'EOF'
#!/usr/bin/env bash
description() { echo "user task named help"; }
help() { echo "this should never run"; }
main() { echo "this should never run"; }
EOF

  run ./run help greet
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./run greet"* ]]
}

@test "./run install-global (built-in) is permanently reserved" {
  cat > bin/install-global.sh <<'EOF'
#!/usr/bin/env bash
description() { echo "user task named install-global"; }
help() { echo "this should never run"; }
main() { echo "this should never run"; }
EOF

  run ./run install-global
  [ "$status" -eq 0 ]
  [[ "$output" == *"detected shell"* ]]
}
