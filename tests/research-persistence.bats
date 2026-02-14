#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
}

teardown() {
  teardown_temp_dir
}

@test "research-persistence: RESEARCH.md template has required sections" {
  # Validates the tracked template has the 4 sections that compile-context
  # and research-warn depend on at runtime.
  RESEARCH_FILE="$TEST_TEMP_DIR/01-RESEARCH.md"
  cp "$PROJECT_ROOT/templates/RESEARCH.md" "$RESEARCH_FILE"

  [ -f "$RESEARCH_FILE" ]

  # All 4 required section headers must be present exactly once
  [ "$(grep -c "^## Findings$" "$RESEARCH_FILE")" -eq 1 ]
  [ "$(grep -c "^## Relevant Patterns$" "$RESEARCH_FILE")" -eq 1 ]
  [ "$(grep -c "^## Risks$" "$RESEARCH_FILE")" -eq 1 ]
  [ "$(grep -c "^## Recommendations$" "$RESEARCH_FILE")" -eq 1 ]
}

@test "research-warn: JSON schema validation - flag disabled" {
  cd "$TEST_TEMP_DIR"
  run bash "$SCRIPTS_DIR/research-warn.sh" "$TEST_TEMP_DIR/.vbw-planning"
  [ "$status" -eq 0 ]

  # Validate JSON schema: must have check, result, reason keys
  echo "$output" | jq -e 'has("check")'
  echo "$output" | jq -e 'has("result")'
  echo "$output" | jq -e 'has("reason")'
}

@test "research-warn: JSON schema validation - turbo effort" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_plan_research_persist = true | .effort = "turbo"' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  run bash "$SCRIPTS_DIR/research-warn.sh" "$TEST_TEMP_DIR/.vbw-planning"
  [ "$status" -eq 0 ]

  # Validate JSON schema
  echo "$output" | jq -e 'has("check")'
  echo "$output" | jq -e 'has("result")'
  echo "$output" | jq -e 'has("reason")'
}

@test "research-warn: JSON schema validation - missing RESEARCH.md" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_plan_research_persist = true | .effort = "balanced"' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  mkdir -p "$TEST_TEMP_DIR/phase-dir"
  run bash "$SCRIPTS_DIR/research-warn.sh" "$TEST_TEMP_DIR/phase-dir"
  [ "$status" -eq 0 ]

  # Extract first line (JSON) — stderr warning also captured by run
  JSON_LINE=$(echo "$output" | head -1)
  echo "$JSON_LINE" | jq -e 'has("check")'
  echo "$JSON_LINE" | jq -e 'has("result")'
  echo "$JSON_LINE" | jq -e 'has("reason")'
}

@test "research-warn: JSON schema validation - RESEARCH.md exists" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_plan_research_persist = true | .effort = "thorough"' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  mkdir -p "$TEST_TEMP_DIR/phase-dir"
  echo "# Research" > "$TEST_TEMP_DIR/phase-dir/02-01-RESEARCH.md"
  run bash "$SCRIPTS_DIR/research-warn.sh" "$TEST_TEMP_DIR/phase-dir"
  [ "$status" -eq 0 ]

  # Validate JSON schema
  echo "$output" | jq -e 'has("check")'
  echo "$output" | jq -e 'has("result")'
  echo "$output" | jq -e 'has("reason")'
}

@test "research-persistence: compile-context includes RESEARCH.md" {
  # Setup: copy Phase 1 structure to temp with isolated planning dir
  TEMP_PLANNING="$TEST_TEMP_DIR/isolated-planning"
  TEMP_PHASES="$TEMP_PLANNING/phases"
  mkdir -p "$TEMP_PHASES/01-test-phase"

  # Create minimal config with caching disabled to avoid cache hits
  mkdir -p "$TEMP_PLANNING"
  echo '{"v3_context_cache": false}' > "$TEMP_PLANNING/config.json"

  # Create minimal ROADMAP.md with Phase 01 definition
  cat > "$TEMP_PLANNING/ROADMAP.md" <<'ROADMAP'
# Roadmap

## Phase 01: Test Phase
**Goal**: Test phase goal
**Success Criteria**: Test criteria
**Requirements**: Not available
ROADMAP

  # Use tracked template as fixture source to avoid dependence on local runtime
  # .vbw-planning state in the plugin source repository.
  cp "$PROJECT_ROOT/templates/RESEARCH.md" "$TEMP_PHASES/01-test-phase/01-RESEARCH.md"

  # Temporarily override CLAUDE_DIR to use isolated planning dir
  ORIG_CLAUDE_DIR="$CLAUDE_DIR"
  export CLAUDE_DIR="$TEST_TEMP_DIR"

  # Create isolated .vbw-planning symlink in temp dir
  ln -s "$TEMP_PLANNING" "$TEST_TEMP_DIR/.vbw-planning"

  # Run compile-context.sh for phase 01, role lead
  cd "$TEST_TEMP_DIR"
  bash "$PROJECT_ROOT/scripts/compile-context.sh" 01 lead "$TEMP_PHASES"

  # Restore CLAUDE_DIR
  export CLAUDE_DIR="$ORIG_CLAUDE_DIR"

  # Verify output contains Research Findings section
  CONTEXT_FILE="$TEMP_PHASES/01-test-phase/.context-lead.md"
  [ -f "$CONTEXT_FILE" ]

  # Check for section header
  grep -q "^### Research Findings$" "$CONTEXT_FILE"

  # Check that actual research content is included (>10 lines from RESEARCH.md)
  RESEARCH_LINES=$(grep -c "^##" "$CONTEXT_FILE" || echo 0)
  [ "$RESEARCH_LINES" -ge 4 ]
}

@test "research-persistence: vibe plan mode respects flag=false" {
  cd "$TEST_TEMP_DIR"

  # Setup temp config with v3_plan_research_persist=false (default in defaults.json)
  jq '.v3_plan_research_persist = false | .effort = "thorough"' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json

  # Create phase dir without RESEARCH.md
  mkdir -p "$TEST_TEMP_DIR/phase-dir"

  # Call research-warn.sh to validate skip path
  run bash "$SCRIPTS_DIR/research-warn.sh" "$TEST_TEMP_DIR/phase-dir"
  [ "$status" -eq 0 ]

  # Verify output is result=ok with reason="research_persist disabled"
  echo "$output" | jq -e '.result == "ok"'
  echo "$output" | jq -e '.reason == "research_persist disabled"'
}
