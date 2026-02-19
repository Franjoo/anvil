# ADR-004: Web Research Integration

## Status

Accepted

## Context

Anvil's debate phases (Advocate, Critic, Synthesizer) originally argued solely from Claude's training data. This limits the quality of arguments — especially for current events, specific benchmarks, real case studies, and fact-checking competing claims.

Claude Code sessions have access to `WebSearch` and `WebFetch` tools when the user's permissions allow it. Since the stop hook injects prompts into the same session, the debate phases can leverage these tools if instructed to do so.

Three approaches were considered:

1. **Always-on research** — Every debate phase automatically performs web searches. Adds significant latency to every debate. Many debates (philosophical, hypothetical) don't benefit from web research.

2. **Per-mode defaults** — Analyst mode defaults to research-on, philosopher defaults to research-off. Too opinionated; removes user control.

3. **Opt-in `--research` flag** — User explicitly enables research when they want evidence-grounded debates. Simple, predictable, user-controlled.

## Decision

Opt-in research via the `--research` flag. When enabled:

- **Advocate** receives instructions to search for supporting evidence (data, case studies, success stories)
- **Critic** receives instructions to search for counter-evidence (failure cases, contradictions, fact-checks)
- **Synthesizer** receives instructions to fact-check the strongest claims from both sides

Research instructions are NOT embedded in the static prompt files (`prompts/*.md`). Instead, the stop hook (`hooks/stop-hook.sh`) and setup script (`scripts/setup-anvil.sh`) conditionally inject a `## Research Mode ENABLED` block into the prompt when `research: true` is set in the state file.

Each phase gets role-appropriate research instructions:
- Advocates search for evidence that supports their position
- Critics search for evidence that contradicts the Advocate's claims
- Synthesizers verify key claims from both sides

## Consequences

**Positive:**
- User controls whether research happens — no surprise latency
- Research instructions are role-appropriate (advocate searches for support, critic for counter-evidence)
- Clean separation: prompt files stay focused on role behavior; research is an overlay
- State file tracks the research flag, so the stop hook knows to inject instructions
- Works with any mode (analyst, philosopher, devils-advocate)

**Negative:**
- Adds latency when enabled (2-3 web searches per phase)
- Quality of research depends on Claude's search query formulation
- Web search results may introduce noise or irrelevant information
- No mechanism to verify that research was actually performed (Claude might skip searches)
