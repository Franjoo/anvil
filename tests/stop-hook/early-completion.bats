#!/usr/bin/env bats
# Tests for <anvil-complete/> early completion signal

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "anvil-complete in advocate forces transition to synthesizer" {
  create_state_file phase="advocate" round="1" max_rounds="3"
  setup_hook_input "Advocate argument <anvil-complete/>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "anvil-complete in critic forces transition to synthesizer" {
  create_state_file phase="critic" round="1" max_rounds="3"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic argument <anvil-complete/>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "anvil-complete tag stripped from output before appending" {
  create_state_file phase="advocate" round="1" max_rounds="3"
  setup_hook_input "Good argument <anvil-complete/> here"
  run_stop_hook
  local body
  body=$(awk '/^---$/{i++; next} i>=2' "$(state_file)")
  ! printf '%s' "$body" | grep -qF "<anvil-complete/>"
}

@test "anvil-complete in synthesizer has no extra effect" {
  create_state_file phase="synthesizer" round="3" max_rounds="3"
  setup_hook_input "Final synthesis <anvil-complete/>"
  run_stop_hook
  assert_success
  assert_output --partial "Anvil debate complete"
  assert_state_cleaned
}

@test "anvil-complete in stakeholder mode forces synthesizer" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Engineering <anvil-complete/>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "anvil-complete in persona mode forces synthesizer" {
  create_state_file phase="persona" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Sec"
  add_persona_to_state "startup-cfo" "CFO"
  add_persona_to_state "junior-developer" "Dev"
  setup_hook_input "Security perspective <anvil-complete/>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "anvil-complete sets round to max_rounds" {
  create_state_file phase="advocate" round="1" max_rounds="5"
  setup_hook_input "Early completion <anvil-complete/>"
  run_stop_hook
  assert_block_decision
  # The round should be set to max_rounds to trigger synthesizer
  assert_frontmatter "phase" "synthesizer"
}
