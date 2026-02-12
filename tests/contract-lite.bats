#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/phases/03-test-phase"

  # Create a sample PLAN.md
  cat > "$TEST_TEMP_DIR/.vbw-planning/phases/03-test-phase/03-01-PLAN.md" <<'EOF'
---
phase: 3
plan: 1
title: "Test Plan"
wave: 1
depends_on: []
must_haves:
  - "Feature A implemented"
  - "Feature B tested"
---

# Plan 03-01: Test Plan

## Tasks

### Task 1: Implement feature A
- **Files:** `scripts/feature-a.sh`, `config/settings.json`
- **Action:** Create feature A.

### Task 2: Test feature B
- **Files:** `tests/feature-b.bats`
- **Action:** Add tests.
EOF
}

teardown() {
  teardown_temp_dir
}

@test "generate-contract.sh exits 0 when v3_contract_lite=false" {
  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"
  [ "$status" -eq 0 ]
  [ ! -d ".vbw-planning/.contracts" ]
}

@test "generate-contract.sh creates contract JSON when flag=true" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  run bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"
  [ "$status" -eq 0 ]
  [ -f ".vbw-planning/.contracts/3-1.json" ]
}

@test "generate-contract.sh contract has correct must_haves" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"

  run jq -r '.must_haves | length' ".vbw-planning/.contracts/3-1.json"
  [ "$output" = "2" ]

  run jq -r '.must_haves[0]' ".vbw-planning/.contracts/3-1.json"
  [ "$output" = "Feature A implemented" ]
}

@test "generate-contract.sh contract has allowed_paths from task Files" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"

  # Should include files from both tasks
  run jq -r '.allowed_paths | length' ".vbw-planning/.contracts/3-1.json"
  [ "$output" -ge 3 ]

  run jq -r '.allowed_paths[]' ".vbw-planning/.contracts/3-1.json"
  echo "$output" | grep -q "scripts/feature-a.sh"
  echo "$output" | grep -q "config/settings.json"
  echo "$output" | grep -q "tests/feature-b.bats"
}

@test "generate-contract.sh contract has correct task_count" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"

  run jq -r '.task_count' ".vbw-planning/.contracts/3-1.json"
  [ "$output" = "2" ]
}

@test "validate-contract.sh exits 0 when v3_contract_lite=false" {
  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/validate-contract.sh" start "nonexistent.json" 1
  [ "$status" -eq 0 ]
}

@test "validate-contract.sh start mode passes for valid task" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"

  run bash "$SCRIPTS_DIR/validate-contract.sh" start ".vbw-planning/.contracts/3-1.json" 1
  [ "$status" -eq 0 ]
}

@test "validate-contract.sh start mode logs violation for out-of-range task" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"
  jq '.v3_metrics = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"

  run bash "$SCRIPTS_DIR/validate-contract.sh" start ".vbw-planning/.contracts/3-1.json" 99
  [ "$status" -eq 0 ]

  # Should have logged a scope_violation metric
  [ -f ".vbw-planning/.metrics/run-metrics.jsonl" ]
  grep -q "scope_violation" ".vbw-planning/.metrics/run-metrics.jsonl"
}

@test "validate-contract.sh end mode passes for in-scope files" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"

  run bash "$SCRIPTS_DIR/validate-contract.sh" end ".vbw-planning/.contracts/3-1.json" 1 "scripts/feature-a.sh"
  [ "$status" -eq 0 ]
}

@test "validate-contract.sh end mode logs violation for out-of-scope files" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_contract_lite = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"
  jq '.v3_metrics = true' ".vbw-planning/config.json" > ".vbw-planning/config.tmp" && mv ".vbw-planning/config.tmp" ".vbw-planning/config.json"

  bash "$SCRIPTS_DIR/generate-contract.sh" ".vbw-planning/phases/03-test-phase/03-01-PLAN.md"

  run bash "$SCRIPTS_DIR/validate-contract.sh" end ".vbw-planning/.contracts/3-1.json" 1 "some/random/file.txt"
  [ "$status" -eq 0 ]

  # Should have logged a scope_violation metric
  [ -f ".vbw-planning/.metrics/run-metrics.jsonl" ]
  grep -q "scope_violation" ".vbw-planning/.metrics/run-metrics.jsonl"
  grep -q "out_of_scope" ".vbw-planning/.metrics/run-metrics.jsonl"
}
