#!/usr/bin/env bats
# Tests for persona argument handling (preset vs free-text, 2-way vs 3+-way)

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/assertions"

run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- 2 personas ---

@test "2 preset personas: names stored correctly" {
  run_setup "question" --persona security-engineer --persona startup-cfo
  assert_frontmatter "personas" "security-engineer|startup-cfo"
}

@test "2 preset personas: descriptions loaded from files" {
  run_setup "question" --persona security-engineer --persona startup-cfo
  # Preset file content should be in the body
  assert_state_body_contains "<!-- persona:security-engineer -->"
  assert_state_body_contains "<!-- persona:startup-cfo -->"
}

@test "2 free-text personas: names stored as descriptions" {
  run_setup "question" --persona "A grumpy architect" --persona "An eager intern"
  assert_frontmatter "personas" "A grumpy architect|An eager intern"
}

@test "2 free-text personas: descriptions in body" {
  run_setup "question" --persona "A grumpy architect" --persona "An eager intern"
  assert_state_body_contains "A grumpy architect"
  assert_state_body_contains "An eager intern"
}

@test "mixed preset and free-text persona" {
  run_setup "question" --persona security-engineer --persona "A product manager"
  assert_state_body_contains "<!-- persona:security-engineer -->"
  assert_state_body_contains "<!-- persona:A product manager -->"
}

# --- 3+ personas ---

@test "3 personas: rotation mode (phase=persona)" {
  run_setup "question" --persona "A" --persona "B" --persona "C"
  assert_frontmatter "phase" "persona"
  assert_frontmatter "max_rounds" "3"
}

@test "4 personas: all stored" {
  run_setup "question" --persona "A" --persona "B" --persona "C" --persona "D"
  assert_frontmatter "personas" "A|B|C|D"
  assert_frontmatter "max_rounds" "4"
}

# --- Interactive compatibility ---

@test "2 personas with --interactive works" {
  run_setup "question" --persona "A" --persona "B" --interactive
  assert_success
  assert_frontmatter "interactive" "true"
}

@test "3+ personas with --interactive fails" {
  run_setup "question" --persona "A" --persona "B" --persona "C" --interactive
  assert_failure
}
