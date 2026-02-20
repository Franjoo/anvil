#!/usr/bin/env bats
# Tests for prompt assembly for each phase/mode combination

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# --- Phase-specific role prompts ---

@test "advocate phase includes advocate role prompt" {
  create_state_file phase="critic" round="1" max_rounds="3"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic output"
  run_stop_hook
  assert_block_decision
  # Next phase is advocate (round 2), should include advocate prompt
  assert_reason_contains "Advocate"
  assert_reason_contains "strongest possible case FOR"
}

@test "critic phase includes critic role prompt" {
  create_state_file phase="advocate" round="1" max_rounds="3"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "Critic"
  assert_reason_contains "dismantle"
}

@test "synthesizer phase includes synthesizer role prompt" {
  create_state_file phase="critic" round="3" max_rounds="3"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critique"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "Synthesizer"
  assert_reason_contains "balanced"
}

# --- Mode prompts ---

@test "analyst mode prompt included" {
  create_state_file phase="advocate" round="1" max_rounds="3" mode="analyst"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "analyst mode"
}

@test "philosopher mode prompt included" {
  create_state_file phase="advocate" round="1" max_rounds="3" mode="philosopher"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "philosopher"
}

@test "devils-advocate mode prompt included" {
  create_state_file phase="advocate" round="1" max_rounds="3" mode="devils-advocate" \
    position="\"I think X\""
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "devil"
}

# --- Question and position in prompt ---

@test "question included in prompt" {
  create_state_file phase="advocate" round="1" max_rounds="3" \
    question="\"Should we use microservices?\""
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Should we use microservices?"
}

@test "position included in prompt when set" {
  create_state_file phase="advocate" round="1" max_rounds="3" \
    position="\"I believe microservices are bad\""
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "I believe microservices are bad"
}

@test "null position not shown in prompt" {
  create_state_file phase="advocate" round="1" max_rounds="3" position="null"
  setup_hook_input "Advocate output"
  run_stop_hook
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason')
  ! printf '%s' "$reason" | grep -qF "stated position"
}

# --- Transcript in prompt ---

@test "debate transcript included in prompt" {
  create_state_file phase="advocate" round="2" max_rounds="3"
  add_round_to_state 1 "First advocate argument" "First critic rebuttal"
  setup_hook_input "Critic output round 1"
  run_stop_hook
  assert_reason_contains "First advocate argument"
}

# --- Framework prompts ---

@test "framework prompt included for synthesizer" {
  create_state_file phase="critic" round="3" max_rounds="3" framework="adr"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critique"
  run_stop_hook
  assert_reason_contains "ADR"
}

@test "framework prompt NOT included for non-synthesizer phases" {
  create_state_file phase="advocate" round="1" max_rounds="3" framework="adr"
  setup_hook_input "Advocate output"
  run_stop_hook
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason')
  # ADR template should NOT appear in advocate prompts
  ! printf '%s' "$reason" | grep -qF "Architecture Decision Record"
}

# --- Focus lens ---

@test "focus lens included in advocate prompt" {
  create_state_file phase="advocate" round="1" max_rounds="3" focus="security"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Focus Lens: security"
  assert_reason_contains "CONSTRAIN"
}

@test "focus lens included in critic prompt" {
  create_state_file phase="advocate" round="1" max_rounds="3" focus="performance"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Focus Lens: performance"
}

@test "focus lens NOT included in synthesizer prompt" {
  create_state_file phase="critic" round="3" max_rounds="3" focus="security"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critique"
  run_stop_hook
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason')
  ! printf '%s' "$reason" | grep -qF "Focus Lens"
}

@test "custom focus description used for unknown focus" {
  create_state_file phase="advocate" round="1" max_rounds="3" focus="team morale"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "team morale"
}

# --- Versus mode ---

@test "versus advocate gets Position A framing" {
  create_state_file phase="critic" round="1" max_rounds="3" versus="true"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic output"
  run_stop_hook
  assert_reason_contains "Position A"
}

@test "versus critic gets Position B framing" {
  create_state_file phase="advocate" round="1" max_rounds="3" versus="true"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Position B"
}

# --- Research mode ---

@test "research enabled: advocate gets research instructions" {
  create_state_file phase="critic" round="1" max_rounds="3" research="true"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic output"
  run_stop_hook
  assert_reason_contains "Research Mode ENABLED"
  assert_reason_contains "WebSearch"
}

@test "research enabled: synthesizer gets verification instructions" {
  create_state_file phase="critic" round="3" max_rounds="3" research="true"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critique"
  run_stop_hook
  assert_reason_contains "Research Mode ENABLED"
  assert_reason_contains "VERIFY"
}

# --- System message ---

@test "system message shows phase and round" {
  create_state_file phase="advocate" round="1" max_rounds="3"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_system_message_contains "CRITIC"
  assert_system_message_contains "Round 1"
}

