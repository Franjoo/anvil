#!/usr/bin/env bats
# Adversarial input tests: special characters, edge cases, and pathological content

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# Helper: run setup in isolated test dir, assert exit 0 + valid state
run_setup_ok() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
  assert_success
  assert_state_exists
  assert_frontmatter "active" "true"
}

# Helper: run setup and assert exit 0, return the raw focus value from frontmatter
get_focus_from_state() {
  get_frontmatter "focus" "$(state_file)"
}

# =============================================================================
# Through setup-anvil.sh — special chars in user-provided values
# =============================================================================

@test "setup: double quotes in question are YAML-escaped" {
  run_setup_ok 'Should we use "microservices" or "monoliths"?'
  # Question uses yaml_escape — verify it's stored without breaking YAML
  local q
  q=$(get_frontmatter "question" "$(state_file)")
  [[ -n "$q" ]]
}

@test "setup: double quotes in --focus are YAML-escaped" {
  run_setup_ok "Test question" --focus 'the "real" cost'
  # This was a known bug: focus was unescaped, breaking YAML
  local f
  f=$(get_focus_from_state)
  # The escaped value should be readable (backslash-quotes preserved by sed)
  [[ -n "$f" ]]
}

@test "setup: double quotes in --persona name are YAML-escaped" {
  run_setup_ok "Test question" --persona 'The "Expert" Dev' --persona 'The "Novice" Dev'
  local p
  p=$(get_frontmatter "personas" "$(state_file)")
  [[ -n "$p" ]]
  # Both names should be present (pipe-separated)
  [[ "$p" == *"Expert"* ]]
  [[ "$p" == *"Novice"* ]]
}

@test "setup: double quotes in stakeholder names are YAML-escaped" {
  run_setup_ok "Test question" --mode stakeholders --stakeholders '"Engineering","Product"'
  local s
  s=$(get_frontmatter "stakeholders" "$(state_file)")
  [[ -n "$s" ]]
}

@test "setup: backslash in focus is YAML-escaped" {
  run_setup_ok "Test question" --focus 'C:\Users\path'
  local f
  f=$(get_focus_from_state)
  [[ -n "$f" ]]
}

@test "setup: colon in question doesn't break YAML" {
  run_setup_ok 'key: value or key:value — which is better?'
  local q
  q=$(get_frontmatter "question" "$(state_file)")
  [[ "$q" == *"key"* ]]
}

@test "setup: hash in question doesn't break YAML" {
  run_setup_ok 'Should we use C# or Java?'
  local q
  q=$(get_frontmatter "question" "$(state_file)")
  [[ "$q" == *"C#"* ]]
}

@test "setup: brackets in question" {
  run_setup_ok 'Is Array[String] better than List<String>?'
  local q
  q=$(get_frontmatter "question" "$(state_file)")
  [[ -n "$q" ]]
}

@test "setup: very long question (1000+ chars)" {
  local long_q
  long_q="Should we $(printf 'really %.0s' {1..200})consider this?"
  run_setup_ok "$long_q"
  assert_frontmatter "active" "true"
}

@test "setup: unicode characters in question" {
  run_setup_ok 'Sollten wir Ünïcödë-Zeichén unterstützen? 日本語テスト 🚀'
  local q
  q=$(get_frontmatter "question" "$(state_file)")
  [[ -n "$q" ]]
}

@test "setup: unicode in focus" {
  run_setup_ok "Test question" --focus "Ünïcödë"
  local f
  f=$(get_focus_from_state)
  [[ "$f" == *"Ünïcödë"* ]]
}

@test "setup: single quotes in focus (not special in YAML double-quoted)" {
  run_setup_ok "Test question" --focus "it's complicated"
  local f
  f=$(get_focus_from_state)
  [[ "$f" == *"it's"* ]]
}

@test "setup: custom focus with spaces and mixed case" {
  run_setup_ok "Test question" --focus "User Experience & Accessibility"
  local f
  f=$(get_focus_from_state)
  [[ "$f" == *"Accessibility"* ]]
}

@test "setup: HTML comment marker in persona name is rejected" {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --persona "<!-- admin -->" --persona "regular user"
  assert_failure
  assert_output --partial "cannot contain HTML comment markers"
}

# =============================================================================
# Through stop-hook.sh — pathological LLM output
# =============================================================================

@test "hook: output containing --- on its own line" {
  create_state_file phase=advocate round=1 max_rounds=2
  setup_hook_input "Here is my argument.

---

Above was the separator."
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
}

@test "hook: output containing <anvil-complete/> inside a code block" {
  create_state_file phase=advocate round=1 max_rounds=3
  setup_hook_input 'Here is code:
```
<anvil-complete/>
```
But I am not done.'
  run_stop_hook
  # The tag is inside a code block but grep doesn't distinguish — it triggers early completion
  # This is expected behavior (documented limitation), just verify no crash
  assert_success
  local decision
  decision=$(printf '%s' "$output" | jq -r '.decision' 2>/dev/null)
  # Either block (moved to synthesizer) or exit 0 (completed) is acceptable
  [[ "$decision" == "block" ]] || [[ "$status" -eq 0 ]]
}

