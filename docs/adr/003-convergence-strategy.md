# ADR-003: Convergence — Hard Round Limit

## Status

Accepted

## Context

Anvil needs a strategy for when to stop debating and move to synthesis. Three approaches were considered:

1. **Fixed round limit** — User specifies number of advocate/critic rounds (default 3, max 5). Simple, predictable, user-controlled. Research on multi-agent debate systems shows gains saturate after 2-3 critique rounds.

2. **LLM meta-evaluation** — A separate LLM call evaluates whether the debate has converged (no new arguments being raised). Adds complexity, latency, and cost. Risk of premature termination.

3. **Heuristic detection** — Analyze argument overlap, sentiment patterns, or response length trends to detect convergence. Complex to implement, brittle, language-dependent.

## Decision

Hard round limit as the primary convergence mechanism. Default is 3 rounds, maximum is 5, configurable via `--rounds N`.

As a secondary signal (optional, not relied upon): if an advocate or critic outputs `<anvil-complete/>`, this is treated as a natural endpoint and the debate moves to synthesis early. The stop hook checks for this tag before enforcing the round limit.

v2 retained this approach unchanged. The `<anvil-complete/>` signal was extended to work with stakeholder and persona rotation modes, but the core convergence strategy (hard round limit + optional early exit) proved sufficient and was not replaced with more sophisticated detection.

## Consequences

**Positive:**
- Simple and predictable — users know exactly how many rounds will occur
- No additional LLM calls or complex analysis needed
- User-controlled: `--rounds 1` for quick assessment, `--rounds 5` for deep analysis
- Aligns with research showing diminishing returns after 2-3 rounds

**Negative:**
- May stop too early for complex topics where genuine new arguments emerge in later rounds
- May stop too late for simple topics resolved in one exchange
- No intelligence about actual debate quality — purely mechanical
