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

# --- Per-task budget tests (REQ-02) ---

@test "token-budget: computes per-task budget from contract metadata" {
  cd "$TEST_TEMP_DIR"
  # Contract: 3 must_haves, 4 allowed_paths, 0 depends_on
  # Score: 3*1 + 4*2 + 0*3 = 11 -> standard tier -> multiplier 1.0
  # Dev base 800 * 1.0 = 800
  jq -n '{phase:2, plan:1, task_count:3, must_haves:["a","b","c"], allowed_paths:["f1","f2","f3","f4"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/contract.json"
  generate_lines 800 > "$TEST_TEMP_DIR/task-context.txt"
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' dev '$TEST_TEMP_DIR/task-context.txt' '$TEST_TEMP_DIR/contract.json' 1 2>/dev/null"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 800 ]
}

@test "token-budget: applies higher multiplier for complex tasks" {
  cd "$TEST_TEMP_DIR"
  # Contract: 8 must_haves, 6 files, 1 dep
  # Score: 8*1 + 6*2 + 1*3 = 23 -> heavy tier -> multiplier 1.6
  # Dev base 800 * 1.6 = 1280
  jq -n '{phase:2, plan:1, task_count:3, must_haves:["a","b","c","d","e","f","g","h"], allowed_paths:["f1","f2","f3","f4","f5","f6"], depends_on:["dep1"]}' \
    > "$TEST_TEMP_DIR/contract.json"
  generate_lines 1200 > "$TEST_TEMP_DIR/task-context.txt"
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' dev '$TEST_TEMP_DIR/task-context.txt' '$TEST_TEMP_DIR/contract.json' 1 2>/dev/null"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  # 1200 lines < 1280 budget, so all pass through
  [ "$LINE_COUNT" -eq 1200 ]
}

@test "token-budget: applies lower multiplier for simple tasks" {
  cd "$TEST_TEMP_DIR"
  # Contract: 1 must_have, 1 file, 0 deps
  # Score: 1*1 + 1*2 + 0*3 = 3 -> simple tier -> multiplier 0.6
  # Dev base 800 * 0.6 = 480
  jq -n '{phase:2, plan:1, task_count:1, must_haves:["a"], allowed_paths:["f1"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/contract.json"
  generate_lines 500 > "$TEST_TEMP_DIR/task-context.txt"
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' dev '$TEST_TEMP_DIR/task-context.txt' '$TEST_TEMP_DIR/contract.json' 1 2>/dev/null"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 480 ]
}

@test "token-budget: falls back to per-role when no contract" {
  cd "$TEST_TEMP_DIR"
  # No contract args -> per-role fallback -> dev = 800
  generate_lines 900 > "$TEST_TEMP_DIR/fallback-context.txt"
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' dev '$TEST_TEMP_DIR/fallback-context.txt' 2>/dev/null"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 800 ]
}

@test "token-budget: falls back to per-role when contract file missing" {
  cd "$TEST_TEMP_DIR"
  # Pass nonexistent contract path -> fallback -> dev = 800
  generate_lines 900 > "$TEST_TEMP_DIR/fallback-context.txt"
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' dev '$TEST_TEMP_DIR/fallback-context.txt' '$TEST_TEMP_DIR/nonexistent.json' 1 2>/dev/null"
  [ "$status" -eq 0 ]
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -eq 800 ]
}

@test "token-budget: includes budget_source in metrics" {
  cd "$TEST_TEMP_DIR"
  # Create contract to trigger per-task budget
  jq -n '{phase:2, plan:1, task_count:1, must_haves:["a"], allowed_paths:["f1"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/contract.json"
  generate_lines 500 > "$TEST_TEMP_DIR/source-context.txt"
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/source-context.txt" "$TEST_TEMP_DIR/contract.json" 1 >/dev/null 2>&1
  [ -f ".vbw-planning/.metrics/run-metrics.jsonl" ]
  run cat ".vbw-planning/.metrics/run-metrics.jsonl"
  [[ "$output" == *"budget_source"* ]]
  [[ "$output" == *"task"* ]]
}

# --- Escalation tests (REQ-03) ---

@test "token-budget: emits escalation warning on overage" {
  cd "$TEST_TEMP_DIR"
  jq -n '{phase:2, plan:1, task_count:3, must_haves:["a","b","c"], allowed_paths:["f1","f2","f3","f4"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/contract.json"
  generate_lines 900 > "$TEST_TEMP_DIR/escalation-context.txt"
  run bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/escalation-context.txt" "$TEST_TEMP_DIR/contract.json" 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"ESCALATION"* ]] || [[ "$stderr" == *"ESCALATION"* ]]
}

@test "token-budget: writes budget reduction sidecar" {
  cd "$TEST_TEMP_DIR"
  jq -n '{phase:2, plan:1, task_count:3, must_haves:["a","b","c"], allowed_paths:["f1","f2","f3","f4"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/2-1.json"
  generate_lines 900 > "$TEST_TEMP_DIR/sidecar-context.txt"
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/sidecar-context.txt" "$TEST_TEMP_DIR/2-1.json" 1 >/dev/null 2>&1
  [ -f ".vbw-planning/.token-state/2-1.json" ]
  run jq -r '.overages' ".vbw-planning/.token-state/2-1.json"
  [ "$output" = "1" ]
  run jq -r '.remaining_budget_pct' ".vbw-planning/.token-state/2-1.json"
  [ "$output" = "85" ]
}

