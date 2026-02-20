#!/usr/bin/env bash
# State file generator for Anvil tests
#
# Usage:
#   create_state_file [KEY=VALUE ...]
#
# Creates a state file at $TEST_DIR/.claude/anvil-state.local.md
# with the given frontmatter overrides. Defaults are provided for all fields.

create_state_file() {
  local active="true"
  local question="\"Should we use microservices?\""
  local mode="analyst"
  local position="null"
  local round="1"
  local max_rounds="3"
  local phase="advocate"
  local research="false"
  local framework=""
  local focus=""
  local context_source=""
  local follow_up=""
  local versus="false"
  local interactive="false"
  local stakeholders=""
  local stakeholder_index="1"
  local personas=""
  local started_at="2026-01-01T00:00:00Z"
  local body=""

  # Parse key=value arguments
  for arg in "$@"; do
    case "$arg" in
      active=*) active="${arg#active=}" ;;
      question=*) question="${arg#question=}" ;;
      mode=*) mode="${arg#mode=}" ;;
      position=*) position="${arg#position=}" ;;
      round=*) round="${arg#round=}" ;;
      max_rounds=*) max_rounds="${arg#max_rounds=}" ;;
      phase=*) phase="${arg#phase=}" ;;
      research=*) research="${arg#research=}" ;;
      framework=*) framework="${arg#framework=}" ;;
      focus=*) focus="${arg#focus=}" ;;
      context_source=*) context_source="${arg#context_source=}" ;;
      follow_up=*) follow_up="${arg#follow_up=}" ;;
      versus=*) versus="${arg#versus=}" ;;
      interactive=*) interactive="${arg#interactive=}" ;;
      stakeholders=*) stakeholders="${arg#stakeholders=}" ;;
      stakeholder_index=*) stakeholder_index="${arg#stakeholder_index=}" ;;
      personas=*) personas="${arg#personas=}" ;;
      started_at=*) started_at="${arg#started_at=}" ;;
      body=*) body="${arg#body=}" ;;
    esac
  done

  local state_file="${TEST_DIR}/.claude/anvil-state.local.md"
  mkdir -p "$(dirname "$state_file")"

  cat > "$state_file" <<EOF
---
active: $active
question: $question
mode: $mode
position: $position
round: $round
max_rounds: $max_rounds
phase: $phase
research: $research
framework: $framework
focus: "$focus"
context_source: "$context_source"
follow_up: "$follow_up"
versus: $versus
interactive: $interactive
stakeholders: "$stakeholders"
stakeholder_index: $stakeholder_index
personas: "$personas"
started_at: "$started_at"
---
EOF

  if [[ -n "$body" ]]; then
    printf '%s\n' "$body" >> "$state_file"
  fi

  echo "$state_file"
}

# Add persona descriptions to an existing state file
# Usage: add_persona_to_state "persona-name" "description"
add_persona_to_state() {
  local name="$1"
  local desc="$2"
  local state_file="${TEST_DIR}/.claude/anvil-state.local.md"
  printf '\n<!-- persona:%s -->\n%s\n<!-- /persona -->\n' "$name" "$desc" >> "$state_file"
}

# Add a round transcript to an existing state file
# Usage: add_round_to_state round_num advocate_text critic_text
add_round_to_state() {
  local round_num="$1"
  local advocate_text="$2"
  local critic_text="${3:-}"
  local state_file="${TEST_DIR}/.claude/anvil-state.local.md"

  printf '\n## Round %s\n' "$round_num" >> "$state_file"
  printf '\n### Advocate\n\n%s\n' "$advocate_text" >> "$state_file"
  if [[ -n "$critic_text" ]]; then
    printf '\n### Critic\n\n%s\n' "$critic_text" >> "$state_file"
  fi
}
