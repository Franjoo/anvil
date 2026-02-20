#!/usr/bin/env bats
# End-to-end integration tests: setup → hook → ... → result

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# Helper: run setup
run_setup() {
  bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@" >/dev/null 2>&1
}

# Helper: run hook with given assistant message
run_hook_step() {
  local msg="$1"
  setup_hook_input "$msg"
  local result
  result=$(bash -c 'cd "$1" && printf "%s" "$2" | "$3" 2>/dev/null' _ "$TEST_DIR" "$HOOK_INPUT" "$STOP_HOOK")
  echo "$result"
}

@test "full 1-round debate: setup → advocate → critic → synthesizer → result" {
  # Setup
  run_setup "Should we use Rust?" --rounds 1

  # Verify initial state
  assert_state_exists
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "1"

  # Advocate phase (round 1)
  run_hook_step "Advocate: Rust is great for safety."
  assert_frontmatter "phase" "critic"
  assert_frontmatter "round" "1"

  # Critic phase (round 1)
  run_hook_step "Critic: But learning curve is steep."
  assert_frontmatter "phase" "synthesizer"

  # Synthesizer phase
  run_hook_step "Synthesis: Rust is good but needs investment."
  assert_state_cleaned
  assert_result_exists
  assert_result_contains "Should we use Rust?"
  assert_result_contains "Synthesis: Rust is good but needs investment."
}

@test "full 2-round debate: advocate/critic cycle repeats" {
  run_setup "Monolith vs microservices?" --rounds 2

  # Round 1: advocate → critic
  run_hook_step "Advocate R1: Microservices scale."
  assert_frontmatter "phase" "critic"
  assert_frontmatter "round" "1"

  run_hook_step "Critic R1: But complexity."
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"

  # Round 2: advocate → critic → synthesizer
  run_hook_step "Advocate R2: Domain boundaries help."
  assert_frontmatter "phase" "critic"
  assert_frontmatter "round" "2"

  run_hook_step "Critic R2: Still too much overhead."
  assert_frontmatter "phase" "synthesizer"

  run_hook_step "Final synthesis."
  assert_state_cleaned
  assert_result_exists
}

@test "full stakeholder simulation: 3 stakeholders → synthesizer" {
  run_setup "Should we adopt Kubernetes?" --mode stakeholders --stakeholders "Eng,Product,Ops"

  assert_frontmatter "phase" "stakeholder"
  assert_frontmatter "max_rounds" "3"

  # Stakeholder 1: Engineering
  run_hook_step "Engineering: Great for scaling."
  assert_frontmatter "phase" "stakeholder"
  assert_frontmatter "round" "2"

  # Stakeholder 2: Product
  run_hook_step "Product: Slows feature delivery."
  assert_frontmatter "phase" "stakeholder"
  assert_frontmatter "round" "3"

  # Stakeholder 3: Ops
  run_hook_step "Ops: Love it, more control."
  assert_frontmatter "phase" "synthesizer"

  # Synthesizer
  run_hook_step "Synthesis: adopt with guardrails."
  assert_state_cleaned
  assert_result_exists
}

@test "full 3-persona rotation: persona1 → persona2 → persona3 → synthesizer" {
  run_setup "GraphQL vs REST?" --persona "frontend dev" --persona "backend dev" --persona "devops"

  assert_frontmatter "phase" "persona"
  assert_frontmatter "max_rounds" "3"

  # Persona 1
  run_hook_step "Frontend: GraphQL gives us flexibility."
  assert_frontmatter "phase" "persona"
  assert_frontmatter "round" "2"

  # Persona 2
  run_hook_step "Backend: REST is simpler to maintain."
  assert_frontmatter "phase" "persona"
  assert_frontmatter "round" "3"

  # Persona 3
  run_hook_step "DevOps: REST is easier to cache."
  assert_frontmatter "phase" "synthesizer"

  # Synthesizer
  run_hook_step "Use REST with specific GraphQL endpoints."
  assert_state_cleaned
  assert_result_exists
}

@test "early completion: anvil-complete in round 1 skips to synthesis" {
  run_setup "Test question" --rounds 3

  # Advocate tries to end early
  run_hook_step "This is clear enough <anvil-complete/>"
  assert_frontmatter "phase" "synthesizer"

  run_hook_step "Quick synthesis."
  assert_state_cleaned
  assert_result_exists
}

@test "2-persona debate: security vs cfo" {
  run_setup "Should we invest in SOC2?" --persona security-engineer --persona startup-cfo

  assert_frontmatter "phase" "advocate"
  assert_frontmatter "personas" "security-engineer|startup-cfo"

  # Round 1: security (advocate) → cfo (critic)
  run_hook_step "Security: SOC2 opens enterprise deals."
  assert_frontmatter "phase" "critic"

  run_hook_step "CFO: Too expensive for our stage."
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"
}

@test "debate with framework: result file exists" {
  run_setup "New API design" --rounds 1 --framework adr

  run_hook_step "Advocate: REST is the way."
  run_hook_step "Critic: GraphQL offers more."
  run_hook_step "Synthesis in ADR format."
  assert_state_cleaned
  assert_result_exists
  assert_result_contains "**Framework**: adr"
}

@test "full interactive mode cycle: pause → steer → synthesize" {
  run_setup "Should we use serverless?" --rounds 2 --interactive

  # Round 1: advocate → critic → interactive-pause
  run_hook_step "Advocate R1: Serverless reduces ops."
  assert_frontmatter "phase" "critic"

  run_hook_step "Critic R1: Cold starts are a problem."
  assert_frontmatter "phase" "interactive-pause"

  # User steers: continue with focus
  run_hook_step "Summary of round 1 <anvil-steering>Focus on cost</anvil-steering>"
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"

  # Round 2: advocate → critic → synthesizer (no pause at last round)
  run_hook_step "Advocate R2: Cost benefits are clear."
  assert_frontmatter "phase" "critic"

  run_hook_step "Critic R2: Hidden costs exist."
  assert_frontmatter "phase" "synthesizer"

  run_hook_step "Final analysis."
  assert_state_cleaned
  assert_result_exists
}
