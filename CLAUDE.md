# Anvil — Adversarial Thinking Plugin

## What this is

A Claude Code plugin that enables adversarial thinking through structured debates. Uses stop hook orchestration to rotate through Advocate → Critic → Synthesizer phases, each with distinct role prompts.

## Architecture

- **No TypeScript runtime** — the plugin is shell scripts + markdown prompts
- `bun` is used as package manager only (scripts, formatting)
- The prompts in `prompts/` ARE the product
- Stop hook (`hooks/stop-hook.sh`) is the orchestrator — it manages the state machine
- State lives in `.claude/anvil-state.local.md` (YAML frontmatter + markdown transcript)

## Key files

- `hooks/stop-hook.sh` — Core state machine and prompt routing
- `scripts/setup-anvil.sh` — Argument parsing, validation, state file creation
- `prompts/{advocate,critic,synthesizer}.md` — Role-specific instructions
- `prompts/modes/{analyst,philosopher,devils-advocate}.md` — Mode-specific tone
- `commands/anvil.md` — Entry point command

## Conventions

- ADRs in `docs/adr/` for architectural decisions
- State file uses `.local.md` suffix (gitignored by Claude Code)
- All shell scripts use `set -euo pipefail`
- Frontmatter parsing with `sed`, transcript manipulation with `awk`
- Atomic file updates via temp file + `mv`
