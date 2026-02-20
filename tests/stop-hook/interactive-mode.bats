#!/usr/bin/env bats
# Tests for interactive mode: pause, steering, skip-to-synthesis

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "interactive pause prompt includes round summary instructions" {
  create_state_file phase="critic" round="1" max_rounds="3" interactive="true"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic argument"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "Interactive Steering"
  assert_reason_contains "AskUserQuestion"
}

@test "interactive pause system message correct" {
  create_state_file phase="critic" round="1" max_rounds="3" interactive="true"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic argument"
  run_stop_hook
  assert_system_message_contains "INTERACTIVE PAUSE"
}

@test "interactive pause prompt includes debate transcript" {
  create_state_file phase="critic" round="1" max_rounds="3" interactive="true"
  add_round_to_state 1 "First advocate argument"
  setup_hook_input "First critic rebuttal"
  run_stop_hook
  assert_reason_contains "First advocate argument"
}

@test "steering directive injected into next advocate prompt" {
  create_state_file phase="interactive-pause" round="1" max_rounds="3" interactive="true"
  setup_hook_input "Summary <anvil-steering>Focus on security implications</anvil-steering>"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "User Steering Directive"
  assert_reason_contains "Focus on security implications"
}

@test "steering 'none' does not inject directive" {
  create_state_file phase="interactive-pause" round="1" max_rounds="3" interactive="true"
  setup_hook_input "Summary <anvil-steering>none</anvil-steering>"
  run_stop_hook
  assert_block_decision
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason')
  ! printf '%s' "$reason" | grep -qF "User Steering Directive"
}

@test "steering 'synthesize' skips to synthesizer" {
  create_state_file phase="interactive-pause" round="1" max_rounds="3" interactive="true"
  setup_hook_input "Summary <anvil-steering>synthesize</anvil-steering>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "no interactive pause at last round" {
  create_state_file phase="critic" round="3" max_rounds="3" interactive="true"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critic argument"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "interactive-pause does not append to debate transcript" {
  create_state_file phase="interactive-pause" round="1" max_rounds="3" interactive="true"
  add_round_to_state 1 "adv text" "critic text"
  setup_hook_input "This is meta-conversation <anvil-steering>none</anvil-steering>"
  run_stop_hook
  # The interactive-pause output should NOT appear in the state body
  local body
  body=$(awk '/^---$/{i++; next} i>=2' "$(state_file)")
  ! printf '%s' "$body" | grep -qF "meta-conversation"
}

@test "non-interactive mode never pauses" {
  create_state_file phase="critic" round="1" max_rounds="3" interactive="false"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic argument"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"
}
