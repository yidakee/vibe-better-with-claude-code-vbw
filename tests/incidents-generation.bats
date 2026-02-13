#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/.events"
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/phases/01-test"
}

teardown() {
  teardown_temp_dir
}

@test "generate-incidents: creates INCIDENTS.md from task_blocked events" {
  cd "$TEST_TEMP_DIR"
  cat > .vbw-planning/.events/event-log.jsonl << 'EVENTS'
{"ts":"2026-01-01T00:00:00Z","event":"task_blocked","phase":1,"data":{"task_id":"1-1-T1","reason":"dependency missing","next_action":"escalate_lead"}}
{"ts":"2026-01-01T00:01:00Z","event":"task_blocked","phase":1,"data":{"task_id":"1-1-T2","reason":"file conflict","next_action":"retry"}}
EVENTS
  run bash "$SCRIPTS_DIR/generate-incidents.sh" 1
  [ "$status" -eq 0 ]
  [ -f ".vbw-planning/phases/01-test/01-INCIDENTS.md" ]
  grep -q "Blockers (2)" ".vbw-planning/phases/01-test/01-INCIDENTS.md"
  grep -q "escalate_lead" ".vbw-planning/phases/01-test/01-INCIDENTS.md"
}

@test "generate-incidents: includes task_completion_rejected events" {
  cd "$TEST_TEMP_DIR"
  cat > .vbw-planning/.events/event-log.jsonl << 'EVENTS'
{"ts":"2026-01-01T00:00:00Z","event":"task_completion_rejected","phase":1,"data":{"task_id":"1-1-T1","reason":"tests failing"}}
EVENTS
  run bash "$SCRIPTS_DIR/generate-incidents.sh" 1
  [ "$status" -eq 0 ]
  [ -f ".vbw-planning/phases/01-test/01-INCIDENTS.md" ]
  grep -q "Rejections (1)" ".vbw-planning/phases/01-test/01-INCIDENTS.md"
}

@test "generate-incidents: exits 0 with no output when no incidents" {
  cd "$TEST_TEMP_DIR"
  echo '{"ts":"2026-01-01T00:00:00Z","event":"phase_start","phase":1}' > .vbw-planning/.events/event-log.jsonl
  run bash "$SCRIPTS_DIR/generate-incidents.sh" 1
  [ "$status" -eq 0 ]
  [ ! -f ".vbw-planning/phases/01-test/01-INCIDENTS.md" ]
}

@test "generate-incidents: filters by phase number" {
  cd "$TEST_TEMP_DIR"
  cat > .vbw-planning/.events/event-log.jsonl << 'EVENTS'
{"ts":"2026-01-01T00:00:00Z","event":"task_blocked","phase":1,"data":{"task_id":"1-1-T1","reason":"blocked"}}
{"ts":"2026-01-01T00:01:00Z","event":"task_blocked","phase":2,"data":{"task_id":"2-1-T1","reason":"other block"}}
EVENTS
  run bash "$SCRIPTS_DIR/generate-incidents.sh" 1
  [ "$status" -eq 0 ]
  [ -f ".vbw-planning/phases/01-test/01-INCIDENTS.md" ]
  grep -q "Total: 1 incidents" ".vbw-planning/phases/01-test/01-INCIDENTS.md"
}
