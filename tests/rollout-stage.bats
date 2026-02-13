#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  # Copy rollout-stages.json to temp dir
  mkdir -p "$TEST_TEMP_DIR/config"
  cp "$CONFIG_DIR/../config/rollout-stages.json" "$TEST_TEMP_DIR/config/rollout-stages.json"
  # Create scripts symlink so SCRIPT_DIR/../config resolves
  mkdir -p "$TEST_TEMP_DIR/scripts"
}

teardown() {
  teardown_temp_dir
}

create_event_log() {
  local count="$1"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.events"
  > "$TEST_TEMP_DIR/.vbw-planning/.events/event-log.jsonl"
  for i in $(seq 1 "$count"); do
    echo "{\"ts\":\"2026-01-0${i}T00:00:00Z\",\"event_id\":\"evt-${i}\",\"event\":\"phase_end\",\"phase\":${i}}" >> "$TEST_TEMP_DIR/.vbw-planning/.events/event-log.jsonl"
  done
}

create_error_event_log() {
  local clean="$1"
  local error="$2"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.events"
  > "$TEST_TEMP_DIR/.vbw-planning/.events/event-log.jsonl"
  for i in $(seq 1 "$clean"); do
    echo "{\"ts\":\"2026-01-0${i}T00:00:00Z\",\"event_id\":\"evt-${i}\",\"event\":\"phase_end\",\"phase\":${i}}" >> "$TEST_TEMP_DIR/.vbw-planning/.events/event-log.jsonl"
  done
  for i in $(seq 1 "$error"); do
    local idx=$((clean + i))
    echo "{\"ts\":\"2026-01-0${idx}T00:00:00Z\",\"event_id\":\"evt-err-${i}\",\"event\":\"phase_end\",\"phase\":${idx},\"data\":{\"error\":\"failed\"}}" >> "$TEST_TEMP_DIR/.vbw-planning/.events/event-log.jsonl"
  done
}

run_rollout() {
  cd "$TEST_TEMP_DIR"
  # Override STAGES_PATH by running from the temp dir where config/ exists
  run bash "$SCRIPTS_DIR/rollout-stage.sh" "$@"
}

# --- Test 1: check reports stage 1 with no event log ---

@test "rollout-stage: check reports stage 1 with no event log" {
  run_rollout check
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.current_stage == 1'
  echo "$output" | jq -e '.completed_phases == 0'
}

# --- Test 2: check reports stage 2 after 2 completed phases ---

@test "rollout-stage: check reports stage 2 after 2 completed phases" {
  create_event_log 2
  run_rollout check
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.current_stage == 2'
  echo "$output" | jq -e '.completed_phases == 2'
}

# --- Test 3: check reports stage 3 after 5 completed phases ---

@test "rollout-stage: check reports stage 3 after 5 completed phases" {
  create_event_log 5
  run_rollout check
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.current_stage == 3'
  echo "$output" | jq -e '.completed_phases == 5'
}

# --- Test 4: advance stage 1 enables event_log and metrics ---

@test "rollout-stage: advance stage 1 enables event_log and metrics" {
  run_rollout advance --stage=1
  [ "$status" -eq 0 ]
  # Check config was updated
  local val_event val_metrics val_delta
  val_event=$(jq -r '.v3_event_log' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_metrics=$(jq -r '.v3_metrics' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_delta=$(jq -r '.v3_delta_context' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  [ "$val_event" = "true" ]
  [ "$val_metrics" = "true" ]
  [ "$val_delta" = "false" ]
}

# --- Test 5: advance stage 2 also enables stage 1 flags ---

@test "rollout-stage: advance stage 2 also enables stage 1 flags" {
  run_rollout advance --stage=2
  [ "$status" -eq 0 ]
  local val_event val_metrics val_delta val_cache val_routing
  val_event=$(jq -r '.v3_event_log' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_metrics=$(jq -r '.v3_metrics' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_delta=$(jq -r '.v3_delta_context' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_cache=$(jq -r '.v3_context_cache' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_routing=$(jq -r '.v3_smart_routing' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  [ "$val_event" = "true" ]
  [ "$val_metrics" = "true" ]
  [ "$val_delta" = "true" ]
  [ "$val_cache" = "true" ]
  [ "$val_routing" = "false" ]
}

# --- Test 6: advance is idempotent ---

@test "rollout-stage: advance is idempotent" {
  # First advance
  run_rollout advance --stage=1
  [ "$status" -eq 0 ]
  # Second advance (idempotent)
  run_rollout advance --stage=1
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.flags_enabled | length == 0'
  echo "$output" | jq -e '.flags_already_enabled | length == 2'
}

# --- Test 7: dry-run does not modify config ---

@test "rollout-stage: dry-run does not modify config" {
  run_rollout advance --stage=1 --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.dry_run == true'
  echo "$output" | jq -e '.flags_enabled | length == 2'
  # Config should still have false values
  local val_event val_metrics
  val_event=$(jq -r '.v3_event_log' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_metrics=$(jq -r '.v3_metrics' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  [ "$val_event" = "false" ]
  [ "$val_metrics" = "false" ]
}

# --- Test 8: status outputs markdown table ---

@test "rollout-stage: status outputs markdown table" {
  run_rollout status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rollout Status"* ]]
  [[ "$output" == *"Flag"* ]]
  [[ "$output" == *"Stage"* ]]
  [[ "$output" == *"Enabled"* ]]
  [[ "$output" == *"v3_event_log"* ]]
}

# --- Test 9: exits 0 when config missing ---

@test "rollout-stage: exits 0 when config missing" {
  rm -f "$TEST_TEMP_DIR/.vbw-planning/config.json"
  run_rollout check
  [ "$status" -eq 0 ]
}

# --- Test 10: advance respects phase threshold ---

@test "rollout-stage: advance respects phase threshold" {
  create_event_log 1
  run_rollout advance
  [ "$status" -eq 0 ]
  # With 1 phase, only stage 1 is eligible (stage 2 needs 2)
  local val_event val_metrics val_delta val_cache
  val_event=$(jq -r '.v3_event_log' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_metrics=$(jq -r '.v3_metrics' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_delta=$(jq -r '.v3_delta_context' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  val_cache=$(jq -r '.v3_context_cache' "$TEST_TEMP_DIR/.vbw-planning/config.json")
  [ "$val_event" = "true" ]
  [ "$val_metrics" = "true" ]
  [ "$val_delta" = "false" ]
  [ "$val_cache" = "false" ]
}
