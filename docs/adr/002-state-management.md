# ADR-002: State Management — Markdown with YAML Frontmatter

## Status

Accepted

## Context

Anvil needs to persist debate state between stop hook invocations. The state includes: active flag,
question, mode, current phase, round number, max rounds, and the accumulated debate transcript.
Options considered:

1. **JSON file** — Machine-readable but not human-friendly. Harder to inspect/debug. Appending
   transcript sections is awkward in JSON.

2. **SQLite** — Overkill for single-debate state. Adds a dependency. Not readable without tooling.

3. **Markdown with YAML frontmatter** — Structured metadata (phase, round, mode) in YAML
   frontmatter. Debate transcript in the markdown body, organized by round and phase headings.
   Human-readable, consistent with Ralph Loop's approach.

## Decision

Markdown with YAML frontmatter, stored at `.claude/anvil-state.local.md`.

The `.local.md` suffix follows Claude Code convention for gitignored local state files. The YAML
frontmatter contains machine-parseable fields (active, question, mode, phase, round, max_rounds,
started_at). The markdown body accumulates the debate transcript under structured headings
(`## Round N` / `### Advocate` / `### Critic` / `## Synthesis`).

The stop hook uses `sed` to parse frontmatter and `awk` to extract/append transcript content — no
external dependencies beyond standard Unix tools.

## Consequences

**Positive:**

- Human-readable: users can inspect debate progress by reading the file
- Simple parsing: sed/awk for frontmatter, string concatenation for transcript
- Consistent with Ralph Loop conventions (same file location pattern, same frontmatter approach)
- The transcript section serves as both state AND a useful artifact

**Negative:**

- YAML frontmatter parsing with sed is fragile for complex values (e.g., multi-line questions)
- File grows with each phase — very long debates could produce large files
- No atomic transactions — corruption possible if hook crashes mid-write (mitigated by temp file +
  mv pattern)
