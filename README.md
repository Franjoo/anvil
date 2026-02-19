<p align="center">
  <img src="assets/icon.png" alt="Anvil" width="128" height="128">
</p>

<h1 align="center">Anvil</h1>

<p align="center">Adversarial thinking plugin for <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>. Stress-test ideas through structured debates.</p>

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

### Options

```
/anvil:anvil "question" [--mode analyst|philosopher|devils-advocate] [--rounds N] [--position "TEXT"] [--research]
```

| Option | Default | Description |
|---|---|---|
| `--mode` | `analyst` | Debate style (see modes below) |
| `--rounds` | `3` | Number of advocate/critic rounds (1-5) |
| `--position` | — | Your stance (required for `devils-advocate` mode) |
| `--research` | off | Enable web research for evidence-grounded arguments |

> **Tip:** With `--research`, each phase performs 2-3 web searches, increasing latency but grounding arguments in real evidence. For deep research debates, consider using fewer rounds (`--rounds 2 --research`) to manage context window usage.

### Check status

```
/anvil:anvil-status
```

### Cancel active debate

```
/anvil:anvil-cancel
```

## Modes

### Analyst (default)

Evidence-based technical analysis. Advocate argues FOR with data and benchmarks. Critic dismantles with counter-evidence. Best for tech decisions and strategy.

```
/anvil:anvil "Should we migrate to Kubernetes?" --mode analyst
```

### Philosopher

Socratic exploration using first-principles reasoning. Thought experiments, ethical frameworks, definitional precision. Best for ethics, thought experiments, and fundamental questions.

```
/anvil:anvil "Is AI-generated code really 'your' code?" --mode philosopher
```

### With Research

Enable `--research` to ground arguments in real-time web searches. Each phase performs targeted research: Advocate searches for supporting evidence, Critic for counter-evidence, Synthesizer fact-checks both.

```
/anvil:anvil "Should we adopt Rust for our backend services?" --mode analyst --research
```

### Devil's Advocate

**Roles are reversed.** Advocate attacks YOUR stated position. Critic defends it and finds weaknesses in the attacks. Best for stress-testing beliefs you already hold.

```
/anvil:anvil "monolith vs microservices" --mode devils-advocate --position "I believe we should stay with our monolith because our team is small"
```

## How It Works

Anvil uses Claude Code's [stop hook](https://docs.anthropic.com/en/docs/claude-code/hooks) mechanism to orchestrate a multi-phase debate within a single session.

### Debate Flow

```
/anvil:anvil "question"
  │
  ├─ setup-anvil.sh creates state file + outputs ADVOCATE prompt
  │
  ├─ Claude argues FOR (Advocate phase)
  │   └─ Stop hook fires → appends output → switches to CRITIC
  │
  ├─ Claude argues AGAINST (Critic phase)
  │   └─ Stop hook fires → round < max → switches to ADVOCATE R2
  │
  ├─ [Repeats for configured rounds]
  │   └─ Stop hook fires → round limit → switches to SYNTHESIZER
  │
  ├─ Claude produces balanced analysis (Synthesizer phase)
  │   └─ Stop hook fires → writes result → allows exit
  │
  └─ Result saved to .claude/anvil-result.local.md
```

### State Machine

```
advocate(R1) → critic(R1) → advocate(R2) → critic(R2) → ... → synthesizer → DONE
```

### State File

Debate state lives in `.claude/anvil-state.local.md` — YAML frontmatter for metadata, markdown body for the accumulating transcript. Human-readable, inspectable at any time.

### Result File

When synthesis completes, the final analysis is written to `.claude/anvil-result.local.md` with the question, mode, round count, and the synthesizer's output.

## Architecture

```
anvil/
├── .claude-plugin/plugin.json    # Plugin manifest
├── commands/
│   ├── anvil.md                  # /anvil:anvil command
│   ├── anvil-status.md           # /anvil:anvil-status command
│   └── anvil-cancel.md           # /anvil:anvil-cancel command
├── hooks/
│   ├── hooks.json                # Stop hook registration
│   └── stop-hook.sh              # Core orchestrator (state machine)
├── scripts/
│   └── setup-anvil.sh            # Argument parsing + state initialization
├── prompts/
│   ├── advocate.md               # Advocate role instructions
│   ├── critic.md                 # Critic role instructions
│   ├── synthesizer.md            # Synthesizer role instructions
│   └── modes/
│       ├── analyst.md            # Analyst mode tone
│       ├── philosopher.md        # Philosopher mode tone
│       └── devils-advocate.md    # Devil's advocate mode (reversed roles)
└── docs/adr/                     # Architecture Decision Records
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