@test "token-budget: compounds reduction on repeated overages" {
  cd "$TEST_TEMP_DIR"
  jq -n '{phase:2, plan:1, task_count:3, must_haves:["a","b","c"], allowed_paths:["f1","f2","f3","f4"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/2-1.json"
  generate_lines 900 > "$TEST_TEMP_DIR/compound-context.txt"
  # First overage
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/compound-context.txt" "$TEST_TEMP_DIR/2-1.json" 1 >/dev/null 2>&1
  run jq -r '.remaining_budget_pct' ".vbw-planning/.token-state/2-1.json"
  [ "$output" = "85" ]
  # Second overage
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/compound-context.txt" "$TEST_TEMP_DIR/2-1.json" 2 >/dev/null 2>&1
  run jq -r '.remaining_budget_pct' ".vbw-planning/.token-state/2-1.json"
  [ "$output" = "70" ]
  run jq -r '.overages' ".vbw-planning/.token-state/2-1.json"
  [ "$output" = "2" ]
}

@test "token-budget: respects min_budget_floor" {
  cd "$TEST_TEMP_DIR"
  # Set min_budget_floor to 500 and reduction_percent to 50 for faster floor hit
  jq '.escalation.min_budget_floor = 500 | .escalation.reduction_percent = 50' \
    "$TEST_TEMP_DIR/config/token-budgets.json" > "$TEST_TEMP_DIR/config/token-budgets.json.tmp" \
    && mv "$TEST_TEMP_DIR/config/token-budgets.json.tmp" "$TEST_TEMP_DIR/config/token-budgets.json"
  jq -n '{phase:2, plan:1, task_count:5, must_haves:["a","b","c"], allowed_paths:["f1","f2","f3","f4"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/2-1.json"
  generate_lines 900 > "$TEST_TEMP_DIR/floor-context.txt"
  # First overage: 100% -> 50%
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/floor-context.txt" "$TEST_TEMP_DIR/2-1.json" 1 >/dev/null 2>&1
  # Second overage: budget = 800*50% = 400, but floor is 500, so clamped to 500
  # 900 lines > 500 -> overage, 50% -> 0%, but floor at 500
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/floor-context.txt" "$TEST_TEMP_DIR/2-1.json" 2 >/dev/null 2>&1
  # Third overage: budget should still be at floor (500)
  run bash -c "bash '$SCRIPTS_DIR/token-budget.sh' dev '$TEST_TEMP_DIR/floor-context.txt' '$TEST_TEMP_DIR/2-1.json' 3 2>/dev/null"
  LINE_COUNT=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINE_COUNT" -ge 500 ]
}

@test "token-budget: emits token_cap_escalated event" {
  cd "$TEST_TEMP_DIR"
  jq -n '{phase:2, plan:1, task_count:3, must_haves:["a","b","c"], allowed_paths:["f1","f2","f3","f4"], depends_on:[]}' \
    > "$TEST_TEMP_DIR/2-1.json"
  generate_lines 900 > "$TEST_TEMP_DIR/event-context.txt"
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/event-context.txt" "$TEST_TEMP_DIR/2-1.json" 1 >/dev/null 2>&1
  [ -f ".vbw-planning/.events/event-log.jsonl" ]
  run cat ".vbw-planning/.events/event-log.jsonl"
  [[ "$output" == *"token_cap_escalated"* ]]
}

@test "token-budget: escalation skipped when no contract path" {
  cd "$TEST_TEMP_DIR"
  # Per-role mode (no contract) -> no .token-state file created
  generate_lines 900 > "$TEST_TEMP_DIR/norole-context.txt"
  bash "$SCRIPTS_DIR/token-budget.sh" dev "$TEST_TEMP_DIR/norole-context.txt" >/dev/null 2>&1
  # Token state directory should not exist or be empty
  if [ -d ".vbw-planning/.token-state" ]; then
    FILE_COUNT=$(ls -1 ".vbw-planning/.token-state/" 2>/dev/null | wc -l | tr -d ' ')
    [ "$FILE_COUNT" -eq 0 ]
  fi
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

@test "metrics-report: computes median task latency" {
  cd "$TEST_TEMP_DIR"
  # Create matched start/confirm events with real timestamps and task_id data
  echo '{"ts":"2026-01-01T10:00:00Z","event":"task_started","phase":1,"data":{"task_id":"t1"}}' >> ".vbw-planning/.events/event-log.jsonl"
  echo '{"ts":"2026-01-01T10:05:00Z","event":"task_completed_confirmed","phase":1,"data":{"task_id":"t1"}}' >> ".vbw-planning/.events/event-log.jsonl"
  echo '{"ts":"2026-01-01T10:10:00Z","event":"task_started","phase":1,"data":{"task_id":"t2"}}' >> ".vbw-planning/.events/event-log.jsonl"
  echo '{"ts":"2026-01-01T10:20:00Z","event":"task_completed_confirmed","phase":1,"data":{"task_id":"t2"}}' >> ".vbw-planning/.events/event-log.jsonl"
  run bash "$SCRIPTS_DIR/metrics-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Median latency"* ]]
  # Should not be N/A since we have matched pairs
  [[ "$output" != *"Median latency: N/A"* ]]
}

@test "metrics-report: shows profile info in summary" {
  cd "$TEST_TEMP_DIR"
  echo '{"ts":"2026-01-01","event":"task_started","phase":1}' >> ".vbw-planning/.events/event-log.jsonl"
  run bash "$SCRIPTS_DIR/metrics-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"effort=balanced"* ]]
  [[ "$output" == *"autonomy=standard"* ]]
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
