# ADR-005: Context Injection Strategy

## Status

Accepted

## Context

Code-aware debates (`--context`, `--pr`, `--diff`) need to inject real codebase content into the debate. The content must be available to all phases (Advocate, Critic, Synthesizer) without re-fetching each round. Three approaches were considered:

1. **Re-fetch per phase** — Each phase independently reads the context source. Problem: PRs and diffs can change between phases, producing inconsistent context. Also requires the stop hook to shell out to `gh` and `git`, adding complexity and failure modes.

2. **Frontmatter storage** — Store context in YAML frontmatter. Problem: context can be multi-line code with special characters that break YAML parsing. Context can be up to 5000 characters — bloating frontmatter beyond its intended role as metadata.

3. **State file body injection** — Generate context once during setup, append it to the state file body before any round headings. All phases receive it naturally through transcript extraction (`awk` after second `---` delimiter).

## Decision

State file body injection (option 3). The setup script generates context at debate start, caps it at 5000 characters, and appends it to the state file body. For Round 1 (which is served by the setup script, not the stop hook), context is also output directly in the initial prompt. For all subsequent rounds, the stop hook's existing transcript extraction (`awk '/^---$/{i++; next} i>=2'`) picks it up from the state file automatically — no special handling needed in the hook.

Context generation is handled by four dedicated functions in `setup-anvil.sh`:
- `generate_dir_context()` — File tree + key declarations via grep heuristic
- `generate_file_context()` — File content with truncation at 150 lines
- `generate_pr_context()` — PR metadata + diff via `gh pr view` and `gh pr diff`
- `generate_diff_context()` — Staged and unstaged changes via `git diff`

## Consequences

**Positive:**
- Zero changes to the stop hook's core transcript extraction logic
- Context is immutable once set — all phases see the same snapshot
- Human-readable in the state file for debugging
- Context sources compose naturally (multiple `--context` flags, `--pr` + `--diff`)

**Negative:**
- 5000 character cap means large codebases get truncated — users must be selective with paths
- Context is duplicated in every phase's prompt (via transcript), consuming context window tokens
- No way to update context mid-debate (e.g., if a PR gets new commits)
