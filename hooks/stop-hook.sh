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
FRAMEWORK=$(printf '%s\n' "$FRONTMATTER" | grep '^framework:' | sed 's/framework: *//' | tr -d '\r')
FOCUS=$(printf '%s\n' "$FRONTMATTER" | grep '^focus:' | sed 's/focus: *//' | sed 's/^"\(.*\)"$/\1/' | tr -d '\r')
CONTEXT_SOURCE=$(printf '%s\n' "$FRONTMATTER" | grep '^context_source:' | sed 's/context_source: *//' | sed 's/^"\(.*\)"$/\1/' | tr -d '\r')
VERSUS=$(printf '%s\n' "$FRONTMATTER" | grep '^versus:' | sed 's/versus: *//' | tr -d '\r')
INTERACTIVE=$(printf '%s\n' "$FRONTMATTER" | grep '^interactive:' | sed 's/interactive: *//' | tr -d '\r')

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
  advocate|critic|synthesizer|interactive-pause) ;;
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
# Skip transcript append for interactive-pause (meta-conversation, not debate content)
PHASE_UPPER=$(capitalize "$ORIGINAL_PHASE")

if [[ "$ORIGINAL_PHASE" == "interactive-pause" ]]; then
  : # Do not append interactive-pause output to debate transcript
elif [[ "$ORIGINAL_PHASE" == "advocate" ]] || [[ "$ORIGINAL_PHASE" == "critic" ]]; then
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
      # In interactive mode, pause for user steering between rounds
      if [[ "$INTERACTIVE" == "true" ]]; then
        NEXT_PHASE="interactive-pause"
        NEXT_ROUND="$ROUND"
      else
        NEXT_PHASE="advocate"
        NEXT_ROUND=$((ROUND + 1))
      fi
    else
      NEXT_PHASE="synthesizer"
      NEXT_ROUND="$ROUND"
    fi
    ;;
  interactive-pause)
    # Extract steering from the last output
    STEERING=""
    if printf '%s' "$LAST_OUTPUT" | grep -q '<anvil-steering>'; then
      STEERING=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*<anvil-steering>\(.*\)<\/anvil-steering>.*/\1/p')
    fi
    # Check for skip-to-synthesis
    if [[ "$STEERING" == "synthesize" ]] || [[ "$STEERING" == "skip" ]]; then
      NEXT_PHASE="synthesizer"
      NEXT_ROUND="$ROUND"
    else
      NEXT_PHASE="advocate"
      NEXT_ROUND=$((ROUND + 1))
    fi
    ;;
  synthesizer)
    # Debate complete — write result file and allow exit
    RESULT_FILE=".claude/anvil-result.local.md"
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    RESEARCH_LABEL="no"
    if [[ "$RESEARCH" == "true" ]]; then
      RESEARCH_LABEL="yes"
    fi

    FRAMEWORK_LABEL=""
    if [[ -n "$FRAMEWORK" ]]; then
      FRAMEWORK_LABEL="$FRAMEWORK"
    fi

    RESULT_HEADER=$(printf '# Anvil Analysis\n\n**Question**: %s\n**Mode**: %s\n**Rounds**: %s\n**Research**: %s' \
      "$QUESTION" "$MODE" "$ROUND" "$RESEARCH_LABEL")
    if [[ -n "$FRAMEWORK_LABEL" ]]; then
      RESULT_HEADER=$(printf '%s\n**Framework**: %s' "$RESULT_HEADER" "$FRAMEWORK_LABEL")
    fi
    if [[ -n "$FOCUS" ]]; then
      RESULT_HEADER=$(printf '%s\n**Focus**: %s' "$RESULT_HEADER" "$FOCUS")
    fi
    if [[ -n "$CONTEXT_SOURCE" ]]; then
      RESULT_HEADER=$(printf '%s\n**Context**: %s' "$RESULT_HEADER" "$CONTEXT_SOURCE")
    fi
    RESULT_HEADER=$(printf '%s\n**Date**: %s' "$RESULT_HEADER" "$TIMESTAMP")

    printf '%s\n\n%s\n' "$RESULT_HEADER" "$LAST_OUTPUT" > "$RESULT_FILE"

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

# Extract the debate transcript so far (everything after second ---)
TRANSCRIPT_SO_FAR=$(awk '/^---$/{i++; next} i>=2' "$ANVIL_STATE_FILE")

# Handle interactive-pause prompt separately (it's a meta-phase, not a debate phase)
if [[ "$NEXT_PHASE" == "interactive-pause" ]]; then
  PAUSE_PROMPT="# Round $ROUND Complete — Interactive Steering

