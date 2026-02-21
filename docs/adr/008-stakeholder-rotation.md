# ADR-008: Stakeholder Rotation

## Status

Accepted

## Context

Stakeholder simulation (`--mode stakeholders`) replaces adversarial Advocate/Critic with multiple
stakeholder perspectives. Each round is a different stakeholder analyzing the same question. Two
approaches were considered:

1. **Reuse advocate/critic with mode flag** — Keep the advocate/critic phase types but change the
   role prompt based on round number and mode. Problem: the transcript labels ("Advocate", "Critic")
   become misleading, the state machine's alternating pattern doesn't fit a linear rotation, and the
   interactive-pause logic (which triggers after critic) would fire at wrong points.

2. **Dedicated `stakeholder` phase type** — New phase in the state machine with simple linear
   rotation: `stakeholder(1) → stakeholder(2) → ... → synthesizer`. Each round maps to a stakeholder
   by index.

## Decision

Dedicated phase type (option 2). The state machine gains:

```
stakeholder(R1) → stakeholder(R2) → ... → stakeholder(RN) → synthesizer
```

Stakeholder names are stored comma-separated in frontmatter
(`stakeholders: "Engineering Team,Product/UX,Business/Management"`). Rounds auto-calculate from
stakeholder count. The mode-level instructions come from `prompts/modes/stakeholders.md`, which
defines the general stakeholder simulation behavior. The per-stakeholder role prompts are generated
inline with the stakeholder's name — there is no file per stakeholder.

The synthesizer in stakeholder mode gets a custom neutral mode prompt instead of the
`stakeholders.md` embodiment instructions, preventing the conflict of "embody a stakeholder" + "be a
neutral synthesizer."

## Consequences

**Positive:**

- Clean state machine — no overloading of advocate/critic semantics
- Transcript labels are accurate: "## Stakeholder 1: Engineering Team"
- Round count = stakeholder count, no configuration ambiguity
- Synthesizer correctly identifies as neutral arbiter, not a stakeholder
- Default stakeholders ("Engineering Team, Product/UX, Business/Management") provide good out-of-box
  experience

**Negative:**

- Adds a new phase type to the state machine, increasing branch complexity in the stop hook
- `--interactive` is not wired to stakeholder mode (no critic phase to pause after)
- Inline role prompts (not file-based) mean stakeholder instructions can't be customized via prompt
  files
- Early completion (`<anvil-complete/>`) required special handling to force the correct phase
  transition
