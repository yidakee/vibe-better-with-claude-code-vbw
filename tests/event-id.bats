#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  # Enable event logging
  jq '.v3_event_log = true' "$TEST_TEMP_DIR/.vbw-planning/config.json" > "$TEST_TEMP_DIR/.vbw-planning/config.json.tmp" \
    && mv "$TEST_TEMP_DIR/.vbw-planning/config.json.tmp" "$TEST_TEMP_DIR/.vbw-planning/config.json"
}

teardown() {
  teardown_temp_dir
}

@test "log-event: includes event_id in output" {
  cd "$TEST_TEMP_DIR"
  bash "$SCRIPTS_DIR/log-event.sh" phase_start 1
  LINE=$(head -1 .vbw-planning/.events/event-log.jsonl)
  echo "$LINE" | jq -e '.event_id'
  EVENT_ID=$(echo "$LINE" | jq -r '.event_id')
  [ -n "$EVENT_ID" ]
  [ "$EVENT_ID" != "null" ]
}

@test "log-event: event_id is unique across events" {
  cd "$TEST_TEMP_DIR"
  bash "$SCRIPTS_DIR/log-event.sh" phase_start 1
  bash "$SCRIPTS_DIR/log-event.sh" plan_start 1 1
  bash "$SCRIPTS_DIR/log-event.sh" phase_end 1
  ID1=$(sed -n '1p' .vbw-planning/.events/event-log.jsonl | jq -r '.event_id')
  ID2=$(sed -n '2p' .vbw-planning/.events/event-log.jsonl | jq -r '.event_id')
  ID3=$(sed -n '3p' .vbw-planning/.events/event-log.jsonl | jq -r '.event_id')
  [ "$ID1" != "$ID2" ]
  [ "$ID2" != "$ID3" ]
  [ "$ID1" != "$ID3" ]
}

@test "log-event: event_id format is UUID-like when uuidgen available" {
  cd "$TEST_TEMP_DIR"
  if ! command -v uuidgen &>/dev/null; then
    skip "uuidgen not available"
  fi
  bash "$SCRIPTS_DIR/log-event.sh" phase_start 1
  EVENT_ID=$(head -1 .vbw-planning/.events/event-log.jsonl | jq -r '.event_id')
  # UUID format: 8-4-4-4-12 hex chars (lowercase)
  [[ "$EVENT_ID" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]
}

@test "log-event: event_id present even without uuidgen" {
  cd "$TEST_TEMP_DIR"
  # Shadow uuidgen with a stub that fails, triggering the fallback
  mkdir -p "$TEST_TEMP_DIR/fake_bin"
  printf '#!/bin/sh\nexit 1\n' > "$TEST_TEMP_DIR/fake_bin/uuidgen"
  chmod +x "$TEST_TEMP_DIR/fake_bin/uuidgen"
  run bash -c "PATH='$TEST_TEMP_DIR/fake_bin:$PATH' bash '$SCRIPTS_DIR/log-event.sh' phase_start 1"
  [ "$status" -eq 0 ]
  LINE=$(head -1 .vbw-planning/.events/event-log.jsonl)
  EVENT_ID=$(echo "$LINE" | jq -r '.event_id')
  [ -n "$EVENT_ID" ]
  [ "$EVENT_ID" != "null" ]
}