Summarize this round of the debate concisely:
1. **Advocate's key arguments** this round (2-3 bullet points)
2. **Critic's key counterarguments** this round (2-3 bullet points)
3. **Current state**: Which side seems stronger so far?

Then ask the user how they want to steer the next round. Use the AskUserQuestion tool with these options:
- \"Continue automatically\" — let the debate proceed without steering
- \"Focus the debate\" — provide a specific angle or constraint for the next round
- \"Skip to synthesis\" — end the debate early and produce the final analysis

After receiving the user's response, output exactly one of these tags at the END of your response:
- If the user wants to continue: \`<anvil-steering>none</anvil-steering>\`
- If the user provides direction: \`<anvil-steering>THEIR DIRECTION HERE</anvil-steering>\`
- If the user wants synthesis: \`<anvil-steering>synthesize</anvil-steering>\`

## Debate so far

$TRANSCRIPT_SO_FAR"

  SYSTEM_MSG="Anvil: INTERACTIVE PAUSE — Round $ROUND complete, awaiting user steering"

  jq -n \
    --arg prompt "$PAUSE_PROMPT" \
    --arg msg "$SYSTEM_MSG" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }'
  exit 0
fi

# If we just came from interactive-pause with steering, inject it
STEERING_BLOCK=""
if [[ "$PHASE" == "interactive-pause" ]] && [[ -n "$STEERING" ]] && [[ "$STEERING" != "none" ]]; then
  STEERING_BLOCK="
## User Steering Directive

The user has directed the next round to focus on: **$STEERING**

Incorporate this directive into your argument. Address the user's concern directly."
fi

# Read role prompt
ROLE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/${NEXT_PHASE}.md" 2>/dev/null || echo "")

# Read mode prompt
MODE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/modes/${MODE}.md" 2>/dev/null || echo "")

# Read framework template (synthesizer only)
FRAMEWORK_PROMPT=""
if [[ "$NEXT_PHASE" == "synthesizer" ]] && [[ -n "$FRAMEWORK" ]]; then
  FRAMEWORK_PROMPT=$(cat "$PLUGIN_ROOT/prompts/frameworks/${FRAMEWORK}.md" 2>/dev/null || echo "")
fi

# Build research instructions if enabled (mode-aware)
RESEARCH_BLOCK=""
if [[ "$RESEARCH" == "true" ]]; then
  # Mode-specific research guidance
  RESEARCH_FOCUS=""
  case "$MODE" in
    analyst)
      RESEARCH_FOCUS_ADVOCATE="- Search for data, studies, benchmarks, and case studies that SUPPORT your position
- Look for real-world examples, success stories, and adoption metrics
- Find specific numbers, dates, and measurable outcomes — not vague generalities"
      RESEARCH_FOCUS_CRITIC="- Search for data that CONTRADICTS the Advocate's claims
- Look for failure cases, counter-examples, and cautionary tales
- Fact-check specific claims the Advocate made — verify or debunk them
- Find alternative perspectives and competing studies"
      RESEARCH_FOCUS_SYNTH="- Verify key statistics and data points cited during the debate
- Check if cited sources actually support the claims made
- If a claim lacks a source, search to confirm or refute it"
      ;;
    philosopher)
      RESEARCH_FOCUS_ADVOCATE="- Search for philosophical arguments, frameworks, and thinkers that support your position
- Look for historical precedents and analogous ethical dilemmas
- Find thought experiments or academic papers that illuminate your thesis
- Search for how this question has been debated in philosophy, ethics, or social theory"
      RESEARCH_FOCUS_CRITIC="- Search for philosophical counter-arguments and opposing frameworks
- Look for historical cases where similar reasoning led to problematic outcomes
- Find critiques of the frameworks the Advocate relied on
- Search for thinkers who have argued against this position"
      RESEARCH_FOCUS_SYNTH="- Verify if cited philosophical arguments and thinkers are accurately represented
- Check if historical precedents cited actually support the claims made
- Search for any major philosophical framework that both sides overlooked"
      ;;
    devils-advocate)
      RESEARCH_FOCUS_ADVOCATE="- Search for evidence that UNDERMINES the user's stated position
- Look for failure cases, risks, and overlooked consequences
- Find real-world examples where similar positions turned out wrong
- Search for the strongest arguments against the user's stance"
      RESEARCH_FOCUS_CRITIC="- Search for evidence that SUPPORTS and DEFENDS the user's position
- Look for success stories and data that validate the user's stance
- Fact-check the Advocate's attacks — find where they're wrong or exaggerated
- Search for rebuttals to the specific arguments the Advocate raised"
      RESEARCH_FOCUS_SYNTH="- Verify key claims from both the attacks and the defense
- Check if cited sources actually support the claims made
- If a claim lacks a source, search to confirm or refute it"
      ;;
  esac

  if [[ "$NEXT_PHASE" == "advocate" ]]; then
    RESEARCH_BLOCK="
## Research Mode ENABLED

Before constructing your argument, use **WebSearch** to research the topic. Ground your claims in real evidence:
$RESEARCH_FOCUS_ADVOCATE
- Cite your sources inline: [Source Title](URL)
- PREFER researched evidence with real URLs over claims from memory

Perform at least 2-3 targeted searches. Respond to the Critic's points from the previous round with researched counter-evidence where possible.

If WebSearch is unavailable, proceed without research and note that evidence is based on training data only."
  elif [[ "$NEXT_PHASE" == "critic" ]]; then
    RESEARCH_BLOCK="
## Research Mode ENABLED

Before constructing your critique, use **WebSearch** to research counter-evidence. Ground your critique in real evidence:
$RESEARCH_FOCUS_CRITIC
- Cite your sources inline: [Source Title](URL)
- PREFER researched evidence with real URLs over claims from memory

Perform at least 2-3 targeted searches. If the Advocate cited sources, verify their accuracy.

If WebSearch is unavailable, proceed without research and note that evidence is based on training data only."
  elif [[ "$NEXT_PHASE" == "synthesizer" ]]; then
    RESEARCH_BLOCK="
## Research Mode ENABLED

Before synthesizing, use **WebSearch** to VERIFY claims from both sides. You are NOT introducing new arguments — you are fact-checking the debate:
$RESEARCH_FOCUS_SYNTH
- Cite your verification sources inline: [Source Title](URL)

Perform 1-2 targeted verification searches. In your synthesis, explicitly note which evidence held up under scrutiny and which didn't. Do NOT add new perspectives — only assess what was already argued.

If WebSearch is unavailable, proceed without research and note that claims could not be independently verified."
  fi
fi

# Build the full prompt
FULL_PROMPT="$MODE_PROMPT

$ROLE_PROMPT"

if [[ -n "$FRAMEWORK_PROMPT" ]]; then
  FULL_PROMPT="$FULL_PROMPT

$FRAMEWORK_PROMPT"
fi

# Inject focus lens for advocate and critic phases
if [[ -n "$FOCUS" ]] && [[ "$NEXT_PHASE" != "synthesizer" ]]; then
  FOCUS_DESCRIPTION=""
  case "$FOCUS" in
    security)
      FOCUS_DESCRIPTION="Attack surface, vulnerabilities, compliance, data exposure, authentication/authorization, supply chain risks." ;;
    performance)
      FOCUS_DESCRIPTION="Latency, throughput, resource consumption, scalability limits, bottlenecks, caching implications." ;;
    developer-experience)
      FOCUS_DESCRIPTION="Learning curve, tooling ecosystem, debugging experience, documentation quality, onboarding time, API ergonomics." ;;
    operational-cost)
      FOCUS_DESCRIPTION="Infrastructure costs, maintenance burden, licensing, required team size, hidden operational overhead." ;;
    maintainability)
      FOCUS_DESCRIPTION="Code complexity, coupling, testability, upgrade path, technical debt trajectory, bus factor." ;;
    *)
      FOCUS_DESCRIPTION="" ;;
  esac

  FULL_PROMPT="$FULL_PROMPT

## Focus Lens: $FOCUS

CONSTRAIN your argument to this evaluation dimension. Do not address other dimensions unless they directly intersect with this focus."

  if [[ -n "$FOCUS_DESCRIPTION" ]]; then
    FULL_PROMPT="$FULL_PROMPT
Evaluate through: $FOCUS_DESCRIPTION"
  else
    FULL_PROMPT="$FULL_PROMPT
Evaluate exclusively through the lens of: **$FOCUS**"
  fi
fi

# Inject steering directive from interactive mode
if [[ -n "$STEERING_BLOCK" ]]; then
  FULL_PROMPT="$FULL_PROMPT
$STEERING_BLOCK"
fi

# Inject versus framing for advocate and critic
if [[ "$VERSUS" == "true" ]] && [[ "$NEXT_PHASE" != "synthesizer" ]]; then
  if [[ "$NEXT_PHASE" == "advocate" ]]; then
    FULL_PROMPT="$FULL_PROMPT

## VERSUS MODE

You are defending **Position A**. Argue why Position A's analysis and conclusions are stronger than Position B's. Reference specific arguments from both positions."
  elif [[ "$NEXT_PHASE" == "critic" ]]; then
    FULL_PROMPT="$FULL_PROMPT

## VERSUS MODE

You are defending **Position B**. Argue why Position B's analysis and conclusions are stronger than Position A's. Reference specific arguments from both positions."
  fi
fi

FULL_PROMPT="$FULL_PROMPT
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
