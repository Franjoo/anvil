#!/bin/bash

# Anvil Stop Hook — Adversarial Debate Orchestrator
#
# State machine: advocate(R1) → critic(R1) → advocate(R2) → critic(R2) → ... → synthesizer → DONE
#
# Reads state from .claude/anvil-state.local.md, extracts last assistant output,
# appends it to the debate transcript, determines the next phase, constructs
# a role-specific prompt, and returns JSON to block exit and inject the prompt.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if anvil debate is active
ANVIL_STATE_FILE=".claude/anvil-state.local.md"

if [[ ! -f "$ANVIL_STATE_FILE" ]]; then
  exit 0
fi

# Parse YAML frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$ANVIL_STATE_FILE")

ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')
QUESTION=$(echo "$FRONTMATTER" | grep '^question:' | sed 's/question: *//' | sed 's/^"\(.*\)"$/\1/')
MODE=$(echo "$FRONTMATTER" | grep '^mode:' | sed 's/mode: *//')
POSITION=$(echo "$FRONTMATTER" | grep '^position:' | sed 's/position: *//' | sed 's/^"\(.*\)"$/\1/')
ROUND=$(echo "$FRONTMATTER" | grep '^round:' | sed 's/round: *//')
MAX_ROUNDS=$(echo "$FRONTMATTER" | grep '^max_rounds:' | sed 's/max_rounds: *//')
PHASE=$(echo "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//')

# Validate state
if [[ "$ACTIVE" != "true" ]]; then
  rm -f "$ANVIL_STATE_FILE"
  exit 0
fi

if [[ ! "$ROUND" =~ ^[0-9]+$ ]]; then
  echo "Warning: Anvil state corrupted (invalid round: '$ROUND'). Cleaning up." >&2
  rm -f "$ANVIL_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ROUNDS" =~ ^[0-9]+$ ]]; then
  echo "Warning: Anvil state corrupted (invalid max_rounds: '$MAX_ROUNDS'). Cleaning up." >&2
  rm -f "$ANVIL_STATE_FILE"
  exit 0
fi

# Validate phase
case "$PHASE" in
  advocate|critic|synthesizer) ;;
  *)
    echo "Warning: Anvil state corrupted (invalid phase: '$PHASE'). Cleaning up." >&2
    rm -f "$ANVIL_STATE_FILE"
    exit 0
    ;;
esac

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Warning: Anvil transcript not found. Cleaning up." >&2
  rm -f "$ANVIL_STATE_FILE"
  exit 0
fi

# Extract last assistant message from transcript (JSONL format)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "Warning: No assistant messages in transcript. Cleaning up." >&2
  rm -f "$ANVIL_STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)

LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null || echo "")

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "Warning: Empty assistant output. Cleaning up." >&2
  rm -f "$ANVIL_STATE_FILE"
  exit 0
fi

# Helper: capitalize first letter (portable, works on macOS)
capitalize() {
  local str="$1"
  local first
  first=$(echo "${str:0:1}" | tr '[:lower:]' '[:upper:]')
  echo "${first}${str:1}"
}

# Check for early completion signal
if echo "$LAST_OUTPUT" | grep -q '<anvil-complete/>'; then
  # Strip the tag from output before appending
  LAST_OUTPUT=$(echo "$LAST_OUTPUT" | sed 's/<anvil-complete\/>//')
  # Force transition to synthesizer if not already there
  if [[ "$PHASE" != "synthesizer" ]]; then
    PHASE="critic"
    ROUND="$MAX_ROUNDS"
  fi
fi

# Append output to state file under the correct heading
PHASE_UPPER=$(capitalize "$PHASE")

