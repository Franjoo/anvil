#!/usr/bin/env bats
# Combinatorial tests: verify multi-flag setups don't crash or produce invalid state

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# Helper: clear state between combo iterations within a single test
reset_test_dir() {
  rm -rf "${TEST_DIR}/.claude"
  mkdir -p "${TEST_DIR}/.claude"
}

# Helper: run setup and assert it succeeds with a valid state file
# Usage: assert_setup_valid "description" args...
assert_setup_valid() {
  local desc="$1"
  shift
  reset_test_dir
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
  if [[ "$status" -ne 0 ]]; then
    echo "FAILED: $desc" >&2
    echo "  args: $*" >&2
    echo "  exit: $status" >&2
    echo "  output: $output" >&2
    return 1
  fi
  local sf
  sf=$(state_file)
  if [[ ! -f "$sf" ]]; then
    echo "FAILED: $desc — no state file" >&2
    return 1
  fi
  local active
  active=$(get_frontmatter "active" "$sf")
  if [[ "$active" != "true" ]]; then
    echo "FAILED: $desc — active='$active'" >&2
    return 1
  fi
}

# Helper: run setup → one hook step, assert valid JSON block output
# Usage: assert_round_trip "description" args...
assert_round_trip() {
  local desc="$1"
  shift
  reset_test_dir
  # Setup
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
  if [[ "$status" -ne 0 ]]; then
    echo "FAILED (setup): $desc" >&2
    echo "  args: $*" >&2
    echo "  exit: $status, output: $output" >&2
    return 1
  fi
  # Hook step
  setup_hook_input "Test argument for round-trip."
  run_stop_hook
  if [[ "$status" -ne 0 ]]; then
    echo "FAILED (hook): $desc" >&2
    echo "  exit: $status, output: $output" >&2
    return 1
  fi
  local decision
  decision=$(printf '%s' "$output" | jq -r '.decision' 2>/dev/null)
  if [[ "$decision" != "block" ]]; then
    echo "FAILED (json): $desc — decision='$decision'" >&2
    echo "  output: $output" >&2
    return 1
  fi
}

# --- Mode × Framework ---

@test "every mode × every framework: setup produces valid state" {
  local modes=(analyst philosopher devils-advocate)
  local frameworks=(adr pre-mortem red-team rfc risks)

  for mode in "${modes[@]}"; do
    for fw in "${frameworks[@]}"; do
      local args=("Test question" --mode "$mode" --framework "$fw")
      if [[ "$mode" == "devils-advocate" ]]; then
        args+=(--position "I believe X")
      fi
      assert_setup_valid "$mode + $fw" "${args[@]}"
    done
  done
}

@test "stakeholders mode × every framework" {
  local frameworks=(adr pre-mortem red-team rfc risks)
  for fw in "${frameworks[@]}"; do
    assert_setup_valid "stakeholders + $fw" \
      "Test question" --mode stakeholders --stakeholders "Eng,Product" --framework "$fw"
  done
}

# --- Mode × Focus ---

@test "every mode × every focus preset: setup produces valid state" {
  local modes=(analyst philosopher devils-advocate)
  local focuses=(security performance developer-experience operational-cost maintainability)

  for mode in "${modes[@]}"; do
    for focus in "${focuses[@]}"; do
      local args=("Test question" --mode "$mode" --focus "$focus")
      if [[ "$mode" == "devils-advocate" ]]; then
        args+=(--position "I believe X")
      fi
      assert_setup_valid "$mode + $focus" "${args[@]}"
    done
  done
}

@test "stakeholders mode × every focus preset" {
  local focuses=(security performance developer-experience operational-cost maintainability)
  for focus in "${focuses[@]}"; do
    assert_setup_valid "stakeholders + $focus" \
      "Test question" --mode stakeholders --stakeholders "Eng,Product" --focus "$focus"
  done
}

# --- Mode + Framework + Focus Triples ---

@test "mode + framework + focus triples: setup produces valid state" {
  assert_setup_valid "analyst + adr + security" \
    "Test question" --mode analyst --framework adr --focus security
  assert_setup_valid "analyst + rfc + performance" \
    "Test question" --mode analyst --framework rfc --focus performance
  assert_setup_valid "philosopher + pre-mortem + maintainability" \
    "Test question" --mode philosopher --framework pre-mortem --focus maintainability
  assert_setup_valid "devils-advocate + red-team + security" \
    "Test question" --mode devils-advocate --framework red-team --focus security --position "I believe X"
  assert_setup_valid "stakeholders + risks + operational-cost" \
    "Test question" --mode stakeholders --stakeholders "Eng,Ops" --framework risks --focus operational-cost
}

# --- Research Flag Interactions ---

@test "research + various modes: setup produces valid state" {
  assert_setup_valid "analyst + research" \
    "Test question" --mode analyst --research
  assert_setup_valid "philosopher + research" \
    "Test question" --mode philosopher --research
  assert_setup_valid "devils-advocate + research" \
    "Test question" --mode devils-advocate --research --position "I believe X"
  assert_setup_valid "stakeholders + research" \
    "Test question" --mode stakeholders --stakeholders "Eng,Product" --research
}

@test "research + framework + focus: setup produces valid state" {
  assert_setup_valid "analyst + research + adr + security" \
    "Test question" --mode analyst --research --framework adr --focus security
  assert_setup_valid "philosopher + research + rfc + maintainability" \
    "Test question" --mode philosopher --research --framework rfc --focus maintainability
}

# --- Interactive + Compatible Configs ---

