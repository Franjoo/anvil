# ADR-007: Persona Architecture

## Status

Accepted

## Context

Custom personas (`--persona`) replace generic Advocate/Critic with named characters that have specific worldviews. Persona descriptions can be multi-line markdown (for presets) or short free-text strings (for custom personas). They must persist across phases and be accessible to the stop hook. Three storage approaches were considered:

1. **Frontmatter storage** — Store persona descriptions in YAML frontmatter. Problem: multi-line markdown with special characters breaks YAML parsing. Even with escaping, the frontmatter becomes unwieldy.

2. **External files** — Write persona descriptions to temporary files, reference paths in frontmatter. Problem: adds file management complexity, temp files can be cleaned up by the system, and paths must be absolute.

3. **HTML comment markers in state file body** — Store persona descriptions as `<!-- persona:NAME -->...<!-- /persona -->` blocks in the state file body. The stop hook extracts them with `awk` using `index()` for literal string matching. Persona names are stored pipe-separated in frontmatter for enumeration.

## Decision

HTML comment markers (option 3). Persona descriptions are written to the state file body during setup, wrapped in comment markers. The frontmatter stores only the pipe-separated names (`personas: "security-engineer|startup-cfo"`). The stop hook extracts descriptions on demand via:

```awk
index($0, "<!-- persona:NAME -->") > 0 { found=1; next }
/<!-- \/persona -->/ { if(found) exit }
found { print }
```

Using `index()` instead of `~` avoids regex metacharacter issues with free-text persona names.

Two operating modes based on persona count:
- **2 personas**: Standard advocate/critic alternation. Persona 1 = Advocate role, Persona 2 = Critic role. Uses existing state machine.
- **3+ personas**: Rotation mode with dedicated `persona` phase. Each persona gets one round, then synthesizer. Similar to stakeholder mode.

Presets live in `prompts/personas/*.md` and are resolved at setup time — the stop hook only sees the resolved descriptions.

## Consequences

**Positive:**
- No YAML escaping issues — descriptions live outside frontmatter
- Descriptions flow through transcript extraction naturally
- Preset resolution happens once at setup — stop hook is preset-agnostic
- 2-persona mode reuses existing advocate/critic state machine with zero changes
- `index()` matching is safe for any persona name content

**Negative:**
- HTML comment markers are unconventional for state storage — not immediately obvious to someone reading the state file
- Persona names in frontmatter are pipe-separated (not standard YAML list syntax)
- `--persona` is mutually exclusive with `--mode` — no way to combine personas with philosopher tone, for example
- 3+ persona rotation mode cannot use `--interactive` (no critic phase to pause after)
