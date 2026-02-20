#!/usr/bin/env bats
# Tests for persona-specific prompt construction in stop-hook

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# --- 2-Persona Mode ---

@test "2 personas: advocate phase uses first persona name" {
  create_state_file phase="advocate" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "You think about security first"
  add_persona_to_state "startup-cfo" "You think about costs first"
  setup_hook_input "Security argument"
  run_stop_hook
  assert_block_decision
  # Next phase is critic, which should use second persona
  assert_reason_contains "startup-cfo"
  assert_reason_contains "AGAINST"
}

@test "2 personas: critic phase uses second persona description" {
  create_state_file phase="advocate" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "You think about security first"
  add_persona_to_state "startup-cfo" "You think about costs first"
  setup_hook_input "Security argument"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "You think about costs first"
}

@test "2 personas: advocate round 2 uses first persona again" {
  create_state_file phase="critic" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "You think about security first"
  add_persona_to_state "startup-cfo" "You think about costs first"
  add_round_to_state 1 "advocate text"
  setup_hook_input "CFO critique"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "security-engineer"
  assert_reason_contains "FOR"
}

@test "2 personas: synthesizer gets persona debate mode prompt" {
  create_state_file phase="critic" round="3" max_rounds="3" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "Sec"
  add_persona_to_state "startup-cfo" "CFO"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critique"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "persona debate"
}

@test "2 personas: system message shows persona names" {
  create_state_file phase="advocate" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "Sec"
  add_persona_to_state "startup-cfo" "CFO"
  setup_hook_input "Security argument"
  run_stop_hook
  assert_block_decision
  assert_system_message_contains "startup-cfo"
  assert_system_message_contains "CRITIC"
}

# --- 3+ Persona Rotation ---

@test "3 personas: round 2 uses second persona" {
  create_state_file phase="persona" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Security focus"
  add_persona_to_state "startup-cfo" "Cost focus"
  add_persona_to_state "junior-developer" "Simplicity focus"
  setup_hook_input "Security perspective"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "startup-cfo"
  assert_reason_contains "Cost focus"
}

@test "3 personas: round 3 uses third persona" {
  create_state_file phase="persona" round="2" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Security focus"
  add_persona_to_state "startup-cfo" "Cost focus"
  add_persona_to_state "junior-developer" "Simplicity focus"
  setup_hook_input "CFO perspective"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "junior-developer"
  assert_reason_contains "Simplicity focus"
}

@test "3 personas: system message shows current persona" {
  create_state_file phase="persona" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Security focus"
  add_persona_to_state "startup-cfo" "Cost focus"
  add_persona_to_state "junior-developer" "Simplicity focus"
  setup_hook_input "Security perspective"
  run_stop_hook
  assert_system_message_contains "startup-cfo"
  assert_system_message_contains "PERSONA"
}

@test "3 personas: synthesizer prompt has persona debate context" {
  create_state_file phase="persona" round="3" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Security"
  add_persona_to_state "startup-cfo" "Cost"
  add_persona_to_state "junior-developer" "Simple"
  setup_hook_input "Junior perspective"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "persona debate"
}

@test "3 personas: transcript labels by persona name" {
  create_state_file phase="persona" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Sec"
  add_persona_to_state "startup-cfo" "CFO"
  add_persona_to_state "junior-developer" "Dev"
  setup_hook_input "Security perspective output"
  run_stop_hook
  assert_state_body_contains "## Persona 1: security-engineer"
}

@test "2 personas: transcript labels advocate/critic with round heading" {
  create_state_file phase="advocate" round="1" max_rounds="2" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "Sec"
  add_persona_to_state "startup-cfo" "CFO"
  setup_hook_input "Advocate argument from security persona"
  run_stop_hook
  assert_state_body_contains "## Round 1"
  assert_state_body_contains "### Advocate"
}

@test "persona description fallback when markers missing" {
  create_state_file phase="persona" round="1" max_rounds="2" \
    personas="unknown-persona|other-persona"
  # Don't add persona markers — test fallback
  setup_hook_input "Unknown persona output"
  run_stop_hook
  assert_block_decision
  # Should use persona name as fallback description
  assert_reason_contains "other-persona"
}
