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

# Check for required dependency
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: Anvil requires 'jq'. Install with: brew install jq" >&2
  exit 0
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if anvil debate is active
ANVIL_STATE_FILE=".claude/anvil-state.local.md"

if [[ ! -f "$ANVIL_STATE_FILE" ]]; then
  exit 0
fi

# Helper: capitalize first letter (portable, works on macOS)
capitalize() {
  local str="$1"
  local first
  first=$(printf '%s' "${str:0:1}" | tr '[:lower:]' '[:upper:]')
  printf '%s' "${first}${str:1}"
}

# Parse YAML frontmatter (only lines between first and second ---)
FRONTMATTER=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$ANVIL_STATE_FILE")

ACTIVE=$(printf '%s\n' "$FRONTMATTER" | grep '^active:' | sed 's/active: *//' | tr -d '\r')
QUESTION=$(printf '%s\n' "$FRONTMATTER" | grep '^question:' | sed 's/question: *//' | sed 's/^"\(.*\)"$/\1/' | tr -d '\r')
MODE=$(printf '%s\n' "$FRONTMATTER" | grep '^mode:' | sed 's/mode: *//' | tr -d '\r')
POSITION=$(printf '%s\n' "$FRONTMATTER" | grep '^position:' | sed 's/position: *//' | sed 's/^"\(.*\)"$/\1/' | tr -d '\r')
ROUND=$(printf '%s\n' "$FRONTMATTER" | grep '^round:' | sed 's/round: *//' | tr -d '\r')
MAX_ROUNDS=$(printf '%s\n' "$FRONTMATTER" | grep '^max_rounds:' | sed 's/max_rounds: *//' | tr -d '\r')
PHASE=$(printf '%s\n' "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//' | tr -d '\r')
RESEARCH=$(printf '%s\n' "$FRONTMATTER" | grep '^research:' | sed 's/research: *//' | tr -d '\r')

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
TRANSCRIPT_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.transcript_path')

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

LAST_OUTPUT=$(printf '%s' "$LAST_LINE" | jq -r '
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

# Save the original phase for transcript attribution before any modification
ORIGINAL_PHASE="$PHASE"
ORIGINAL_ROUND="$ROUND"

# Check for early completion signal
if printf '%s' "$LAST_OUTPUT" | grep -q '<anvil-complete/>'; then
  # Strip the tag from output before appending
  LAST_OUTPUT=$(printf '%s' "$LAST_OUTPUT" | sed 's/<anvil-complete\/>//')
  # Force transition to synthesizer if not already there
  if [[ "$PHASE" != "synthesizer" ]]; then
    PHASE="critic"
    ROUND="$MAX_ROUNDS"
  fi
fi

# Append output to state file under the correct heading (use ORIGINAL phase/round)
PHASE_UPPER=$(capitalize "$ORIGINAL_PHASE")

if [[ "$ORIGINAL_PHASE" == "advocate" ]] || [[ "$ORIGINAL_PHASE" == "critic" ]]; then
  # Check if this round heading already exists
  if ! grep -q "^## Round $ORIGINAL_ROUND" "$ANVIL_STATE_FILE"; then
    printf '\n## Round %s\n' "$ORIGINAL_ROUND" >> "$ANVIL_STATE_FILE"
  fi
  printf '\n### %s\n\n%s\n' "$PHASE_UPPER" "$LAST_OUTPUT" >> "$ANVIL_STATE_FILE"
elif [[ "$ORIGINAL_PHASE" == "synthesizer" ]]; then
  printf '\n## Synthesis\n\n%s\n' "$LAST_OUTPUT" >> "$ANVIL_STATE_FILE"
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
    RESULT_FILE=".claude/anvil-result.local.md"
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    printf '# Anvil Analysis\n\n**Question**: %s\n**Mode**: %s\n**Rounds**: %s\n**Date**: %s\n\n%s\n' \
      "$QUESTION" "$MODE" "$ROUND" "$TIMESTAMP" "$LAST_OUTPUT" > "$RESULT_FILE"

    rm -f "$ANVIL_STATE_FILE"
    echo "Anvil debate complete. Result saved to .claude/anvil-result.local.md"
    exit 0
    ;;
esac

# Update state file frontmatter (only within frontmatter block, not transcript body)
TEMP_FILE="${ANVIL_STATE_FILE}.tmp.$$"
awk -v next_phase="$NEXT_PHASE" -v next_round="$NEXT_ROUND" '
  /^---$/ { count++ }
  count <= 1 && /^phase: / { print "phase: " next_phase; next }
  count <= 1 && /^round: / { print "round: " next_round; next }
  { print }
' "$ANVIL_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$ANVIL_STATE_FILE"

# --- Construct Next Prompt ---

# Read role prompt
ROLE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/${NEXT_PHASE}.md" 2>/dev/null || echo "")

# Read mode prompt
MODE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/modes/${MODE}.md" 2>/dev/null || echo "")

# Extract the debate transcript so far (everything after second ---)
TRANSCRIPT_SO_FAR=$(awk '/^---$/{i++; next} i>=2' "$ANVIL_STATE_FILE")

# Build research instructions if enabled
RESEARCH_BLOCK=""
if [[ "$RESEARCH" == "true" ]]; then
  if [[ "$NEXT_PHASE" == "advocate" ]]; then
    RESEARCH_BLOCK="
## Research Mode ENABLED

Before constructing your argument, use **WebSearch** to research the topic. Ground your claims in real evidence:
- Search for data, studies, benchmarks, and case studies that SUPPORT your position
- Look for real-world examples and success stories
- Find specific numbers, dates, and facts — not vague generalities
- Cite your sources inline: [Source Title](URL)

Perform at least 2-3 targeted searches. Respond to the Critic's points from the previous round with researched counter-evidence where possible."
  elif [[ "$NEXT_PHASE" == "critic" ]]; then
    RESEARCH_BLOCK="
## Research Mode ENABLED

Before constructing your critique, use **WebSearch** to research counter-evidence. Ground your critique in real evidence:
- Search for data that CONTRADICTS the Advocate's claims
- Look for failure cases, counter-examples, and cautionary tales
- Fact-check specific claims the Advocate made — verify or debunk them
- Find alternative perspectives and competing studies
- Cite your sources inline: [Source Title](URL)

Perform at least 2-3 targeted searches. If the Advocate cited sources, verify their accuracy."
  elif [[ "$NEXT_PHASE" == "synthesizer" ]]; then
    RESEARCH_BLOCK="
## Research Mode ENABLED

Before synthesizing, use **WebSearch** to fact-check the strongest claims from both sides:
- Verify key statistics and data points cited during the debate
- Check if cited sources actually support the claims made
- Search for any major perspective that BOTH sides missed
- Cite your sources inline: [Source Title](URL)

Perform 1-2 targeted verification searches. Your synthesis should note which cited evidence held up and which didn't."
  fi
fi

# Build the full prompt
FULL_PROMPT="$MODE_PROMPT

$ROLE_PROMPT
$RESEARCH_BLOCK

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
  SYSTEM_MSG="Anvil: $(printf '%s' "$NEXT_PHASE" | tr '[:lower:]' '[:upper:]') phase — Round $NEXT_ROUND of $MAX_ROUNDS"
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
