#!/usr/bin/env bats
# Tests for all error paths in setup-anvil.sh (exit 1 + stderr)

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/assertions"

# Helper: run setup script in TEST_DIR
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- Missing question ---

@test "error: no arguments at all" {
  run_setup
  assert_failure
  assert_output --partial "No question provided"
}

@test "error: only flags, no question" {
  run_setup --mode analyst --rounds 3
  assert_failure
  assert_output --partial "No question provided"
}

# --- --mode errors ---

@test "error: --mode without value" {
  run_setup "question" --mode
  assert_failure
  assert_output --partial "--mode requires a value"
}

@test "error: --mode with invalid value" {
  run_setup "question" --mode invalid-mode
  assert_failure
  assert_output --partial "Invalid mode"
}

# --- --rounds errors ---

@test "error: --rounds without value" {
  run_setup "question" --rounds
  assert_failure
  assert_output --partial "--rounds requires a number"
}

@test "error: --rounds with non-numeric value" {
  run_setup "question" --rounds abc
  assert_failure
  assert_output --partial "--rounds must be a positive integer"
}

@test "error: --rounds 0" {
  run_setup "question" --rounds 0
  assert_failure
  assert_output --partial "--rounds must be between 1 and 5"
}

@test "error: --rounds 6 (exceeds max)" {
  run_setup "question" --rounds 6
  assert_failure
  assert_output --partial "--rounds must be between 1 and 5"
}

# --- --position errors ---

@test "error: --position without value" {
  run_setup "question" --position
  assert_failure
  assert_output --partial "--position requires a value"
}

@test "error: devils-advocate mode without --position" {
  run_setup "question" --mode devils-advocate
  assert_failure
  assert_output --partial "--position is required for devils-advocate"
}

# --- --framework errors ---

@test "error: --framework without value" {
  run_setup "question" --framework
  assert_failure
  assert_output --partial "--framework requires a value"
}

@test "error: --framework with invalid value" {
  run_setup "question" --framework invalid
  assert_failure
  assert_output --partial "Invalid framework"
}

# --- --focus errors ---

@test "error: --focus without value" {
  run_setup "question" --focus
  assert_failure
  assert_output --partial "--focus requires a value"
}

# --- --context errors ---

@test "error: --context without value" {
  run_setup "question" --context
  assert_failure
  assert_output --partial "--context requires a path"
}

@test "error: --context with nonexistent path" {
  run_setup "question" --context /nonexistent/path
  assert_failure
  assert_output --partial "Context path not found"
}

# --- --pr errors ---

@test "error: --pr without value" {
  run_setup "question" --pr
  assert_failure
  assert_output --partial "--pr requires a PR number"
}

@test "error: --pr with non-numeric value" {
  run_setup "question" --pr abc
  assert_failure
  assert_output --partial "--pr must be a number"
}

# --- --follow-up errors ---

@test "error: --follow-up without value" {
  run_setup "question" --follow-up
  assert_failure
  assert_output --partial "--follow-up requires a file path"
}

@test "error: --follow-up with nonexistent file" {
  run_setup "question" --follow-up /nonexistent/file.md
  assert_failure
  assert_output --partial "Follow-up file not found"
}

# --- --versus errors ---

@test "error: --versus without both files (one arg)" {
  run_setup "question" --versus only-one.md
  assert_failure
  assert_output --partial "--versus requires two file paths"
}

@test "error: --versus at end of args (no files)" {
  run_setup "question" --versus
  assert_failure
  assert_output --partial "--versus requires two file paths"
}

@test "error: --versus with nonexistent first file" {
  echo "content" > "${TEST_DIR}/exists.md"
  run_setup "question" --versus /nonexistent.md "${TEST_DIR}/exists.md"
  assert_failure
  assert_output --partial "Versus file not found"
}

@test "error: --versus with nonexistent second file" {
  echo "content" > "${TEST_DIR}/exists.md"
  run_setup "question" --versus "${TEST_DIR}/exists.md" /nonexistent.md
  assert_failure
  assert_output --partial "Versus file not found"
}

# --- --interactive errors ---

@test "error: --interactive with 3+ personas" {
  run_setup "question" --interactive --persona "persona A" --persona "persona B" --persona "persona C"
  assert_failure
  assert_output --partial "--interactive is not supported with 3+ personas"
}

# --- --stakeholders errors ---

@test "error: --stakeholders without value" {
  run_setup "question" --stakeholders
  assert_failure
  assert_output --partial "--stakeholders requires a comma-separated list"
}

@test "error: --stakeholders with explicit non-stakeholders mode" {
  run_setup "question" --mode philosopher --stakeholders "eng,product"
  assert_failure
  assert_output --partial "--stakeholders can only be used with --mode stakeholders"
}

# --- --persona errors ---

@test "error: --persona without value" {
  run_setup "question" --persona
  assert_failure
  assert_output --partial "--persona requires a value"
}

@test "error: single persona (need at least 2)" {
  run_setup "question" --persona "Only One"
  assert_failure
  assert_output --partial "requires at least 2 personas"
}

@test "error: --persona with explicit --mode" {
  run_setup "question" --mode analyst --persona "A" --persona "B"
  assert_failure
  assert_output --partial "--persona and --mode are mutually exclusive"
}

# --- Active debate ---

@test "error: active debate already exists" {
  create_state_file
  run_setup "question"
  assert_failure
  assert_output --partial "already active"
}
