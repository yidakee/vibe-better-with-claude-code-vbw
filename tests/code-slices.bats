#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/phases/01-test"
  # Enable delta context
  jq '.v3_delta_context = true' "$TEST_TEMP_DIR/.vbw-planning/config.json" > "$TEST_TEMP_DIR/.vbw-planning/config.json.tmp" \
    && mv "$TEST_TEMP_DIR/.vbw-planning/config.json.tmp" "$TEST_TEMP_DIR/.vbw-planning/config.json"
  # Create ROADMAP.md with phase info
  cat > "$TEST_TEMP_DIR/.vbw-planning/ROADMAP.md" << 'ROADMAP'
## Phase 1: Test Phase

**Goal:** Test code slices
**Reqs:** REQ-08
**Success:** Code slices included in context
ROADMAP
}

teardown() {
  teardown_temp_dir
}

@test "compile-context: includes Code Slices section when delta enabled" {
  cd "$TEST_TEMP_DIR"
  # Create a small source file that delta-files.sh would find
  mkdir -p src
  echo 'console.log("hello")' > src/test.js
  # Create a plan
  cat > .vbw-planning/phases/01-test/01-01-PLAN.md << 'PLAN'
---
phase: 1
plan: 1
title: Test
wave: 1
depends_on: []
files_modified:
  - src/test.js
---
Test plan
PLAN
  # Initialize git so delta-files.sh has data
  git init "$TEST_TEMP_DIR" > /dev/null 2>&1
  git -C "$TEST_TEMP_DIR" add src/test.js > /dev/null 2>&1
  run bash "$SCRIPTS_DIR/compile-context.sh" 01 dev "$TEST_TEMP_DIR/.vbw-planning/phases" "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/01-01-PLAN.md"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/.context-dev.md" ]
  grep -q "Code Slices" "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/.context-dev.md"
}

@test "compile-context: omits Code Slices when delta disabled" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_delta_context = false' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  cat > .vbw-planning/phases/01-test/01-01-PLAN.md << 'PLAN'
---
phase: 1
plan: 1
title: Test
wave: 1
depends_on: []
---
Test plan
PLAN
  run bash "$SCRIPTS_DIR/compile-context.sh" 01 dev "$TEST_TEMP_DIR/.vbw-planning/phases" "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/01-01-PLAN.md"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/.context-dev.md" ]
  ! grep -q "Code Slices" "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/.context-dev.md"
}

@test "compile-context: includes file content in code slices" {
  cd "$TEST_TEMP_DIR"
  mkdir -p src
  printf 'function hello() {\n  return "world";\n}\n' > src/small.js
  cat > .vbw-planning/phases/01-test/01-01-PLAN.md << 'PLAN'
---
phase: 1
plan: 1
title: Test
wave: 1
depends_on: []
files_modified:
  - src/small.js
---
Test plan
PLAN
  git init "$TEST_TEMP_DIR" > /dev/null 2>&1
  git -C "$TEST_TEMP_DIR" add src/small.js > /dev/null 2>&1
  run bash "$SCRIPTS_DIR/compile-context.sh" 01 dev "$TEST_TEMP_DIR/.vbw-planning/phases" "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/01-01-PLAN.md"
  [ "$status" -eq 0 ]
  grep -q 'function hello' "$TEST_TEMP_DIR/.vbw-planning/phases/01-test/.context-dev.md"
}
