#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.metrics"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.events"
  # Enable flags
  jq '.v2_token_budgets = true | .v3_metrics = true | .v3_event_log = true' \
    "$TEST_TEMP_DIR/.vbw-planning/config.json" > "$TEST_TEMP_DIR/.vbw-planning/config.json.tmp" \
    && mv "$TEST_TEMP_DIR/.vbw-planning/config.json.tmp" "$TEST_TEMP_DIR/.vbw-planning/config.json"
  # Copy token budgets config
  mkdir -p "$TEST_TEMP_DIR/config"
  cp "$CONFIG_DIR/token-budgets.json" "$TEST_TEMP_DIR/config/"
}

teardown() {
  teardown_temp_dir
}

generate_lines() {
  local count=$1
  for i in $(seq 1 "$count"); do
    echo "Line ${i} of content for testing token budget enforcement"
  done
}

# --- Token budget enforcement ---

@test "token-budget: passes through when within budget" {
  cd "$TEST_TEMP_DIR"
  CONTENT=$(generate_lines 50)
  run bash -c "echo '$CONTENT' | bash '$SCRIPTS_DIR/token-budget.sh' scout"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 50 ]
}

@test "token-budget: truncates when over budget" {
  cd "$TEST_TEMP_DIR"
  # Scout has 200 line budget
  generate_lines 300 > "$TEST_TEMP_DIR/big-context.txt"
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' scout '$TEST_TEMP_DIR/big-context.txt' 2>/dev/null"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 200 ]
}

@test "token-budget: dev has higher budget than scout" {
  cd "$TEST_TEMP_DIR"
  generate_lines 600 > "$TEST_TEMP_DIR/dev-context.txt"
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' dev '$TEST_TEMP_DIR/dev-context.txt' 2>/dev/null"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 600 ]
  # Same content for scout should truncate
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' scout '$TEST_TEMP_DIR/dev-context.txt' 2>/dev/null"
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 200 ]
}

@test "token-budget: skips when flag disabled" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_token_budgets = false' ".vbw-planning/config.json" > ".vbw-planning/config.json.tmp" \
    && mv ".vbw-planning/config.json.tmp" ".vbw-planning/config.json"
  generate_lines 300 > "$TEST_TEMP_DIR/no-truncate.txt"
  run bash "$SCRIPTS_DIR/token-budget.sh" scout "$TEST_TEMP_DIR/no-truncate.txt"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 300 ]
}

@test "token-budget: logs overage to metrics" {
  cd "$TEST_TEMP_DIR"
  generate_lines 300 > "$TEST_TEMP_DIR/overage.txt"
  bash "$SCRIPTS_DIR/token-budget.sh" scout "$TEST_TEMP_DIR/overage.txt" >/dev/null 2>&1
  [ -f ".vbw-planning/.metrics/run-metrics.jsonl" ]
  run cat ".vbw-planning/.metrics/run-metrics.jsonl"
  [[ "$output" == *"token_overage"* ]]
  [[ "$output" == *"scout"* ]]
}

# --- Metrics report ---

@test "metrics-report: produces markdown with no data" {
  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/metrics-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Metrics Report"* ]] || [[ "$output" == *"Observability Report"* ]]
}

@test "metrics-report: produces summary table with event data" {
  cd "$TEST_TEMP_DIR"
  # Create some event data
  echo '{"ts":"2026-01-01","event":"task_started","phase":1}' >> ".vbw-planning/.events/event-log.jsonl"
  echo '{"ts":"2026-01-01","event":"task_completed_confirmed","phase":1}' >> ".vbw-planning/.events/event-log.jsonl"
  echo '{"ts":"2026-01-01","event":"gate_passed","phase":1}' >> ".vbw-planning/.events/event-log.jsonl"
  run bash "$SCRIPTS_DIR/metrics-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Summary"* ]]
  [[ "$output" == *"Tasks started"* ]]
  [[ "$output" == *"Tasks confirmed"* ]]
}

@test "metrics-report: includes gate failure rate" {
  cd "$TEST_TEMP_DIR"
  echo '{"ts":"2026-01-01","event":"gate_passed","phase":1}' >> ".vbw-planning/.events/event-log.jsonl"
  echo '{"ts":"2026-01-01","event":"gate_passed","phase":1}' >> ".vbw-planning/.events/event-log.jsonl"
  echo '{"ts":"2026-01-01","event":"gate_failed","phase":1}' >> ".vbw-planning/.events/event-log.jsonl"
  run bash "$SCRIPTS_DIR/metrics-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Gate Failure Rate"* ]]
  [[ "$output" == *"33%"* ]]
}

# --- Config flag ---

@test "defaults.json includes v2_token_budgets flag" {
  run jq '.v2_token_budgets' "$CONFIG_DIR/defaults.json"
  [ "$output" = "false" ]
}

# --- Token budgets config ---

@test "token-budgets.json has all 6 roles" {
  run jq '.budgets | keys | length' "$CONFIG_DIR/token-budgets.json"
  [ "$output" = "6" ]
}

@test "token-budgets.json scout cap is lowest" {
  SCOUT=$(jq '.budgets.scout.max_lines' "$CONFIG_DIR/token-budgets.json")
  DEV=$(jq '.budgets.dev.max_lines' "$CONFIG_DIR/token-budgets.json")
  [ "$SCOUT" -lt "$DEV" ]
}

# --- Protocol integration ---

@test "execute-protocol references token budgets" {
  run grep -c "token_budget" "$PROJECT_ROOT/references/execute-protocol.md"
  [ "$output" -ge 1 ]
}

@test "execute-protocol references metrics report" {
  run grep -c "metrics-report.sh" "$PROJECT_ROOT/references/execute-protocol.md"
  [ "$output" -ge 1 ]
}