@test "interactive + various modes: setup produces valid state" {
  assert_setup_valid "analyst + interactive" \
    "Test question" --mode analyst --interactive
  assert_setup_valid "philosopher + interactive" \
    "Test question" --mode philosopher --interactive
  assert_setup_valid "devils-advocate + interactive" \
    "Test question" --mode devils-advocate --interactive --position "I believe X"
  assert_setup_valid "analyst + interactive + research + framework" \
    "Test question" --mode analyst --interactive --research --framework adr
}

@test "interactive + 2 personas: setup produces valid state" {
  assert_setup_valid "2 personas + interactive" \
    "Test question" --persona security-engineer --persona startup-cfo --interactive
}

# --- Context Flag Stacking ---

@test "context combos: file context" {
  local ctx_file="${TEST_DIR}/context.txt"
  echo "sample context" > "$ctx_file"
  assert_setup_valid "file context" \
    "Test question" --context "$ctx_file"
}

@test "context combos: directory context" {
  local ctx_dir="${TEST_DIR}/src"
  mkdir -p "$ctx_dir"
  echo "func main() {}" > "$ctx_dir/main.go"
  assert_setup_valid "dir context" \
    "Test question" --context "$ctx_dir"
}

@test "context combos: diff context" {
  assert_setup_valid "diff context" \
    "Test question" --diff
}

@test "context combos: file + diff" {
  local ctx_file="${TEST_DIR}/context.txt"
  echo "sample context" > "$ctx_file"
  assert_setup_valid "file + diff" \
    "Test question" --context "$ctx_file" --diff
}

@test "context combos: multiple files + diff + mode + framework" {
  local f1="${TEST_DIR}/a.txt"
  local f2="${TEST_DIR}/b.txt"
  echo "aaa" > "$f1"
  echo "bbb" > "$f2"
  assert_setup_valid "multi-context + mode + framework" \
    "Test question" --context "$f1" --context "$f2" --diff --mode analyst --framework adr
}

@test "follow-up context: follow-up + mode + framework" {
  local prior="${TEST_DIR}/prior-result.md"
  echo "# Prior Analysis" > "$prior"
  assert_setup_valid "follow-up + analyst + adr" \
    "Test question" --follow-up "$prior" --mode analyst --framework adr
}

# --- Persona + Flag Combos ---

@test "2 personas + framework combos: setup produces valid state" {
  local frameworks=(adr pre-mortem red-team rfc risks)
  for fw in "${frameworks[@]}"; do
    assert_setup_valid "2 personas + $fw" \
      "Test question" --persona security-engineer --persona startup-cfo --framework "$fw"
  done
}

@test "2 personas + focus combos: setup produces valid state" {
  local focuses=(security performance developer-experience)
  for focus in "${focuses[@]}"; do
    assert_setup_valid "2 personas + $focus" \
      "Test question" --persona security-engineer --persona startup-cfo --focus "$focus"
  done
}

@test "2 personas + research + framework: setup produces valid state" {
  assert_setup_valid "2 personas + research + adr" \
    "Test question" --persona security-engineer --persona startup-cfo --research --framework adr
}

@test "3 personas + framework: setup produces valid state" {
  assert_setup_valid "3 personas + rfc" \
    "Test question" --persona security-engineer --persona startup-cfo --persona junior-developer --framework rfc
}

@test "3 personas + focus + research: setup produces valid state" {
  assert_setup_valid "3 personas + security focus + research" \
    "Test question" --persona security-engineer --persona startup-cfo --persona junior-developer \
    --focus security --research
}

# --- Stakeholder + Flag Combos ---

@test "stakeholders + research + framework: setup produces valid state" {
  assert_setup_valid "stakeholders + research + risks" \
    "Test question" --mode stakeholders --stakeholders "Eng,Product,Ops" --research --framework risks
}

@test "stakeholders + focus + research + framework: setup produces valid state" {
  assert_setup_valid "stakeholders + all flags" \
    "Test question" --mode stakeholders --stakeholders "Eng,Product" \
    --focus security --research --framework red-team
}

@test "stakeholders + context: setup produces valid state" {
  local ctx_file="${TEST_DIR}/context.txt"
  echo "context" > "$ctx_file"
  assert_setup_valid "stakeholders + context" \
    "Test question" --mode stakeholders --stakeholders "Eng,Ops" --context "$ctx_file"
}

@test "stakeholders with 4 groups: setup produces valid state" {
  assert_setup_valid "4 stakeholders" \
    "Test question" --mode stakeholders --stakeholders "Eng,Product,Ops,Security"
}

# --- Setup → Hook Round-Trip ---

@test "round-trip: analyst + adr + security" {
  assert_round_trip "analyst + adr + security" \
    "Test question" --mode analyst --framework adr --focus security --rounds 1
}

@test "round-trip: philosopher + research" {
  assert_round_trip "philosopher + research" \
    "Test question" --mode philosopher --research --rounds 1
}

@test "round-trip: devils-advocate + red-team" {
  assert_round_trip "devils-advocate + red-team" \
    "Test question" --mode devils-advocate --position "I believe X" --framework red-team --rounds 1
}

@test "round-trip: stakeholders + risks + security focus" {
  assert_round_trip "stakeholders + risks + security" \
    "Test question" --mode stakeholders --stakeholders "Eng,Product" --framework risks --focus security
}

@test "round-trip: 2 personas + adr" {
  assert_round_trip "2 personas + adr" \
    "Test question" --persona security-engineer --persona startup-cfo --framework adr --rounds 1
}

@test "round-trip: 3 personas + research" {
  assert_round_trip "3 personas + research" \
    "Test question" --persona security-engineer --persona startup-cfo --persona junior-developer --research
}
