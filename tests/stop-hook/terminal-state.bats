#!/usr/bin/env bats
# Tests for terminal state: synthesizer completion, result file creation, cleanup

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "synthesizer phase produces result file and cleans up state" {
  create_state_file phase="synthesizer" round="3" max_rounds="3" mode="analyst"
  add_round_to_state 1 "adv1" "crit1"
  add_round_to_state 2 "adv2" "crit2"
  add_round_to_state 3 "adv3" "crit3"
  setup_hook_input "Final synthesis output"
  run_stop_hook
  assert_success
  assert_output --partial "Anvil debate complete"
  assert_state_cleaned
  assert_result_exists
}

@test "result file contains question in heading" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" \
    question="Should we use microservices?"
  setup_hook_input "Synthesis content"
  run_stop_hook
  assert_result_contains "Anvil Analysis: Should we use microservices?"
}

@test "result file contains mode" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" mode="philosopher"
  setup_hook_input "Synthesis content"
  run_stop_hook
  assert_result_contains "philosopher"
}

@test "result file contains framework when set" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" framework="adr"
  setup_hook_input "ADR synthesis"
  run_stop_hook
  assert_result_contains "**Framework**: adr"
}

@test "result file contains focus when set" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" focus="security"
  setup_hook_input "Security synthesis"
  run_stop_hook
  assert_result_contains "**Focus**: security"
}

@test "result file contains research label yes" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" research="true"
  setup_hook_input "Researched synthesis"
  run_stop_hook
  assert_result_contains "**Research**: yes"
}

@test "result file contains research label no" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" research="false"
  setup_hook_input "Non-researched synthesis"
  run_stop_hook
  assert_result_contains "**Research**: no"
}

@test "result file contains context source when set" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" context_source="src/main.ts"
  setup_hook_input "Context synthesis"
  run_stop_hook
  assert_result_contains "**Context**: src/main.ts"
}

@test "result file contains personas when set" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "Sec"
  add_persona_to_state "startup-cfo" "CFO"
  setup_hook_input "Persona synthesis"
  run_stop_hook
  assert_result_contains "**Personas**: security-engineer,startup-cfo"
}

@test "result file contains synthesis output" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  setup_hook_input "The final conclusion is that microservices are good."
  run_stop_hook
  assert_result_contains "The final conclusion is that microservices are good."
}

@test "result file contains date" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  setup_hook_input "Synthesis"
  run_stop_hook
  assert_result_contains "**Date**:"
}

@test "synthesizer exits with code 0 (allows exit)" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  setup_hook_input "Final synthesis"
  run_stop_hook
  assert_success
}

# --- Full report structure ---

@test "result contains Executive Summary heading" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  setup_hook_input "My synthesis conclusion"
  run_stop_hook
  assert_result_contains "## Executive Summary"
}

@test "result contains Debate Record heading" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  add_round_to_state 1 "advocate arg" "critic arg"
  add_round_to_state 2 "advocate arg 2" "critic arg 2"
  setup_hook_input "Synthesis output"
  run_stop_hook
  assert_result_contains "## Debate Record"
}

@test "result contains advocate/critic content from rounds" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  add_round_to_state 1 "Microservices are great for scaling" "Monoliths are simpler"
  add_round_to_state 2 "But scaling matters" "Complexity kills"
  setup_hook_input "Final balanced view"
  run_stop_hook
  assert_result_contains "Microservices are great for scaling"
  assert_result_contains "Monoliths are simpler"
  assert_result_contains "But scaling matters"
  assert_result_contains "Complexity kills"
}

@test "synthesis appears after Executive Summary heading" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  add_round_to_state 1 "adv" "crit"
  setup_hook_input "The balanced conclusion"
  run_stop_hook
  local rf
  rf=$(result_file)
  # Executive Summary should come before the synthesis text
  local summary_line debate_line
  summary_line=$(grep -n "## Executive Summary" "$rf" | head -1 | cut -d: -f1)
  debate_line=$(grep -n "The balanced conclusion" "$rf" | head -1 | cut -d: -f1)
  [ "$summary_line" -lt "$debate_line" ]
}

@test "custom output path used when set in frontmatter" {
  local custom_path="${TEST_DIR}/custom-output/report.md"
  create_state_file phase="synthesizer" round="2" max_rounds="2" \
    output="$custom_path"
  setup_hook_input "Custom path synthesis"
  run_stop_hook
  assert_success
  [ -f "$custom_path" ]
  grep -qF "Custom path synthesis" "$custom_path"
}

@test "default path used when output not set" {
  create_state_file phase="synthesizer" round="2" max_rounds="2"
  setup_hook_input "Default path synthesis"
  run_stop_hook
  assert_success
  assert_result_exists
  assert_result_contains "Default path synthesis"
}

@test "stakeholder transcript preserved in debate record" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" \
    mode="stakeholders" stakeholders="Engineering,Product"
  # Add stakeholder rounds
  local sf
  sf=$(state_file)
  printf '\n## Stakeholder 1: Engineering\n\nEngineering perspective here\n' >> "$sf"
  printf '\n## Stakeholder 2: Product\n\nProduct perspective here\n' >> "$sf"
  setup_hook_input "Stakeholder synthesis"
  run_stop_hook
  assert_result_contains "Engineering perspective here"
  assert_result_contains "Product perspective here"
}

@test "parent directory created for custom output path" {
  local custom_path="${TEST_DIR}/deep/nested/dir/report.md"
  create_state_file phase="synthesizer" round="2" max_rounds="2" \
    output="$custom_path"
  setup_hook_input "Nested output synthesis"
  run_stop_hook
  assert_success
  [ -f "$custom_path" ]
}

@test "html output path produces HTML when bun available" {
  if ! command -v bun >/dev/null 2>&1; then
    skip "bun not available"
  fi
  local html_path="${TEST_DIR}/report.html"
  create_state_file phase="synthesizer" round="1" max_rounds="1" \
    output="$html_path"
  add_round_to_state 1 "Advocate argument" "Critic argument"
  setup_hook_input "HTML synthesis output"
  run_stop_hook
  assert_success
  [ -f "$html_path" ]
  grep -qF "<!DOCTYPE html>" "$html_path"
  grep -qF "HTML synthesis output" "$html_path"
  grep -qF "executive-summary" "$html_path"
}

@test "console message shows actual output path" {
  local custom_path="${TEST_DIR}/my-report.md"
  create_state_file phase="synthesizer" round="2" max_rounds="2" \
    output="$custom_path"
  setup_hook_input "Synthesis"
  run_stop_hook
  assert_output --partial "Result saved to $custom_path"
}
