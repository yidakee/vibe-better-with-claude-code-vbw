#!/bin/bash
# Shared test helper for VBW bats tests

# Project root (relative to tests/ dir)
export PROJECT_ROOT="${BATS_TEST_DIRNAME}/.."
export SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
export CONFIG_DIR="${PROJECT_ROOT}/config"

# Create temp directory for test isolation
setup_temp_dir() {
  export TEST_TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning"
}

# Clean up temp directory
teardown_temp_dir() {
  [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Create minimal config.json for tests
create_test_config() {
  local dir="${1:-.vbw-planning}"
  cat > "$TEST_TEMP_DIR/$dir/config.json" <<'CONF'
{
  "effort": "balanced",
  "autonomy": "standard",
  "auto_commit": true,
  "verification_tier": "standard",
  "model_profile": "balanced",
  "model_overrides": {},
  "agent_teams": true,
  "max_tasks_per_plan": 5,
  "context_compiler": true,
  "v3_delta_context": false,
  "v3_context_cache": false,
  "v3_plan_research_persist": false,
  "v3_metrics": false,
  "v3_contract_lite": false,
  "v3_lock_lite": false,
  "v3_validation_gates": false,
  "v3_smart_routing": false,
  "v3_event_log": false,
  "v3_schema_validation": false,
  "v3_snapshot_resume": false
}
CONF
}
