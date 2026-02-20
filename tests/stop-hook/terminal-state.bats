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

@test "result file contains question" {
  create_state_file phase="synthesizer" round="2" max_rounds="2" \
    question="\"Should we use microservices?\""
  setup_hook_input "Synthesis content"
  run_stop_hook
  assert_result_contains "Should we use microservices?"
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
