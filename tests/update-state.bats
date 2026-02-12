#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  echo "line1" > "$TEST_TEMP_DIR/test.txt"
  echo "line2" >> "$TEST_TEMP_DIR/test.txt"
}

teardown() {
  teardown_temp_dir
}

@test "appends line to file" {
  run bash "$SCRIPTS_DIR/update-state.sh" "$TEST_TEMP_DIR/test.txt" append "line3"
  [ "$status" -eq 0 ]
  grep -q "line3" "$TEST_TEMP_DIR/test.txt"
}

@test "replaces text in file" {
  run bash "$SCRIPTS_DIR/update-state.sh" "$TEST_TEMP_DIR/test.txt" replace "line1" "replaced1"
  [ "$status" -eq 0 ]
  grep -q "replaced1" "$TEST_TEMP_DIR/test.txt"
  ! grep -q "line1" "$TEST_TEMP_DIR/test.txt"
}

@test "updates JSON file" {
  echo '{"status":"pending"}' > "$TEST_TEMP_DIR/test.json"
  run bash "$SCRIPTS_DIR/update-state.sh" "$TEST_TEMP_DIR/test.json" json '.status = "complete"'
  [ "$status" -eq 0 ]
  jq -e '.status == "complete"' "$TEST_TEMP_DIR/test.json"
}

@test "rejects unknown operation" {
  run bash "$SCRIPTS_DIR/update-state.sh" "$TEST_TEMP_DIR/test.txt" invalid "arg"
  [ "$status" -eq 1 ]
}

@test "rejects missing arguments" {
  run bash "$SCRIPTS_DIR/update-state.sh" "$TEST_TEMP_DIR/test.txt"
  [ "$status" -eq 1 ]
}
