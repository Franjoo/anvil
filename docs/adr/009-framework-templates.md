# ADR-009: Framework Templates

## Status

Accepted

## Context

Decision frameworks (`--framework`) structure the Synthesizer's output into established formats (ADR, pre-mortem, risk register, etc.). The framework must override the Synthesizer's default free-form output without affecting Advocate or Critic phases. Two approaches were considered:

1. **Inline in synthesizer prompt** — Embed all framework templates directly in the synthesizer role prompt with conditional logic. Problem: the synthesizer prompt becomes enormous and hard to maintain. Adding a new framework means editing the core prompt.

2. **Separate template files** — Each framework is a standalone markdown file in `prompts/frameworks/`. The stop hook loads the relevant template only during the synthesizer phase and injects it as an additional prompt block.

## Decision

Separate template files (option 2). Framework templates live in `prompts/frameworks/{name}.md`. Each template:
- Opens with `**OVERRIDE the default Synthesizer output format.**`
- Defines the exact output structure (headings, tables, sections)
- Includes guidance on how to map debate arguments to the framework's categories

The stop hook loads the template only when `NEXT_PHASE == "synthesizer" && FRAMEWORK != ""` and appends it to the full prompt after the mode and role prompts. Advocate and Critic phases never see framework content — they argue freely.

Available frameworks: `adr`, `pre-mortem`, `red-team`, `rfc`, `risks`.

## Consequences

**Positive:**
- Adding a new framework is a single markdown file — no code changes needed
- Templates are human-readable and editable by non-developers
- Advocate/Critic phases are unaffected — framework is synthesis-only
- Templates follow the same pattern as mode and role prompts — consistent architecture

**Negative:**
- Framework templates must be self-contained — they can't reference debate-specific content dynamically
- No validation that the Synthesizer actually follows the template format (it's a prompt instruction, not enforced)
- Templates are loaded by filename convention — a typo in `--framework` produces a silent empty prompt rather than a clear error (mitigated by validation in setup script)
