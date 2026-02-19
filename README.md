<p align="center">
  <img src="assets/icon.png" alt="Anvil" width="128" height="128">
</p>

<h1 align="center">Anvil</h1>

<p align="center">Adversarial thinking plugin for <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>. Stress-test ideas through structured debates.</p>

<p align="center">
  <a href="https://github.com/Franjoo/anvil/releases"><img src="https://img.shields.io/github/v/release/Franjoo/anvil?style=flat-square" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Franjoo/anvil?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/Claude_Code-plugin-blueviolet?style=flat-square" alt="Claude Code Plugin">
  <img src="https://img.shields.io/badge/no_build-shell_%2B_markdown-green?style=flat-square" alt="No Build Step">
</p>

Anvil is a **thinking tool** that forces rigorous examination of propositions by rotating through Advocate, Critic, and Synthesizer phases — each with distinct role prompts that demand genuine adversarial positions. With `--research` enabled, arguments are grounded in real-time web research.

The name: an anvil is what you hammer arguments against to shape them.

## Installation

In Claude Code, run:

```
/plugin marketplace add Franjoo/anvil
/plugin install anvil@franjoo
```

That's it. No cloning needed. Auto-updates are supported via `/plugin marketplace update franjoo`.

### Local development

For local development or testing, use `--plugin-dir`:

```bash
git clone https://github.com/Franjoo/anvil.git
claude --plugin-dir ./anvil
```

## Usage

### Start a debate

```
/anvil:anvil "Should we use microservices for our e-commerce platform?"
```

### All options

```
/anvil:anvil "question" [options]
```

| Option | Default | Description |
|---|---|---|
| `--mode` | `analyst` | Debate style: `analyst`, `philosopher`, `devils-advocate`, `stakeholders` |
| `--rounds` | `3` | Number of advocate/critic rounds (1-5) |
| `--position` | — | Your stance (required for `devils-advocate` mode) |
| `--research` | off | Enable web research for evidence-grounded arguments |
| `--framework` | — | Output format for synthesis: `adr`, `pre-mortem`, `red-team`, `rfc`, `risks` |
| `--focus` | — | Narrow the debate lens: `security`, `performance`, `developer-experience`, `operational-cost`, `maintainability`, or custom text |
| `--context` | — | Inject code/file context (repeatable): file path or directory |
| `--pr` | — | Inject a GitHub PR as context (PR number) |
| `--diff` | — | Inject uncommitted changes as context |
| `--follow-up` | — | Build on a previous debate result (file path) |
| `--versus` | — | Pit two prior results against each other (two file paths) |
| `--interactive` | off | Pause between rounds for user steering |
| `--stakeholders` | — | Custom stakeholder list (comma-separated) |
| `--persona` | — | Named persona (repeatable, min 2). Preset or free-text |

### Check status / cancel

```
/anvil:anvil-status
/anvil:anvil-cancel
```

## Modes

### Analyst (default)

Evidence-based technical analysis. Advocate argues FOR with data and benchmarks. Critic dismantles with counter-evidence.

```
/anvil:anvil "Should we migrate to Kubernetes?" --mode analyst
```

### Philosopher

Socratic exploration using first-principles reasoning. Thought experiments, ethical frameworks, definitional precision.

```
/anvil:anvil "Is AI-generated code really 'your' code?" --mode philosopher
```

### Devil's Advocate

**Roles are reversed.** Advocate attacks YOUR stated position. Critic defends it. Best for stress-testing beliefs you already hold.

```
/anvil:anvil "monolith vs microservices" --mode devils-advocate --position "I believe we should stay with our monolith"
```

### Stakeholder Simulation

Each round represents a different stakeholder perspective instead of adversarial sides.

```
/anvil:anvil "We want to rewrite the frontend in Svelte" --mode stakeholders
/anvil:anvil "New pricing model" --stakeholders "engineering,sales,end-user,legal"
```

## Features

### Decision Frameworks

Structure the synthesis output into established decision formats.

```
/anvil:anvil "Should we adopt GraphQL?" --framework adr
/anvil:anvil "Launch the new pricing tier?" --framework pre-mortem
/anvil:anvil "Move to multi-tenant?" --framework risks
```

Available: `adr` (Architecture Decision Record), `pre-mortem`, `red-team` (threat model), `rfc`, `risks` (risk register).

### Focus Lens

Narrow the entire debate to a single evaluation dimension.

```
/anvil:anvil "Should we adopt Rust?" --focus security
/anvil:anvil "Move to microservices?" --focus operational-cost
/anvil:anvil "Switch to Svelte?" --focus "team onboarding speed"
```

Presets: `security`, `performance`, `developer-experience`, `operational-cost`, `maintainability`. Or pass any custom text.

### Code-Aware Debates

Inject real code, PRs, or diffs as context. Both sides argue with knowledge of the actual codebase.

