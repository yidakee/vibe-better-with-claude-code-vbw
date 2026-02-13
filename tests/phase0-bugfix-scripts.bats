#!/usr/bin/env bats

load test_helper

# --- Task 1: Heredoc commit validation ---

@test "heredoc commit validation extracts correct message" {
  INPUT='{"tool_input":{"command":"git commit -m \"$(cat <<'"'"'EOF'"'"'\nfeat(core): add heredoc feature\n\nCo-Authored-By: Test\nEOF\n)\""}}'
  run bash -c "echo '$INPUT' | bash '$SCRIPTS_DIR/validate-commit.sh'"
  [ "$status" -eq 0 ]
  # Should NOT contain "does not match format" since feat(core): is valid
  [[ "$output" != *"does not match format"* ]]
}

@test "heredoc commit does not get overwritten by -m extraction" {
  # Heredoc with valid format followed by -m with invalid format
  # If heredoc is correctly prioritized, it should use the heredoc message
  INPUT='{"tool_input":{"command":"git commit -m \"$(cat <<'"'"'EOF'"'"'\nfeat(test): valid heredoc\nEOF\n)\""}}'
  run bash -c "echo '$INPUT' | bash '$SCRIPTS_DIR/validate-commit.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not match format"* ]]
}

@test "invalid heredoc commit is flagged" {
  # Build input with actual newlines in the heredoc body
  local input
  input=$(printf '{"tool_input":{"command":"git commit -m \\"$(cat <<EOF)\\"\\nbad commit no type\\nEOF"}}')
  run bash -c "printf '%s' '$input' | bash '$SCRIPTS_DIR/validate-commit.sh'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "does not match format"
}

# --- Task 4: Stack detection expansion ---

@test "detect-stack finds Rust via Cargo.toml" {
  local tmpdir
  tmpdir=$(mktemp -d)
  touch "$tmpdir/Cargo.toml"
  run bash "$SCRIPTS_DIR/detect-stack.sh" "$tmpdir"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.detected_stack | index("rust")' >/dev/null
}

@test "detect-stack finds Go via go.mod" {
  local tmpdir
  tmpdir=$(mktemp -d)
  echo "module example.com/test" > "$tmpdir/go.mod"
  run bash "$SCRIPTS_DIR/detect-stack.sh" "$tmpdir"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.detected_stack | index("go")' >/dev/null
}

@test "detect-stack finds Python via pyproject.toml" {
  local tmpdir
  tmpdir=$(mktemp -d)
  touch "$tmpdir/pyproject.toml"
  run bash "$SCRIPTS_DIR/detect-stack.sh" "$tmpdir"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.detected_stack | index("python")' >/dev/null
}

# --- Task 5: Security filter hardening ---

@test "security-filter allows .vbw-planning/ write when VBW marker present" {
  setup_temp_dir
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning"
  touch "$TEST_TEMP_DIR/.vbw-planning/.active-agent"
  touch "$TEST_TEMP_DIR/.vbw-planning/.gsd-isolation"
  INPUT='{"tool_input":{"file_path":"'"$TEST_TEMP_DIR"'/.vbw-planning/STATE.md"}}'
  run bash -c "cd '$TEST_TEMP_DIR' && echo '$INPUT' | bash '$SCRIPTS_DIR/security-filter.sh'"
  teardown_temp_dir
  [ "$status" -eq 0 ]
}

@test "security-filter blocks .env file access" {
  INPUT='{"tool_input":{"file_path":".env"}}'
  run bash -c "echo '$INPUT' | bash '$SCRIPTS_DIR/security-filter.sh'"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "sensitive file"
}

# --- Task 3: Session config cache ---

@test "session config cache file is written at session start" {
  setup_temp_dir
  create_test_config
  CACHE_FILE="/tmp/vbw-config-cache-$(id -u)"
  rm -f "$CACHE_FILE" 2>/dev/null
  run bash -c "cd '$TEST_TEMP_DIR' && bash '$SCRIPTS_DIR/session-start.sh'"
  [ -f "$CACHE_FILE" ]
  grep -q "VBW_EFFORT=" "$CACHE_FILE"
  grep -q "VBW_AUTONOMY=" "$CACHE_FILE"
  teardown_temp_dir
}

# --- Task 2: zsh glob guard ---

@test "file-guard exits 0 when no plan files exist" {
  setup_temp_dir
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/phases"
  INPUT='{"tool_input":{"file_path":"'"$TEST_TEMP_DIR"'/src/index.ts"}}'
  run bash -c "cd '$TEST_TEMP_DIR' && echo '$INPUT' | bash '$SCRIPTS_DIR/file-guard.sh'"
  teardown_temp_dir
  [ "$status" -eq 0 ]
}