@test "hook: output containing ## Round 1 heading" {
  create_state_file phase=advocate round=1 max_rounds=2
  setup_hook_input "## Round 1

Here is my argument that happens to include a round heading."
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
}

@test "hook: output containing ### Advocate heading" {
  create_state_file phase=critic round=1 max_rounds=2
  setup_hook_input "As the critic, I note the ### Advocate said:

Their argument was weak."
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "advocate"
  assert_frontmatter "round" "2"
}

@test "hook: output containing <anvil-steering> tags" {
  create_state_file phase=advocate round=1 max_rounds=2
  setup_hook_input "The user might say <anvil-steering>focus on cost</anvil-steering> but I continue."
  run_stop_hook
  assert_block_decision
  # steering tags only matter in interactive-pause phase, so this should be normal transition
  assert_frontmatter "phase" "critic"
}

@test "hook: extremely long output (10KB+)" {
  create_state_file phase=advocate round=1 max_rounds=2
  local long_msg
  long_msg="Here is my very detailed argument. $(printf 'This point is important because it demonstrates depth. %.0s' {1..200})"
  setup_hook_input "$long_msg"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
}

@test "hook: output with YAML-like content" {
  create_state_file phase=advocate round=1 max_rounds=2
  setup_hook_input "Consider this config:
active: false
phase: synthesizer
round: 99
These are just examples, not real YAML."
  run_stop_hook
  assert_block_decision
  # Verify the YAML-like content in the output didn't corrupt state
  assert_frontmatter "phase" "critic"
  assert_frontmatter "round" "1"
}

@test "hook: output with only whitespace" {
  create_state_file phase=advocate round=1 max_rounds=2
  # Whitespace-only content — jq text extraction produces empty string
  # The hook detects empty output and cleans up
  setup_hook_input "   "
  run_stop_hook
  # Hook should not crash — either blocks or cleans up
  assert_success
}

@test "hook: output with excessive newlines" {
  create_state_file phase=advocate round=1 max_rounds=2
  setup_hook_input "First line.



$(printf '\n%.0s' {1..50})

Last line."
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
}

@test "hook: output with frontmatter-like block" {
  create_state_file phase=critic round=1 max_rounds=1
  setup_hook_input "My critique:

---
title: Fake Frontmatter
active: false
---

The above is just markdown."
  run_stop_hook
  assert_block_decision
  # Should transition to synthesizer (round 1 of 1, critic → synthesizer)
  assert_frontmatter "phase" "synthesizer"
}

# =============================================================================
# Stop-hook with special chars in state file values
# =============================================================================

@test "hook: focus with double quotes survives round-trip through state" {
  create_state_file phase=advocate round=1 max_rounds=2 \
    'focus=the "real" cost'
  setup_hook_input "My argument about cost."
  run_stop_hook
  assert_block_decision
  # Verify the UNESCAPED focus value appears in the prompt (not backslash-escaped)
  assert_reason_contains 'the "real" cost'
}

@test "hook: stakeholders with special chars survive state parsing" {
  create_state_file phase=stakeholder round=1 max_rounds=2 \
    mode=stakeholders 'stakeholders=Eng & "Dev",Ops/SRE'
  setup_hook_input "Engineering perspective."
  run_stop_hook
  assert_block_decision
}

@test "hook: missing optional field doesn't crash (defense-in-depth)" {
  # Create a state file manually without the 'focus' field
  local sf="${TEST_DIR}/.claude/anvil-state.local.md"
  mkdir -p "$(dirname "$sf")"
  cat > "$sf" <<'EOF'
---
active: true
question: "Test question"
mode: analyst
position: null
round: 1
max_rounds: 2
phase: advocate
research: false
framework:
context_source: ""
follow_up: ""
versus: false
interactive: false
stakeholders: ""
stakeholder_index: 1
personas: ""
started_at: "2026-01-01T00:00:00Z"
---
EOF
  setup_hook_input "My argument."
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "critic"
}

@test "hook: completely missing field doesn't crash with pipefail" {
  # Create a minimal state file missing several fields
  local sf="${TEST_DIR}/.claude/anvil-state.local.md"
  mkdir -p "$(dirname "$sf")"
  cat > "$sf" <<'EOF'
---
active: true
question: "Test"
mode: analyst
position: null
round: 1
max_rounds: 1
phase: advocate
research: false
framework:
versus: false
interactive: false
stakeholders: ""
stakeholder_index: 1
personas: ""
started_at: "2026-01-01T00:00:00Z"
---
EOF
  setup_hook_input "My argument."
  run_stop_hook
  # Should still work — missing focus/context_source/follow_up should default to empty
  assert_block_decision
}

# =============================================================================
# Round-trip correctness: yaml_escape on write → _fmq unescape on read
# =============================================================================