```
/anvil:anvil "Is this auth implementation secure?" --context src/auth/
/anvil:anvil "Should we merge this?" --pr 42
/anvil:anvil "Are these changes ready?" --diff
```

### Debate Chains

Build on previous debates or pit two results against each other.

```
/anvil:anvil "Revisit with new data" --follow-up .claude/anvil-result.local.md
/anvil:anvil --versus result-a.md result-b.md
```

### Interactive Mode

Steer the debate between rounds. Refocus the argument, ask for deeper exploration, or skip to synthesis.

```
/anvil:anvil "Should we rewrite?" --interactive
```

### Custom Personas

Replace generic Advocate/Critic with named personas that have specific worldviews and expertise.

```
/anvil:anvil "Should we add AI features?" \
  --persona "skeptical CTO who's been burned by hype" \
  --persona "product manager obsessed with user retention"
```

Presets: `security-engineer`, `startup-cfo`, `junior-developer`, `end-user`. Or pass free-text descriptions.

With 3+ personas, each gets their own round (rotation mode):

```
/anvil:anvil "New API design" \
  --persona security-engineer \
  --persona junior-developer \
  --persona end-user
```

### Web Research

Enable `--research` to ground arguments in real-time web searches. Each phase performs targeted research: Advocate searches for supporting evidence, Critic for counter-evidence, Synthesizer fact-checks both.

```
/anvil:anvil "Should we adopt Rust for our backend?" --research
```

> **Tip:** Research increases latency but grounds arguments in real evidence. For deep research, consider fewer rounds (`--rounds 2 --research`).

### Combining Options

Options compose freely:

```
/anvil:anvil "Should we adopt gRPC?" \
  --mode analyst \
  --framework adr \
  --focus performance \
  --context src/api/ \
  --research \
  --interactive \
  --rounds 2
```

## How It Works

Anvil uses Claude Code's [stop hook](https://docs.anthropic.com/en/docs/claude-code/hooks) mechanism to orchestrate a multi-phase debate within a single session.

### Debate Flow

```
/anvil:anvil "question"
  |
  +- setup-anvil.sh creates state file + outputs first prompt
  |
  +- Claude argues (Advocate / Persona / Stakeholder phase)
  |   +- Stop hook fires -> appends output -> transitions phase
  |
  +- Claude argues (Critic / next Persona / next Stakeholder)
  |   +- Stop hook fires -> round check -> next phase or synthesizer
  |
  +- [Repeats for configured rounds]
  |
  +- Claude produces balanced analysis (Synthesizer phase)
  |   +- Stop hook fires -> writes result -> allows exit
  |
  +- Result saved to .claude/anvil-result.local.md
```

### State File

Debate state lives in `.claude/anvil-state.local.md` — YAML frontmatter for metadata, markdown body for the accumulating transcript. Human-readable, inspectable at any time.

## Architecture

```
anvil/
+-- .claude-plugin/plugin.json    # Plugin manifest
+-- commands/
|   +-- anvil.md                  # /anvil:anvil command
|   +-- anvil-status.md           # /anvil:anvil-status command
|   +-- anvil-cancel.md           # /anvil:anvil-cancel command
+-- hooks/
|   +-- hooks.json                # Stop hook registration
|   +-- stop-hook.sh              # Core orchestrator (state machine)
+-- scripts/
|   +-- setup-anvil.sh            # Argument parsing + state initialization
+-- prompts/
|   +-- advocate.md               # Advocate role instructions
|   +-- critic.md                 # Critic role instructions
|   +-- synthesizer.md            # Synthesizer role instructions
|   +-- modes/
|   |   +-- analyst.md            # Analyst mode tone
|   |   +-- philosopher.md        # Philosopher mode tone
|   |   +-- devils-advocate.md    # Devil's advocate mode
|   |   +-- stakeholders.md       # Stakeholder simulation mode
|   +-- frameworks/
|   |   +-- adr.md                # ADR output template
|   |   +-- pre-mortem.md         # Pre-mortem template
|   |   +-- red-team.md           # Red team / threat model template
|   |   +-- rfc.md                # RFC template
|   |   +-- risks.md              # Risk register template
|   +-- personas/
|       +-- security-engineer.md  # Security engineer persona
|       +-- startup-cfo.md        # Startup CFO persona
|       +-- junior-developer.md   # Junior developer persona
|       +-- end-user.md           # End user persona
+-- docs/adr/                     # Architecture Decision Records
```

No TypeScript, no build step. The prompts ARE the product. Shell scripts orchestrate, markdown prompts instruct.

## Design Decisions

See `docs/adr/` for detailed Architecture Decision Records:

- **ADR-001**: Stop hook orchestration (why not single prompt or subagents)
- **ADR-002**: Markdown + YAML frontmatter for state (why not JSON or SQLite)
- **ADR-003**: Hard round limit for convergence (why not LLM meta-evaluation)
- **ADR-004**: Web research integration (opt-in `--research` flag)

## License

MIT
