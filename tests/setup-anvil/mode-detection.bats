#!/usr/bin/env bats
# Tests for mode auto-detection and explicit mode setting

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/assertions"

run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "default mode is analyst when no flags" {
  run_setup "question"
  assert_frontmatter "mode" "analyst"
}

@test "auto-detect stakeholders mode from --stakeholders flag" {
  run_setup "question" --stakeholders "Eng,Product"
  assert_frontmatter "mode" "stakeholders"
}

@test "explicit --mode stakeholders without --stakeholders gets defaults" {
  run_setup "question" --mode stakeholders
  assert_frontmatter "mode" "stakeholders"
  local stakeholders
  stakeholders=$(get_frontmatter "stakeholders" "$(state_file)")
  [[ "$stakeholders" == *"Engineering"* ]]
}

@test "explicit --mode philosopher stays philosopher" {
  run_setup "question" --mode philosopher
  assert_frontmatter "mode" "philosopher"
}

@test "explicit --mode devils-advocate requires position" {
  run_setup "question" --mode devils-advocate --position "I think X"
  assert_frontmatter "mode" "devils-advocate"
}

@test "personas do not override mode (mode stays analyst default)" {
  run_setup "question" --persona "A" --persona "B"
  assert_frontmatter "mode" "analyst"
}
