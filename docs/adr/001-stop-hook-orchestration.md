# ADR-001: Stop Hook Orchestration

## Status

Accepted

## Context

Anvil needs to orchestrate a multi-phase debate (Advocate → Critic → Synthesizer) within a single Claude Code session. Three approaches were considered:

1. **Single long prompt** — One prompt instructing Claude to play all roles sequentially. Problem: no enforcement of role separation, Claude tends to hedge and produce balanced output even in adversarial phases. No ability to inject context between phases.

2. **Stop hook phase rotation** — Use Claude Code's stop hook mechanism (same pattern as Ralph Loop plugin) to intercept session exit attempts and inject the next phase's prompt with full debate context. Each phase gets a distinct role prompt and the complete transcript so far.

3. **Background subagents** — Spawn separate agent instances for each role. Problem: agents don't share session context, transcript passing becomes complex, and the orchestration layer needs to be built from scratch.

## Decision

Stop hook phase rotation (option 2). The stop hook reads state from a markdown file with YAML frontmatter, determines the next phase via a state machine, constructs a role-specific prompt (combining mode + role + transcript context), and returns a JSON response that blocks exit and injects the new prompt.

The state machine follows this sequence:
```
advocate(R1) → critic(R1) → advocate(R2) → critic(R2) → ... → synthesizer → DONE
```

## Consequences

**Positive:**
- Proven pattern (Ralph Loop uses the same mechanism successfully)
- Each phase gets Claude's full context window dedicated to that role
- State management is simple shell + markdown — no dependencies
- Human-readable state file for debugging

**Negative:**
- Each phase appears as a "blocked stop attempt" in the session, which is slightly unusual UX
- Shell-based orchestration limits complexity of prompt assembly (string concatenation vs templating)
- Tightly coupled to Claude Code's hook API — if the API changes, the plugin breaks
