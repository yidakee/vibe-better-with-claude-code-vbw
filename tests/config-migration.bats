#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
}

teardown() {
  teardown_temp_dir
}

# Helper: Run the shared migration script
run_migration() {
  bash "$SCRIPTS_DIR/migrate-config.sh" "$TEST_TEMP_DIR/.vbw-planning/config.json"
}

@test "migration handles empty config" {
  # Create config with only non-flag keys
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "autonomy": "standard"
}
EOF

  run_migration

  # Verify all 23 flags were added
  run jq '[
    has("context_compiler"), has("v3_delta_context"), has("v3_context_cache"),
    has("v3_plan_research_persist"), has("v3_metrics"), has("v3_contract_lite"),
    has("v3_lock_lite"), has("v3_validation_gates"), has("v3_smart_routing"),
    has("v3_event_log"), has("v3_schema_validation"), has("v3_snapshot_resume"),
    has("v3_lease_locks"), has("v3_event_recovery"), has("v3_monorepo_routing"),
    has("v2_hard_contracts"), has("v2_hard_gates"), has("v2_typed_protocol"),
    has("v2_role_isolation"), has("v2_two_phase_completion"), has("v2_token_budgets"),
    has("model_overrides"), has("prefer_teams")
  ] | map(select(.)) | length' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "23" ]

  # Verify context_compiler defaults to true
  run jq -r '.context_compiler' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  # Verify v3 flags default to false
  run jq -r '.v3_delta_context' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "migration handles partial config" {
  # Create config with some flags present
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "context_compiler": false,
  "v3_delta_context": true,
  "v2_hard_contracts": true
}
EOF

  run_migration

  # Verify all 23 flags exist
  run jq '[
    has("context_compiler"), has("v3_delta_context"), has("v3_context_cache"),
    has("v3_plan_research_persist"), has("v3_metrics"), has("v3_contract_lite"),
    has("v3_lock_lite"), has("v3_validation_gates"), has("v3_smart_routing"),
    has("v3_event_log"), has("v3_schema_validation"), has("v3_snapshot_resume"),
    has("v3_lease_locks"), has("v3_event_recovery"), has("v3_monorepo_routing"),
    has("v2_hard_contracts"), has("v2_hard_gates"), has("v2_typed_protocol"),
    has("v2_role_isolation"), has("v2_two_phase_completion"), has("v2_token_budgets"),
    has("model_overrides"), has("prefer_teams")
  ] | map(select(.)) | length' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "23" ]

  # Verify existing values were preserved
  run jq -r '.context_compiler' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  run jq -r '.v3_delta_context' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run jq -r '.v2_hard_contracts' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "migration handles full config" {
  # Create config with all flags present
  create_test_config

  # Record normalized content
  BEFORE=$(jq -S . "$TEST_TEMP_DIR/.vbw-planning/config.json")

  run_migration

  # Verify no changes (idempotent when all flags present)
  AFTER=$(jq -S . "$TEST_TEMP_DIR/.vbw-planning/config.json")
  [ "$BEFORE" = "$AFTER" ]
}

@test "migration is idempotent" {
  # Start with empty config
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced"
}
EOF

  # Run migration once
  run_migration
  AFTER_FIRST=$(cat "$TEST_TEMP_DIR/.vbw-planning/config.json")

  # Run migration again
  run_migration
  AFTER_SECOND=$(cat "$TEST_TEMP_DIR/.vbw-planning/config.json")

  # Both runs should produce identical result
  [ "$AFTER_FIRST" = "$AFTER_SECOND" ]

  # Verify flag count is correct
  run jq '[
    has("context_compiler"), has("v3_delta_context"), has("v3_context_cache"),
    has("v3_plan_research_persist"), has("v3_metrics"), has("v3_contract_lite"),
    has("v3_lock_lite"), has("v3_validation_gates"), has("v3_smart_routing"),
    has("v3_event_log"), has("v3_schema_validation"), has("v3_snapshot_resume"),
    has("v3_lease_locks"), has("v3_event_recovery"), has("v3_monorepo_routing"),
    has("v2_hard_contracts"), has("v2_hard_gates"), has("v2_typed_protocol"),
    has("v2_role_isolation"), has("v2_two_phase_completion"), has("v2_token_budgets"),
    has("model_overrides"), has("prefer_teams")
  ] | map(select(.)) | length' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "23" ]
}

