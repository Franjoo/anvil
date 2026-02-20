#!/usr/bin/env bats
# Tests for context generation (--context, --pr, --diff, --versus, --follow-up)

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/assertions"

run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- --context file ---

@test "context file: content included in output and state" {
  echo "function hello() { return 'world'; }" > "${TEST_DIR}/main.ts"
  run_setup "question" --context "${TEST_DIR}/main.ts"
  assert_success
  assert_output --partial "Codebase Context"
  assert_state_body_contains "Codebase Context"
}

@test "context file: line count shown" {
  printf 'line1\nline2\nline3\n' > "${TEST_DIR}/small.ts"
  run_setup "question" --context "${TEST_DIR}/small.ts"
  assert_success
  assert_output --partial "3 lines"
}

@test "context directory: tree included" {
  mkdir -p "${TEST_DIR}/src"
  echo "export class Foo {}" > "${TEST_DIR}/src/foo.ts"
  echo "export class Bar {}" > "${TEST_DIR}/src/bar.ts"
  run_setup "question" --context "${TEST_DIR}/src"
  assert_success
  assert_output --partial "Directory:"
}

@test "multiple --context flags" {
  echo "file A" > "${TEST_DIR}/a.ts"
  echo "file B" > "${TEST_DIR}/b.ts"
  run_setup "question" --context "${TEST_DIR}/a.ts" --context "${TEST_DIR}/b.ts"
  assert_success
  assert_state_body_contains "a.ts"
  assert_state_body_contains "b.ts"
}

@test "context source stored in frontmatter" {
  echo "content" > "${TEST_DIR}/main.ts"
  run_setup "question" --context "${TEST_DIR}/main.ts"
  local ctx
  ctx=$(get_frontmatter "context_source" "$(state_file)")
  [[ "$ctx" == *"main.ts"* ]]
}

# --- --diff ---

@test "diff context: includes uncommitted changes section" {
  run_setup "question" --diff
  assert_success
  assert_output --partial "Uncommitted Changes"
}

@test "diff context: shows no changes when clean" {
  run_setup "question" --diff
  assert_success
  assert_output --partial "no uncommitted changes"
}

# --- --versus ---

@test "versus: both positions appended to state" {
  echo "Position A analysis" > "${TEST_DIR}/a.md"
  echo "Position B analysis" > "${TEST_DIR}/b.md"
  run_setup "question" --versus "${TEST_DIR}/a.md" "${TEST_DIR}/b.md"
  assert_success
  assert_state_body_contains "Position A analysis"
  assert_state_body_contains "Position B analysis"
}

@test "versus: output shows both source files" {
  echo "A" > "${TEST_DIR}/a.md"
  echo "B" > "${TEST_DIR}/b.md"
  run_setup "question" --versus "${TEST_DIR}/a.md" "${TEST_DIR}/b.md"
  assert_output --partial "Versus:"
}

# --- --follow-up ---

@test "follow-up: prior analysis content in state" {
  echo "Prior conclusion: monoliths win" > "${TEST_DIR}/prior.md"
  run_setup "question" --follow-up "${TEST_DIR}/prior.md"
  assert_success
  assert_state_body_contains "Prior Analysis"
  assert_state_body_contains "Prior conclusion: monoliths win"
}

# --- Context truncation ---

@test "context truncated when exceeding max chars" {
  # Generate a file larger than CONTEXT_MAX_CHARS (5000)
  local big_file="${TEST_DIR}/big.ts"
  python3 -c "print('// ' + 'x' * 200, end='\n')" > "$big_file"
  for i in $(seq 1 60); do
    echo "export function func${i}() { return $i; }" >> "$big_file"
  done
  # Pad to exceed 5000 chars
  python3 -c "
for i in range(100):
    print(f'// padding line {i} with enough text to make this file very long indeed')
" >> "$big_file"
  run_setup "question" --context "$big_file"
  assert_success
  assert_output --partial "context truncated"
}

# --- File truncation at 150 lines ---

@test "large file truncated at 150 lines" {
  local big_file="${TEST_DIR}/large.ts"
  for i in $(seq 1 200); do
    echo "line $i" >> "$big_file"
  done
  run_setup "question" --context "$big_file"
  assert_success
  assert_output --partial "truncated"
  assert_output --partial "200 total lines"
}

# --- Mixed context sources ---

@test "context with file and directory" {
  echo "single file" > "${TEST_DIR}/single.ts"
  mkdir -p "${TEST_DIR}/mydir"
  echo "dir file" > "${TEST_DIR}/mydir/inner.ts"
  run_setup "question" --context "${TEST_DIR}/single.ts" --context "${TEST_DIR}/mydir"
  assert_success
  assert_output --partial "File:"
  assert_output --partial "Directory:"
}
