#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.contracts"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.events"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.metrics"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/phases/01-test"
}

teardown() {
  teardown_temp_dir
}

create_valid_contract() {
  cat > "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json" << 'CONTRACT'
{
  "phase_id": "phase-1",
  "plan_id": "phase-1-plan-1",
  "phase": 1,
  "plan": 1,
  "objective": "Test Plan",
  "task_ids": ["1-1-T1", "1-1-T2"],
  "task_count": 2,
  "allowed_paths": ["src/a.js", "src/b.js"],
  "forbidden_paths": [".env", "secrets"],
  "depends_on": [],
  "must_haves": ["Feature A works"],
  "verification_checks": ["true"],
  "max_token_budget": 50000,
  "timeout_seconds": 600
}
CONTRACT
  # Compute and store hash
  HASH=$(jq 'del(.contract_hash)' "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json" | shasum -a 256 | cut -d' ' -f1)
  jq --arg h "$HASH" '.contract_hash = $h' "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json" > "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json.tmp" \
    && mv "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json.tmp" "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json"
}

@test "hard-gate: includes autonomy field in pass output" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_hard_gates = true | .v2_hard_contracts = true | .v3_event_log = true' \
    .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  create_valid_contract
  run bash "$SCRIPTS_DIR/hard-gate.sh" contract_compliance 1 1 1 "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.autonomy'
  AUTONOMY=$(echo "$output" | jq -r '.autonomy')
  [ "$AUTONOMY" = "standard" ]
}

@test "hard-gate: includes autonomy field in skip output" {
  cd "$TEST_TEMP_DIR"
  # v2_hard_gates defaults to false
  run bash "$SCRIPTS_DIR/hard-gate.sh" contract_compliance 1 1 1 /dev/null
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.autonomy'
  echo "$output" | jq -e '.result == "skip"'
}

@test "hard-gate: autonomy value matches config" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_hard_gates = true | .v2_hard_contracts = true | .v3_event_log = true | .autonomy = "yolo"' \
    .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  create_valid_contract
  run bash "$SCRIPTS_DIR/hard-gate.sh" contract_compliance 1 1 1 "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json"
  [ "$status" -eq 0 ]
  AUTONOMY=$(echo "$output" | jq -r '.autonomy')
  [ "$AUTONOMY" = "yolo" ]
}

@test "hard-gate: gate fires regardless of autonomy=yolo" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_hard_gates = true | .v2_hard_contracts = true | .v3_event_log = true | .autonomy = "yolo"' \
    .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  # Create contract with wrong hash to trigger failure
  cat > "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json" << 'CONTRACT'
{
  "phase_id": "phase-1",
  "plan_id": "phase-1-plan-1",
  "phase": 1,
  "plan": 1,
  "objective": "Test",
  "task_ids": ["1-1-T1"],
  "task_count": 1,
  "allowed_paths": [],
  "forbidden_paths": [],
  "depends_on": [],
  "must_haves": [],
  "verification_checks": [],
  "max_token_budget": 50000,
  "timeout_seconds": 600,
  "contract_hash": "tampered_hash_value"
}
CONTRACT
  run bash "$SCRIPTS_DIR/hard-gate.sh" contract_compliance 1 1 1 "$TEST_TEMP_DIR/.vbw-planning/.contracts/1-1.json"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.result == "fail"'
  echo "$output" | jq -e '.autonomy == "yolo"'
}
