#!/usr/bin/env bats
# Tests for ALL state machine transitions in the stop hook

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# --- Standard Advocate/Critic Cycle ---

@test "advocate → critic (same round)" {
  create_state_file phase="advocate" round="1" max_rounds="3"
  setup_hook_input "Advocate argument round 1"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
  assert_frontmatter "round" "1"
}

@test "critic → advocate (next round, round < max)" {
  create_state_file phase="critic" round="1" max_rounds="3"
  add_round_to_state 1 "advocate text"
  setup_hook_input "Critic argument round 1"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"
}

@test "critic → synthesizer (round == max_rounds)" {
  create_state_file phase="critic" round="3" max_rounds="3"
  add_round_to_state 1 "adv1" "crit1"
  add_round_to_state 2 "adv2" "crit2"
  add_round_to_state 3 "adv3"
  setup_hook_input "Critic argument round 3"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "advocate round 2 → critic round 2" {
  create_state_file phase="advocate" round="2" max_rounds="3"
  add_round_to_state 1 "adv1" "crit1"
  setup_hook_input "Advocate argument round 2"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
  assert_frontmatter "round" "2"
}

@test "single round debate: critic round 1 → synthesizer (max_rounds=1)" {
  create_state_file phase="critic" round="1" max_rounds="1"
  setup_hook_input "Critic argument"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

# --- Stakeholder Mode ---

@test "stakeholder round 1 → stakeholder round 2 (when more stakeholders)" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Engineering perspective"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "stakeholder"
  assert_frontmatter "round" "2"
}

@test "stakeholder last round → synthesizer" {
  create_state_file phase="stakeholder" mode="stakeholders" round="3" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Business perspective"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

# --- Persona Rotation (3+) ---

@test "persona round 1 → persona round 2 (when more personas)" {
  create_state_file phase="persona" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Security focused"
  add_persona_to_state "startup-cfo" "Cost focused"
  add_persona_to_state "junior-developer" "Simplicity focused"
  setup_hook_input "Security perspective"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "persona"
  assert_frontmatter "round" "2"
}

@test "persona last round → synthesizer" {
  create_state_file phase="persona" round="3" max_rounds="3" \
    personas="security-engineer|startup-cfo|junior-developer"
  add_persona_to_state "security-engineer" "Security focused"
  add_persona_to_state "startup-cfo" "Cost focused"
  add_persona_to_state "junior-developer" "Simplicity focused"
  setup_hook_input "Junior dev perspective"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

# --- 2-Persona Mode (Advocate/Critic) ---

@test "2 personas: advocate → critic (persona[1] becomes critic)" {
  create_state_file phase="advocate" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "Security perspective"
  add_persona_to_state "startup-cfo" "Cost perspective"
  setup_hook_input "Security argument"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
  assert_reason_contains "startup-cfo"
}

@test "2 personas: critic → advocate next round" {
  create_state_file phase="critic" round="1" max_rounds="3" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "Security perspective"
  add_persona_to_state "startup-cfo" "Cost perspective"
  add_round_to_state 1 "security arg"
  setup_hook_input "CFO critique"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"
}

# --- Interactive Mode ---

@test "interactive: critic → interactive-pause (round < max)" {
  create_state_file phase="critic" round="1" max_rounds="3" interactive="true"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic argument"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "interactive-pause"
}

@test "interactive: critic → synthesizer at max rounds (no pause)" {
  create_state_file phase="critic" round="3" max_rounds="3" interactive="true"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Critic argument round 3"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "interactive-pause → advocate next round (continue)" {
  create_state_file phase="interactive-pause" round="1" max_rounds="3" interactive="true"
  setup_hook_input "Summary and steering <anvil-steering>none</anvil-steering>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"
}

@test "interactive-pause → synthesizer (skip)" {
  create_state_file phase="interactive-pause" round="1" max_rounds="3" interactive="true"
  setup_hook_input "Summary <anvil-steering>synthesize</anvil-steering>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}

@test "interactive-pause → synthesizer (skip keyword)" {
  create_state_file phase="interactive-pause" round="1" max_rounds="3" interactive="true"
  setup_hook_input "Summary <anvil-steering>skip</anvil-steering>"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesizer"
}
