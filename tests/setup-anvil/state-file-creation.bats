#!/usr/bin/env bats
# Tests for state file creation correctness

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/assertions"

# Helper: run setup script in TEST_DIR
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- State file basics ---

@test "creates state file in .claude directory" {
  run_setup "question"
  assert_success
  assert_state_exists
}

@test "creates .claude directory if it doesn't exist" {
  rm -rf "${TEST_DIR}/.claude"
  run_setup "question"
  assert_success
  assert_state_exists
}

@test "state file has YAML frontmatter delimiters" {
  run_setup "question"
  local sf
  sf=$(state_file)
  local first_line
  first_line=$(head -1 "$sf")
  [ "$first_line" = "---" ]
}

@test "state file has active: true" {
  run_setup "question"
  assert_frontmatter "active" "true"
}

@test "state file has started_at timestamp" {
  run_setup "question"
  local started
  started=$(get_frontmatter "started_at" "$(state_file)")
  [ -n "$started" ]
  [[ "$started" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

# --- Stakeholders mode state ---

@test "stakeholders mode: initial phase is stakeholder" {
  run_setup "question" --mode stakeholders
  assert_frontmatter "phase" "stakeholder"
}

@test "stakeholders mode: max_rounds equals stakeholder count" {
  run_setup "question" --mode stakeholders --stakeholders "Eng,Product,Biz"
  assert_frontmatter "max_rounds" "3"
}

@test "stakeholders mode: default stakeholders when none specified" {
  run_setup "question" --mode stakeholders
  local stakeholders
  stakeholders=$(get_frontmatter "stakeholders" "$(state_file)")
  [ -n "$stakeholders" ]
}

@test "stakeholders mode: custom stakeholders stored" {
  run_setup "question" --mode stakeholders --stakeholders "Security,DevOps"
  assert_frontmatter "stakeholders" "Security,DevOps"
}

@test "auto-detect stakeholders mode when --stakeholders provided" {
  run_setup "question" --stakeholders "Eng,Product"
  assert_frontmatter "mode" "stakeholders"
  assert_frontmatter "phase" "stakeholder"
}

# --- Persona state ---

@test "2 personas: initial phase is advocate" {
  run_setup "question" --persona security-engineer --persona startup-cfo
  assert_frontmatter "phase" "advocate"
}

@test "3+ personas: initial phase is persona" {
  run_setup "question" --persona "A" --persona "B" --persona "C"
  assert_frontmatter "phase" "persona"
}

@test "3+ personas: max_rounds equals persona count" {
  run_setup "question" --persona "A" --persona "B" --persona "C"
  assert_frontmatter "max_rounds" "3"
}

@test "personas stored as pipe-separated names" {
  run_setup "question" --persona security-engineer --persona startup-cfo
  assert_frontmatter "personas" "security-engineer|startup-cfo"
}

@test "preset persona descriptions stored in state body" {
  run_setup "question" --persona security-engineer --persona startup-cfo
  assert_state_body_contains "<!-- persona:security-engineer -->"
  assert_state_body_contains "<!-- /persona -->"
}

@test "free-text persona stored as-is" {
  run_setup "question" --persona "A grumpy senior dev" --persona "An optimistic PM"
  assert_state_body_contains "<!-- persona:A grumpy senior dev -->"
  assert_state_body_contains "A grumpy senior dev"
}

# --- Versus state ---

@test "versus mode stores versus: true" {
  echo "Position A" > "${TEST_DIR}/a.md"
  echo "Position B" > "${TEST_DIR}/b.md"
  run_setup "question" --versus "${TEST_DIR}/a.md" "${TEST_DIR}/b.md"
  assert_frontmatter "versus" "true"
}

@test "versus mode auto-generates question if none provided" {
  echo "Position A" > "${TEST_DIR}/a.md"
  echo "Position B" > "${TEST_DIR}/b.md"
  run_setup --versus "${TEST_DIR}/a.md" "${TEST_DIR}/b.md"
  assert_success
  assert_frontmatter "question" "Which analysis is stronger and why?"
}

# --- Follow-up state ---

@test "follow-up content appended to state file" {
  echo "Previous analysis conclusion" > "${TEST_DIR}/prior.md"
  run_setup "question" --follow-up "${TEST_DIR}/prior.md"
  assert_state_body_contains "Prior Analysis"
  assert_state_body_contains "Previous analysis conclusion"
}

@test "follow-up path stored in frontmatter" {
  echo "Previous analysis" > "${TEST_DIR}/prior.md"
  run_setup "question" --follow-up "${TEST_DIR}/prior.md"
  assert_frontmatter "follow_up" "${TEST_DIR}/prior.md"
}

# --- Output path state ---

@test "--output path stored in state frontmatter" {
  run_setup "question" --output /tmp/my-report.html
  assert_frontmatter "output" "/tmp/my-report.html"
}
