#!/bin/bash

# Anvil Setup — Parse arguments, create state file, output initial prompt
# Called by the /anvil command via commands/anvil.md

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Defaults
MODE="analyst"
ROUNDS=3
POSITION=""
RESEARCH=false
QUESTION_PARTS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --mode requires a value (analyst, philosopher, devils-advocate)" >&2
        exit 1
      fi
      MODE="$2"
      shift 2
      ;;
    --rounds)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --rounds requires a number" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --rounds must be a positive integer (got: '$2')" >&2
        exit 1
      fi
      ROUNDS="$2"
      shift 2
      ;;
    --position)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --position requires a value" >&2
        exit 1
      fi
      POSITION="$2"
      shift 2
      ;;
    --research)
      RESEARCH=true
      shift
      ;;
    *)
      QUESTION_PARTS+=("$1")
      shift
      ;;
  esac
done

QUESTION="${QUESTION_PARTS[*]}"

# Validate question
if [[ -z "$QUESTION" ]]; then
  echo "Error: No question provided." >&2
  echo "" >&2
  echo "Usage: /anvil \"Should we use microservices?\" [--mode analyst] [--rounds 3]" >&2
  exit 1
fi

# Validate mode
case "$MODE" in
  analyst|philosopher|devils-advocate) ;;
  *)
    echo "Error: Invalid mode '$MODE'. Must be one of: analyst, philosopher, devils-advocate" >&2
    exit 1
    ;;
esac

# Validate rounds
if [[ "$ROUNDS" -lt 1 ]] || [[ "$ROUNDS" -gt 5 ]]; then
  echo "Error: --rounds must be between 1 and 5 (got: $ROUNDS)" >&2
  exit 1
fi

# Validate position for devils-advocate mode
if [[ "$MODE" == "devils-advocate" ]] && [[ -z "$POSITION" ]]; then
  echo "Error: --position is required for devils-advocate mode" >&2
  echo "" >&2
  echo "Usage: /anvil \"topic\" --mode devils-advocate --position \"I believe X because Y\"" >&2
  exit 1
fi

# Check for existing active debate
ANVIL_STATE_FILE=".claude/anvil-state.local.md"
if [[ -f "$ANVIL_STATE_FILE" ]]; then
  echo "Error: An Anvil debate is already active." >&2
  echo "Use /anvil-cancel to cancel it, or /anvil-status to check progress." >&2
  exit 1
fi

# Create .claude directory if needed
mkdir -p .claude

# Escape strings for YAML double-quoted values (backslash, then double-quote)
yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Format position for YAML (null if empty)
if [[ -n "$POSITION" ]]; then
  POSITION_YAML="\"$(yaml_escape "$POSITION")\""
else
  POSITION_YAML="null"
fi

# Escape question for YAML
QUESTION_YAML="\"$(yaml_escape "$QUESTION")\""

# Create state file
cat > "$ANVIL_STATE_FILE" <<EOF
---
active: true
question: $QUESTION_YAML
mode: $MODE
position: $POSITION_YAML
round: 1
max_rounds: $ROUNDS
phase: advocate
research: $RESEARCH
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---
EOF

# Read the initial advocate prompt
ADVOCATE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/advocate.md")
MODE_PROMPT=$(cat "$PLUGIN_ROOT/prompts/modes/${MODE}.md")

# Build the initial prompt
echo ""
echo "============================================================"
echo "  ANVIL — Adversarial Thinking"
echo "============================================================"
echo ""
echo "  Question:  $QUESTION"
echo "  Mode:      $MODE"
echo "  Rounds:    $ROUNDS"
if [[ -n "$POSITION" ]]; then
  echo "  Position:  $POSITION"
fi
if [[ "$RESEARCH" == "true" ]]; then
  echo "  Research:  ENABLED (WebSearch + WebFetch)"
fi
echo ""
echo "  Phase:     ADVOCATE (Round 1 of $ROUNDS)"
echo ""
echo "  The debate will cycle through:"
echo "    Advocate → Critic → ... → Synthesizer"
echo ""
echo "  When you finish each phase, the stop hook will"
echo "  automatically feed you the next role."
echo ""
echo "============================================================"
echo ""
echo "$MODE_PROMPT"
echo ""
echo "$ADVOCATE_PROMPT"
echo ""
echo "---"
echo ""
echo "**Question under debate:** $QUESTION"
if [[ -n "$POSITION" ]]; then
  echo ""
  echo "**User's stated position:** $POSITION"
fi
if [[ "$RESEARCH" == "true" ]]; then
  echo ""
  echo "## Research Mode ENABLED"
  echo ""
  echo "Before constructing your argument, use **WebSearch** to research the topic. Ground your claims in real evidence:"
  case "$MODE" in
    analyst)
      echo "- Search for relevant data, studies, benchmarks, and case studies"
      echo "- Look for real-world examples that support your position"
      echo "- Find specific numbers, dates, and measurable outcomes — not vague generalities"
      ;;
    philosopher)
      echo "- Search for philosophical arguments, frameworks, and thinkers that support your position"
      echo "- Look for historical precedents and analogous ethical dilemmas"
      echo "- Find thought experiments or academic papers that illuminate your thesis"
      ;;
    devils-advocate)
      echo "- Search for evidence that UNDERMINES the user's stated position"
      echo "- Look for failure cases, risks, and overlooked consequences"
      echo "- Find real-world examples where similar positions turned out wrong"
      ;;
  esac
  echo "- Cite your sources inline: [Source Title](URL)"
  echo "- PREFER researched evidence with real URLs over claims from memory"
  echo ""
  echo "Perform at least 2-3 targeted searches before writing your argument. Quality of evidence matters more than quantity."
  echo ""
  echo "If WebSearch is unavailable in this session, proceed without research and note that evidence is based on training data only."
fi
echo ""
echo "This is Round 1. No prior debate context yet. Begin your argument."