@test "system message for synthesizer" {
  create_state_file phase="critic" round="3" max_rounds="3"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critique"
  run_stop_hook
  assert_system_message_contains "SYNTHESIZER"
}

# --- Research mode per-phase (CRITICAL coverage) ---

@test "research enabled: critic gets counter-evidence instructions" {
  create_state_file phase="advocate" round="1" max_rounds="3" research="true" mode="analyst"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Research Mode ENABLED"
  assert_reason_contains "counter-evidence"
}

@test "research enabled: stakeholder gets domain-specific instructions" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="2" \
    research="true" stakeholders="Engineering,Product"
  setup_hook_input "Engineering perspective"
  run_stop_hook
  assert_reason_contains "Research Mode ENABLED"
  assert_reason_contains "stakeholder"
}

@test "research enabled: persona gets persona-specific instructions" {
  create_state_file phase="persona" round="1" max_rounds="2" research="true" \
    personas="security-engineer|startup-cfo"
  add_persona_to_state "security-engineer" "Security"
  add_persona_to_state "startup-cfo" "Cost"
  setup_hook_input "Security output"
  run_stop_hook
  assert_reason_contains "Research Mode ENABLED"
  assert_reason_contains "persona"
}

@test "research disabled: no research block in prompt" {
  create_state_file phase="advocate" round="1" max_rounds="3" research="false"
  setup_hook_input "Advocate output"
  run_stop_hook
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason')
  ! printf '%s' "$reason" | grep -qF "Research Mode ENABLED"
}

# --- Research mode per-mode in stop-hook ---

@test "research: analyst mode advocate mentions benchmarks/data" {
  create_state_file phase="critic" round="1" max_rounds="3" research="true" mode="analyst"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic output"
  run_stop_hook
  assert_reason_contains "data"
}

@test "research: philosopher mode advocate mentions philosophical" {
  create_state_file phase="critic" round="1" max_rounds="3" research="true" mode="philosopher"
  add_round_to_state 1 "adv"
  setup_hook_input "Critic output"
  run_stop_hook
  assert_reason_contains "philosophical"
}

@test "research: devils-advocate mode advocate mentions UNDERMINES" {
  create_state_file phase="critic" round="1" max_rounds="3" research="true" mode="devils-advocate" \
    position="\"I think X\""
  add_round_to_state 1 "adv"
  setup_hook_input "Critic output"
  run_stop_hook
  assert_reason_contains "UNDERMINES"
}

@test "research: stakeholders mode synthesizer mentions stakeholder verification" {
  create_state_file phase="stakeholder" mode="stakeholders" round="2" max_rounds="2" \
    research="true" stakeholders="Eng,Product"
  setup_hook_input "Product perspective"
  run_stop_hook
  assert_reason_contains "VERIFY"
}

# --- Focus lenses in stop-hook (all 5) ---

@test "focus developer-experience has evaluation criteria" {
  create_state_file phase="advocate" round="1" max_rounds="3" focus="developer-experience"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Learning curve"
}

@test "focus operational-cost has evaluation criteria" {
  create_state_file phase="advocate" round="1" max_rounds="3" focus="operational-cost"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Infrastructure costs"
}

@test "focus maintainability has evaluation criteria" {
  create_state_file phase="advocate" round="1" max_rounds="3" focus="maintainability"
  setup_hook_input "Advocate output"
  run_stop_hook
  assert_reason_contains "Code complexity"
}

# --- Versus mode exclusion ---

@test "versus framing NOT included in synthesizer prompt" {
  create_state_file phase="critic" round="3" max_rounds="3" versus="true"
  add_round_to_state 1 "a1" "c1"
  add_round_to_state 2 "a2" "c2"
  add_round_to_state 3 "a3"
  setup_hook_input "Final critique"
  run_stop_hook
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason')
  ! printf '%s' "$reason" | grep -qF "VERSUS MODE"
}

# --- Framework prompts for all frameworks ---

@test "pre-mortem framework prompt in synthesizer" {
  create_state_file phase="critic" round="1" max_rounds="1" framework="pre-mortem"
  setup_hook_input "Critique"
  run_stop_hook
  assert_reason_contains "pre-mortem"
}

@test "rfc framework prompt in synthesizer" {
  create_state_file phase="critic" round="1" max_rounds="1" framework="rfc"
  setup_hook_input "Critique"
  run_stop_hook
  assert_reason_contains "RFC"
}

@test "risks framework prompt in synthesizer" {
  create_state_file phase="critic" round="1" max_rounds="1" framework="risks"
  setup_hook_input "Critique"
  run_stop_hook
  assert_reason_contains "risk"
}

@test "red-team framework prompt in synthesizer" {
  create_state_file phase="critic" round="1" max_rounds="1" framework="red-team"
  setup_hook_input "Critique"
  run_stop_hook
  assert_reason_contains "red"
}