@test "migration detects malformed JSON" {
  # Create malformed JSON
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  invalid json here
}
EOF

  # Migration should fail gracefully
  run run_migration
  [ "$status" -ne 0 ]

  # Temp file should be cleaned up (tested implicitly by not checking for it)
}

@test "EXPECTED_FLAG_COUNT matches defaults.json" {
  # Count actual v3/v2 flags in defaults.json
  # Flags: v3_*, v2_*, context_compiler, model_overrides, prefer_teams
  DEFAULTS_COUNT=$(jq '[keys[] | select(startswith("v3_") or startswith("v2_") or . == "context_compiler" or . == "model_overrides" or . == "prefer_teams")] | length' "$CONFIG_DIR/defaults.json")

  # Extract EXPECTED_FLAG_COUNT from session-start.sh
  SCRIPT_COUNT=$(grep 'EXPECTED_FLAG_COUNT=' "$SCRIPTS_DIR/session-start.sh" | grep -oE '[0-9]+' | head -1)

  # Debug output for test failure
  if [ "$DEFAULTS_COUNT" != "$SCRIPT_COUNT" ]; then
    echo "MISMATCH: defaults.json has $DEFAULTS_COUNT flags, session-start.sh expects $SCRIPT_COUNT"
  fi

  [ "$DEFAULTS_COUNT" = "$SCRIPT_COUNT" ]
}

@test "migration adds missing prefer_teams with default value" {
  # Create config without prefer_teams
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "autonomy": "standard"
}
EOF

  run_migration

  # Verify prefer_teams was added with "always" default
  run jq -r '.prefer_teams' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "always" ]
}

@test "migration adds planning_tracking and auto_push defaults" {
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced"
}
EOF

  run_migration

  run jq -r '.planning_tracking' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "manual" ]

  run jq -r '.auto_push' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "never" ]
}

@test "migration preserves existing planning_tracking and auto_push values" {
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "planning_tracking": "commit",
  "auto_push": "after_phase"
}
EOF

  run_migration

  run jq -r '.planning_tracking' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "commit" ]

  run jq -r '.auto_push' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "after_phase" ]
}

@test "migration preserves existing prefer_teams value" {
  # Create config with prefer_teams set to "never"
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "prefer_teams": "never"
}
EOF

  run_migration

  # Verify prefer_teams value was NOT overwritten
  run jq -r '.prefer_teams' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "never" ]
}

@test "migration renames agent_teams to prefer_teams and removes stale key" {
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "agent_teams": true
}
EOF

  run_migration

  run jq -r '.prefer_teams' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "always" ]

  run jq -r 'has("agent_teams")' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "migration removes stale agent_teams when prefer_teams already exists" {
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "prefer_teams": "when_parallel",
  "agent_teams": false
}
EOF

  run_migration

  run jq -r '.prefer_teams' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "when_parallel" ]

  run jq -r 'has("agent_teams")' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "migration maps agent_teams false to prefer_teams auto" {
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced",
  "agent_teams": false
}
EOF

  run_migration

  run jq -r '.prefer_teams' "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "auto" ]
}

@test "migration backfills all missing defaults keys" {
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced"
}
EOF

  run jq -s '.[0] as $d | .[1] as $c | [$d | keys[] | select($c[.] == null)] | length' "$CONFIG_DIR/defaults.json" "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  BEFORE_MISSING="$output"
  [ "$BEFORE_MISSING" -gt 0 ]

  run_migration

  run jq -s '.[0] as $d | .[1] as $c | [$d | keys[] | select($c[.] == null)] | length' "$CONFIG_DIR/defaults.json" "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "migration --print-added returns number of inserted defaults" {
  cat > "$TEST_TEMP_DIR/.vbw-planning/config.json" <<'EOF'
{
  "effort": "balanced"
}
EOF

  run jq -s '.[0] as $d | .[1] as $c | [$d | keys[] | select($c[.] == null)] | length' "$CONFIG_DIR/defaults.json" "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  EXPECTED_ADDED="$output"

  run bash "$SCRIPTS_DIR/migrate-config.sh" --print-added "$TEST_TEMP_DIR/.vbw-planning/config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "$EXPECTED_ADDED" ]
}

@test "EXPECTED_FLAG_COUNT is 23 after prefer_teams addition" {
  # Verify session-start.sh has EXPECTED_FLAG_COUNT=23
  SCRIPT_COUNT=$(grep 'EXPECTED_FLAG_COUNT=' "$SCRIPTS_DIR/session-start.sh" | grep -oE '[0-9]+' | head -1)
  [ "$SCRIPT_COUNT" = "23" ]
}
