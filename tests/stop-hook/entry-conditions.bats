#!/usr/bin/env bats
# Tests for stop-hook guard clauses — all the conditions that cause early exit

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "exits silently when no state file exists" {
  rm -f "$(state_file)"
  setup_hook_input "some output"
  run_stop_hook
  assert_success
  assert_output ""
}

@test "exits silently when state file has active: false" {
  create_state_file active="false"
  setup_hook_input "some output"
  run_stop_hook
  assert_success
  assert_state_cleaned
}

@test "exits with warning when round is non-numeric" {
  create_state_file round="abc"
  setup_hook_input "some output"
  run_stop_hook
  assert_success
  assert_output --partial "state corrupted"
  assert_state_cleaned
}

@test "exits with warning when max_rounds is non-numeric" {
  create_state_file max_rounds="xyz"
  setup_hook_input "some output"
  run_stop_hook
  assert_success
  assert_output --partial "state corrupted"
  assert_state_cleaned
}

@test "exits with warning when phase is invalid" {
  create_state_file phase="unknown-phase"
  setup_hook_input "some output"
  run_stop_hook
  assert_success
  assert_output --partial "state corrupted"
  assert_state_cleaned
}

@test "exits when transcript path does not exist" {
  create_state_file
  HOOK_INPUT=$(jq -n '{"transcript_path": "/nonexistent/path.jsonl"}')
  run_stop_hook
  assert_success
  assert_output --partial "transcript not found"
  assert_state_cleaned
}

@test "exits when transcript has no assistant messages" {
  create_state_file
  local transcript_file="${BATS_TEST_TMPDIR}/empty-transcript.jsonl"
  printf '{"role":"user","message":{"content":[{"type":"text","text":"hello"}]}}\n' > "$transcript_file"
  HOOK_INPUT=$(create_hook_input "$transcript_file")
  run_stop_hook
  assert_success
  assert_output --partial "No assistant messages"
  assert_state_cleaned
}

@test "exits when last assistant message is empty" {
  create_state_file
  local transcript_file="${BATS_TEST_TMPDIR}/empty-msg.jsonl"
  printf '{"role":"assistant","message":{"content":[{"type":"text","text":""}]}}\n' > "$transcript_file"
  HOOK_INPUT=$(create_hook_input "$transcript_file")
  run_stop_hook
  assert_success
  assert_output --partial "Empty assistant output"
  assert_state_cleaned
}

@test "exits with jq error when jq is not available" {
  create_state_file
  # Create a mock bin dir without jq
  local mock_bin="${BATS_TEST_TMPDIR}/mock-no-jq"
  mkdir -p "$mock_bin"
  for cmd in bash cat grep sed awk tr printf rm mkdir wc head tail sort find git date command; do
    local cmd_path
    cmd_path=$(command -v "$cmd" 2>/dev/null || true)
    if [[ -n "$cmd_path" ]]; then
      ln -sf "$cmd_path" "$mock_bin/$cmd"
    fi
  done
  run bash -c 'cd "$1" && PATH="$2" "$3" <<< "{}"' _ "$TEST_DIR" "$mock_bin" "$STOP_HOOK"
  assert_success
  assert_output --partial "jq"
}