if [[ "$PHASE" == "advocate" ]] || [[ "$PHASE" == "critic" ]]; then
  # Check if this round heading already exists
  if ! grep -q "^## Round $ROUND" "$ANVIL_STATE_FILE"; then
    printf "\n## Round %s\n" "$ROUND" >> "$ANVIL_STATE_FILE"
  fi
  printf "\n### %s\n\n%s\n" "$PHASE_UPPER" "$LAST_OUTPUT" >> "$ANVIL_STATE_FILE"
elif [[ "$PHASE" == "synthesizer" ]]; then
  printf "\n## Synthesis\n\n%s\n" "$LAST_OUTPUT" >> "$ANVIL_STATE_FILE"
fi

# --- State Machine Transitions ---

NEXT_PHASE=""
NEXT_ROUND="$ROUND"

case "$PHASE" in
  advocate)
    NEXT_PHASE="critic"
    NEXT_ROUND="$ROUND"
    ;;
  critic)
    if [[ "$ROUND" -lt "$MAX_ROUNDS" ]]; then
      NEXT_PHASE="advocate"
      NEXT_ROUND=$((ROUND + 1))
    else
      NEXT_PHASE="synthesizer"
      NEXT_ROUND="$ROUND"
    fi
    ;;
  synthesizer)
    # Debate complete — write result file and allow exit
    write_result_file() {
      local RESULT_FILE=".claude/anvil-result.local.md"
      local TIMESTAMP
      TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

      cat > "$RESULT_FILE" <<RESULT_EOF
# Anvil Analysis

**Question**: $QUESTION
**Mode**: $MODE
**Rounds**: $ROUND
**Date**: $TIMESTAMP

$LAST_OUTPUT
RESULT_EOF
    }

    write_result_file
    rm -f "$ANVIL_STATE_FILE"
    echo "Anvil debate complete. Result saved to .claude/anvil-result.local.md"
    exit 0
    ;;
esac

# Update state file frontmatter
TEMP_FILE="${ANVIL_STATE_FILE}.tmp.$$"
sed "s/^phase: .*/phase: $NEXT_PHASE/" "$ANVIL_STATE_FILE" | \
  sed "s/^round: .*/round: $NEXT_ROUND/" > "$TEMP_FILE"
mv "$TEMP_FILE" "$ANVIL_STATE_FILE"

# --- Construct Next Prompt ---

# Read role prompt
ROLE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/${NEXT_PHASE}.md" 2>/dev/null || echo "")

# Read mode prompt
MODE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/modes/${MODE}.md" 2>/dev/null || echo "")

# Extract the debate transcript so far (everything after second ---)
TRANSCRIPT_SO_FAR=$(awk '/^---$/{i++; next} i>=2' "$ANVIL_STATE_FILE")

# Build the full prompt
FULL_PROMPT="$MODE_PROMPT

$ROLE_PROMPT

---

**Question under debate:** $QUESTION"

if [[ "$POSITION" != "null" ]] && [[ -n "$POSITION" ]]; then
  FULL_PROMPT="$FULL_PROMPT

**User's stated position:** $POSITION"
fi

FULL_PROMPT="$FULL_PROMPT

## Debate so far

$TRANSCRIPT_SO_FAR

---

You are now in the **$(capitalize "$NEXT_PHASE")** phase"

if [[ "$NEXT_PHASE" != "synthesizer" ]]; then
  FULL_PROMPT="$FULL_PROMPT (Round $NEXT_ROUND of $MAX_ROUNDS)"
fi

FULL_PROMPT="$FULL_PROMPT. Read the debate above carefully, then produce your response."

# Build system message
if [[ "$NEXT_PHASE" == "synthesizer" ]]; then
  SYSTEM_MSG="Anvil: SYNTHESIZER phase — produce balanced final analysis"
else
  SYSTEM_MSG="Anvil: $(echo "$NEXT_PHASE" | tr '[:lower:]' '[:upper:]') phase — Round $NEXT_ROUND of $MAX_ROUNDS"
fi

# Output JSON to block exit and inject next prompt
jq -n \
  --arg prompt "$FULL_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