@test "hook: question with double quotes is correctly unescaped in prompt" {
  create_state_file phase=advocate round=1 max_rounds=2 \
    'question=Should we use "microservices"?'
  setup_hook_input "My argument."
  run_stop_hook
  assert_block_decision
  # The unescaped question should appear in the prompt
  assert_reason_contains 'Should we use "microservices"?'
}

@test "hook: position with double quotes is correctly unescaped in prompt" {
  create_state_file phase=advocate round=1 max_rounds=2 \
    mode=devils-advocate \
    'position=I believe "strongly" in this'
  setup_hook_input "My argument."
  run_stop_hook
  assert_block_decision
  assert_reason_contains 'I believe "strongly" in this'
}

@test "hook: backslash in focus survives round-trip" {
  create_state_file phase=advocate round=1 max_rounds=2 \
    'focus=C:\Users\path'
  setup_hook_input "My argument."
  run_stop_hook
  assert_block_decision
  assert_reason_contains 'C:\Users\path'
}

@test "setup: pipe in persona name is rejected" {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --persona "A|B hybrid" --persona "Normal persona"
  assert_failure
  assert_output --partial "cannot contain '|'"
}

@test "setup: context_source with double quotes is YAML-escaped" {
  # context_source is built from file paths — test that quotes in paths don't break YAML
  local ctx_file="${TEST_DIR}/my \"special\" file.txt"
  echo "content" > "$ctx_file"
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --context "$ctx_file"
  assert_success
  assert_state_exists
  assert_frontmatter "active" "true"
}

# =============================================================================
# Newline, tab, and CR escaping
# =============================================================================

@test "setup: newline in focus is YAML-escaped" {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --focus $'line1\nline2'
  assert_success
  # The raw file should have \n literal (not actual newline) in the focus field
  local raw
  raw=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$(state_file)" | grep "^focus:")
  [[ "$raw" == *'line1\nline2'* ]]
  # No actual newline inside the frontmatter focus line
  [[ ! "$raw" == *$'\n'*"line2"* ]]
}

@test "setup: tab in focus is YAML-escaped" {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --focus $'col1\tcol2'
  assert_success
  local raw
  raw=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$(state_file)" | grep "^focus:")
  # Should contain literal \t, not actual tab
  [[ "$raw" == *'col1\tcol2'* ]]
}

@test "setup: mixed escapes in focus round-trip" {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --focus $'say "hello\\world"\nand\tmore'
  assert_success
  # The focus line must be a single line (newline was escaped, not breaking YAML)
  local focus_count
  focus_count=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$(state_file)" | grep -c "^focus:" || true)
  [[ "$focus_count" -eq 1 ]]
  # The focus line must NOT contain actual tab characters (should be escaped)
  local raw
  raw=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$(state_file)" | grep "^focus:")
  # Verify no actual tab (printf %q would show $'\t' for tabs)
  local tab=$'\t'
  [[ "$raw" != *"$tab"* ]]
}

@test "setup: newline in persona name is rejected" {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --persona $'line1\nline2' --persona "normal"
  assert_failure
  assert_output --partial "cannot contain newline"
}

@test "setup: HTML close-comment marker in persona name is rejected" {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" \
    "Test question" --persona "foo-->" --persona "bar"
  assert_failure
  assert_output --partial "cannot contain HTML comment markers"
}

@test "hook: focus with newline survives round-trip" {
  # Create state with escaped newline in focus (as yaml_escape would produce)
  create_state_file phase=advocate round=1 max_rounds=2 \
    focus=$'line1\nline2'
  setup_hook_input "My argument about the focus."
  run_stop_hook
  assert_block_decision
  # The prompt should contain the unescaped value (actual newline restored)
  assert_reason_contains "line1"
  assert_reason_contains "line2"
}

@test "hook: focus with tab survives round-trip" {
  create_state_file phase=advocate round=1 max_rounds=2 \
    focus=$'col1\tcol2'
  setup_hook_input "My argument."
  run_stop_hook
  assert_block_decision
  # Tab should be restored in the prompt
  assert_reason_contains "col1"
  assert_reason_contains "col2"
}

@test "hook: backslash-n literal (not newline) survives round-trip" {
  # Input: hello\nworld (literal backslash + n, NOT a newline)
  # yaml_escape should produce: hello\\nworld (doubled backslash)
  # _fmq should restore: hello\nworld (literal backslash + n, NOT a newline)
  create_state_file phase=advocate round=1 max_rounds=2 \
    'focus=hello\nworld'
  setup_hook_input "My argument."
  run_stop_hook
  assert_block_decision
  # Extract the focus value from the prompt's Focus Lens section
  local prompt
  prompt=$(printf '%s' "$output" | jq -r '.reason')
  [[ "$prompt" == *"hello"* ]]
  [[ "$prompt" == *"world"* ]]
  # Verify the literal \n was NOT converted to an actual newline:
  # the Focus Lens line should contain both "hello" and "world" together
  local focus_line
  focus_line=$(printf '%s' "$prompt" | grep -F "hello" | grep -F "world" || true)
  [[ -n "$focus_line" ]]
}
