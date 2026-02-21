#!/usr/bin/env bats
# Tests for argument parsing and defaults in setup-anvil.sh

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/assertions"

# Helper: run setup script in TEST_DIR and capture state file
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- Defaults ---

@test "default mode is analyst" {
  run_setup "Should we use microservices?"
  assert_success
  assert_frontmatter "mode" "analyst"
}

@test "default rounds is 3" {
  run_setup "question"
  assert_success
  assert_frontmatter "max_rounds" "3"
}

@test "default position is null" {
  run_setup "question"
  assert_success
  assert_frontmatter "position" "null"
}

@test "default research is false" {
  run_setup "question"
  assert_success
  assert_frontmatter "research" "false"
}

@test "default framework is empty" {
  run_setup "question"
  assert_success
  assert_frontmatter "framework" ""
}

@test "default interactive is false" {
  run_setup "question"
  assert_success
  assert_frontmatter "interactive" "false"
}

@test "default versus is false" {
  run_setup "question"
  assert_success
  assert_frontmatter "versus" "false"
}

@test "initial phase is advocate" {
  run_setup "question"
  assert_success
  assert_frontmatter "phase" "advocate"
}

@test "initial round is 1" {
  run_setup "question"
  assert_success
  assert_frontmatter "round" "1"
}

# --- Explicit flags ---

@test "explicit --mode philosopher" {
  run_setup "question" --mode philosopher
  assert_success
  assert_frontmatter "mode" "philosopher"
}

@test "explicit --mode devils-advocate" {
  run_setup "question" --mode devils-advocate --position "I believe X"
  assert_success
  assert_frontmatter "mode" "devils-advocate"
}

@test "explicit --rounds 5" {
  run_setup "question" --rounds 5
  assert_success
  assert_frontmatter "max_rounds" "5"
}

@test "explicit --rounds 1" {
  run_setup "question" --rounds 1
  assert_success
  assert_frontmatter "max_rounds" "1"
}

@test "explicit --position" {
  run_setup "question" --mode devils-advocate --position "I think microservices are bad"
  assert_success
  assert_frontmatter "position" "I think microservices are bad"
}

@test "--research flag" {
  run_setup "question" --research
  assert_success
  assert_frontmatter "research" "true"
}

@test "--framework adr" {
  run_setup "question" --framework adr
  assert_success
  assert_frontmatter "framework" "adr"
}

@test "--framework pre-mortem" {
  run_setup "question" --framework pre-mortem
  assert_success
  assert_frontmatter "framework" "pre-mortem"
}

@test "--framework red-team" {
  run_setup "question" --framework red-team
  assert_success
  assert_frontmatter "framework" "red-team"
}

@test "--framework rfc" {
  run_setup "question" --framework rfc
  assert_success
  assert_frontmatter "framework" "rfc"
}

@test "--framework risks" {
  run_setup "question" --framework risks
  assert_success
  assert_frontmatter "framework" "risks"
}

@test "--focus security" {
  run_setup "question" --focus security
  assert_success
  assert_frontmatter "focus" "security"
}

@test "--focus custom value" {
  run_setup "question" --focus "team morale"
  assert_success
  assert_frontmatter "focus" "team morale"
}

@test "--interactive flag" {
  run_setup "question" --interactive
  assert_success
  assert_frontmatter "interactive" "true"
}

@test "default output is Desktop HTML path" {
  run_setup "question"
  assert_success
  local output_val
  output_val=$(get_frontmatter "output" "$(state_file)")
  [[ "$output_val" == */Desktop/anvil-*-question.html ]]
}

@test "--output stores path" {
  run_setup "question" --output /tmp/report.html
  assert_success
  assert_frontmatter "output" "/tmp/report.html"
}

@test "--output without value fails" {
  run_setup "question" --output
  assert_failure
}

@test "--diff flag" {
  run_setup "question" --diff
  assert_success
  # state file should exist, diff context attempted
  assert_state_exists
}

# --- Multi-word question ---

@test "multi-word question without quotes" {
  run_setup Should we use microservices
  assert_success
  assert_frontmatter "question" "Should we use microservices"
}

@test "question with special characters" {
  run_setup "Is TypeScript's type system worth the complexity?"
  assert_success
  assert_state_exists
}

@test "question with double quotes is escaped in YAML" {
  run_setup 'He said "hello world" today'
  assert_success
  assert_state_exists
  # The state file frontmatter should be valid (not corrupted)
  assert_frontmatter "active" "true"
}

@test "question with backslash is escaped in YAML" {
  run_setup 'Path is C:\Users\test'
  assert_success
  assert_state_exists
  assert_frontmatter "active" "true"
}

@test "position with double quotes is escaped" {
  run_setup "topic" --mode devils-advocate --position 'I think "microservices" are overhyped'
  assert_success
  assert_state_exists
  assert_frontmatter "active" "true"
}

@test "--rounds negative rejected" {
  run_setup "question" --rounds -1
  assert_failure
}

@test "--rounds decimal rejected" {
  run_setup "question" --rounds 1.5
  assert_failure
}

# --- Combination flags ---

@test "multiple flags combined" {
  run_setup "question" --mode philosopher --rounds 2 --research --framework adr --focus performance
  assert_success
  assert_frontmatter "mode" "philosopher"
  assert_frontmatter "max_rounds" "2"
  assert_frontmatter "research" "true"
  assert_frontmatter "framework" "adr"
  assert_frontmatter "focus" "performance"
}
