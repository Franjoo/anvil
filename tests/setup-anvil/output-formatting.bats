#!/usr/bin/env bats
# Tests for banner + prompt stdout output formatting

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/assertions"

run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- Banner ---

@test "output contains ANVIL banner" {
  run_setup "question"
  assert_output --partial "ANVIL"
  assert_output --partial "Adversarial Thinking"
}

@test "output shows question in banner" {
  run_setup "Should we use Rust?"
  assert_output --partial "Question:  Should we use Rust?"
}

@test "output shows mode in banner" {
  run_setup "question" --mode philosopher
  assert_output --partial "Mode:      philosopher"
}

@test "output shows rounds in banner" {
  run_setup "question" --rounds 5
  assert_output --partial "Rounds:    5"
}

@test "output shows position when set" {
  run_setup "question" --mode devils-advocate --position "I think X"
  assert_output --partial "Position:  I think X"
}

@test "output shows framework when set" {
  run_setup "question" --framework adr
  assert_output --partial "Framework: adr"
}

@test "output shows focus when set" {
  run_setup "question" --focus security
  assert_output --partial "Focus:     security"
}

@test "output shows interactive when enabled" {
  run_setup "question" --interactive
  assert_output --partial "Interactive: ENABLED"
}

@test "output shows research when enabled" {
  run_setup "question" --research
  assert_output --partial "Research:  ENABLED"
}

@test "output shows output path when set" {
  run_setup "question" --output /tmp/report.html
  assert_output --partial "Output:    /tmp/report.html"
}

@test "output path always shown in banner" {
  run_setup "question"
  assert_output --partial "Output:"
  assert_output --partial "Desktop/anvil-"
}

# --- Phase indication ---

@test "default phase shows ADVOCATE" {
  run_setup "question"
  assert_output --partial "Phase:     ADVOCATE"
}

@test "stakeholder phase shown correctly" {
  run_setup "question" --mode stakeholders --stakeholders "Eng,Product"
  assert_output --partial "STAKEHOLDER 1"
  assert_output --partial "Eng"
}

@test "persona phase shown for 3+ personas" {
  run_setup "question" --persona "A" --persona "B" --persona "C"
  assert_output --partial "PERSONA 1"
}

@test "2 persona phase shown with persona names" {
  run_setup "question" --persona security-engineer --persona startup-cfo
  assert_output --partial "ADVOCATE"
  assert_output --partial "security-engineer"
}

# --- Cycle description ---

@test "default cycle: Advocate → Critic → Synthesizer" {
  run_setup "question"
  assert_output --partial "Advocate"
  assert_output --partial "Critic"
  assert_output --partial "Synthesizer"
}

@test "stakeholder cycle shows stakeholder rotation" {
  run_setup "question" --mode stakeholders
  assert_output --partial "Stakeholder 1"
  assert_output --partial "Stakeholder 2"
}

@test "persona cycle shows persona rotation" {
  run_setup "question" --persona "A" --persona "B" --persona "C"
  assert_output --partial "Persona 1"
  assert_output --partial "Persona 2"
}

# --- Role prompt content ---

@test "output includes mode prompt" {
  run_setup "question" --mode analyst
  assert_output --partial "analyst mode"
}

@test "output includes advocate role prompt" {
  run_setup "question"
  assert_output --partial "Advocate"
  assert_output --partial "strongest possible case"
}

@test "output includes question under debate" {
  run_setup "Should we migrate?"
  assert_output --partial "Question under debate"
  assert_output --partial "Should we migrate?"
}

# --- Focus lens output ---

@test "security focus includes evaluation criteria" {
  run_setup "question" --focus security
  assert_output --partial "Attack surface"
}

@test "performance focus includes evaluation criteria" {
  run_setup "question" --focus performance
  assert_output --partial "Latency"
}

@test "developer-experience focus includes evaluation criteria" {
  run_setup "question" --focus developer-experience
  assert_output --partial "Learning curve"
}

@test "operational-cost focus includes evaluation criteria" {
  run_setup "question" --focus operational-cost
  assert_output --partial "Infrastructure costs"
}

@test "maintainability focus includes evaluation criteria" {
  run_setup "question" --focus maintainability
  assert_output --partial "Code complexity"
}

@test "custom focus shows custom text" {
  run_setup "question" --focus "team happiness"
  assert_output --partial "team happiness"
}

# --- Research output ---

@test "research mode includes research instructions" {
  run_setup "question" --research
  assert_output --partial "Research Mode ENABLED"
  assert_output --partial "WebSearch"
}

@test "research instructions mode-specific for analyst" {
  run_setup "question" --research --mode analyst
  assert_output --partial "benchmarks"
}

@test "research instructions mode-specific for philosopher" {
  run_setup "question" --research --mode philosopher
  assert_output --partial "philosophical"
}

@test "research instructions mode-specific for devils-advocate" {
  run_setup "question" --research --mode devils-advocate --position "I believe X"
  assert_output --partial "UNDERMINES"
}

@test "research instructions mode-specific for stakeholders" {
  run_setup "question" --research --mode stakeholders
  assert_output --partial "stakeholder"
}

# --- Round indication ---

@test "output shows Round 1 start" {
  run_setup "question"
  assert_output --partial "This is Round 1"
}
