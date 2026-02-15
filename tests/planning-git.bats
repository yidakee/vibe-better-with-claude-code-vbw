#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir

  cd "$TEST_TEMP_DIR"
  git init -q
  git config user.name "VBW Test"
  git config user.email "vbw-test@example.com"

  echo "seed" > README.md
  git add README.md
  git commit -q -m "chore(init): seed"
}

teardown() {
  teardown_temp_dir
}

@test "sync-ignore adds .vbw-planning to root gitignore when planning_tracking=ignore" {
  cat > .vbw-planning/config.json <<'EOF'
{
  "planning_tracking": "ignore",
  "auto_push": "never"
}
EOF

  run bash "$SCRIPTS_DIR/planning-git.sh" sync-ignore .vbw-planning/config.json
  [ "$status" -eq 0 ]

  run grep -qx '\.vbw-planning/' .gitignore
  [ "$status" -eq 0 ]
}

@test "sync-ignore removes root ignore and writes transient planning ignore when commit mode" {
  cat > .gitignore <<'EOF'
.vbw-planning/
EOF

  cat > .vbw-planning/config.json <<'EOF'
{
  "planning_tracking": "commit",
  "auto_push": "never"
}
EOF

  run bash "$SCRIPTS_DIR/planning-git.sh" sync-ignore .vbw-planning/config.json
  [ "$status" -eq 0 ]

  run grep -qx '\.vbw-planning/' .gitignore
  [ "$status" -ne 0 ]

  run grep -q '^\.execution-state\.json$' .vbw-planning/.gitignore
  [ "$status" -eq 0 ]

  run grep -q '^\.context-\*\.md$' .vbw-planning/.gitignore
  [ "$status" -eq 0 ]
}

@test "commit-boundary creates planning artifacts commit in commit mode" {
  cat > .vbw-planning/config.json <<'EOF'
{
  "planning_tracking": "commit",
  "auto_push": "never"
}
EOF

  cat > .vbw-planning/STATE.md <<'EOF'
# State

Updated
EOF

  cat > CLAUDE.md <<'EOF'
# CLAUDE

Updated
EOF

  run bash "$SCRIPTS_DIR/planning-git.sh" commit-boundary "bootstrap project" .vbw-planning/config.json
  [ "$status" -eq 0 ]

  run git log -1 --pretty=%s
  [ "$status" -eq 0 ]
  [ "$output" = "chore(vbw): bootstrap project" ]
}

@test "commit-boundary is no-op in manual mode" {
  cat > .vbw-planning/config.json <<'EOF'
{
  "planning_tracking": "manual",
  "auto_push": "never"
}
EOF

  cat > .vbw-planning/STATE.md <<'EOF'
# State

Updated
EOF

  BEFORE=$(git rev-list --count HEAD)

  run bash "$SCRIPTS_DIR/planning-git.sh" commit-boundary "phase update" .vbw-planning/config.json
  [ "$status" -eq 0 ]

  AFTER=$(git rev-list --count HEAD)
  [ "$BEFORE" = "$AFTER" ]
}