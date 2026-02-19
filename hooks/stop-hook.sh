#!/bin/bash

# Anvil Stop Hook — Adversarial Debate Orchestrator
# Rotates through Advocate → Critic → Synthesizer phases
# Each phase gets a distinct role prompt with full debate context

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if anvil debate is active
ANVIL_STATE_FILE=".claude/anvil-state.local.md"

if [[ ! -f "$ANVIL_STATE_FILE" ]]; then
  exit 0
fi

# TODO: Implement full state machine in Phase 2
# For now, just allow exit
exit 0
