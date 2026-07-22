#!/usr/bin/env bats

setup() {
  RUN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  export RUN_SH_ROOT="$RUN_ROOT"
}

teardown() {
  cd "$RUN_ROOT"
  rm -rf "$TEST_DIR"
}

@test "fresh install creates .runrc and an executable run" {
  run bash "$RUN_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -f .runrc ]
  [ -f run ]
  [ -x run ]
}

@test "fresh install prints [ok] for each created file" {
  run bash "$RUN_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[ok] wrote .runrc"* ]]
  [[ "$output" == *"[ok] wrote run"* ]]
}

@test "re-install leaves .runrc untouched" {
  bash "$RUN_ROOT/install.sh"
  echo "# my customization" >> .runrc

  run bash "$RUN_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *".runrc already exists, leaving it alone"* ]]
  grep -q "my customization" .runrc
}

@test ".runrc includes color helpers and no guard_docker" {
  run bash "$RUN_ROOT/install.sh"
  [ "$status" -eq 0 ]
  grep -q "run_colors_enabled" .runrc
  grep -q "run_gradient_text" .runrc
  [[ "$(grep -c "guard_docker" .runrc || true)" == "0" ]]
}

@test "re-install with no changes reports run as up to date, no backup" {
  bash "$RUN_ROOT/install.sh"
  run bash "$RUN_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"run is already up to date"* ]]
  [ ! -f run.bak ]
}

@test "re-install after hand-editing run backs it up and rewrites it" {
  bash "$RUN_ROOT/install.sh"
  echo "# hand edit" >> run

  run bash "$RUN_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"backed up to run.bak"* ]]
  [ -f run.bak ]
  grep -q "hand edit" run.bak
  ! grep -q "hand edit" run
}

@test "--examples scaffolds hello/greet/deploy when bin/ has no tasks yet" {
  run bash "$RUN_ROOT/install.sh" --examples
  [ "$status" -eq 0 ]
  [ -f bin/hello.sh ]
  [ -f bin/greet.sh ]
  [ -f bin/deploy.sh ]
}

@test "--examples is skipped once a real task file already exists" {
  bash "$RUN_ROOT/install.sh"
  cat > bin/existing.sh <<'EOF'
#!/usr/bin/env bash
description() { echo "existing"; }
help() { echo "existing"; }
main() { echo "existing"; }
EOF

  run bash "$RUN_ROOT/install.sh" --examples
  [ "$status" -eq 0 ]
  [[ "$output" == *"bin/ already has task files, skipping --examples"* ]]
  [ ! -f bin/hello.sh ]
}

@test "unknown flag is rejected" {
  run bash "$RUN_ROOT/install.sh" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}
