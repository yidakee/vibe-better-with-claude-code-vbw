#!/usr/bin/env bats

load test_helper

@test "passes valid conventional commit" {
  INPUT='{"tool_input":{"command":"git commit -m \"feat(core): add new feature\""}}'
  run bash -c "echo '$INPUT' | bash '$SCRIPTS_DIR/validate-commit.sh'"
  [ "$status" -eq 0 ]
}

@test "flags invalid commit format" {
  INPUT='{"tool_input":{"command":"git commit -m \"bad commit message\""}}'
  run bash -c "echo '$INPUT' | bash '$SCRIPTS_DIR/validate-commit.sh'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "does not match format"
}

@test "passes non-commit commands" {
  INPUT='{"tool_input":{"command":"git status"}}'
  run bash -c "echo '$INPUT' | bash '$SCRIPTS_DIR/validate-commit.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "validates heredoc-style commits" {
  INPUT=$(printf '{"tool_input":{"command":"git commit -m \\"$(cat <<'"'"'EOF'"'"'\\nfeat(test): valid heredoc commit\\n\\nCo-Authored-By: Test\\nEOF\\n)\\""}}'  )
  run bash -c "echo '$INPUT' | bash '$SCRIPTS_DIR/validate-commit.sh'"
  [ "$status" -eq 0 ]
}
