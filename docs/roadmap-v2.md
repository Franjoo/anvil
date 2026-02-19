# Anvil v2 Roadmap

## Vision

Anvil v1 proves the core concept: structured opposition produces better thinking. v2 amplifies this by making debates **context-aware**, **framework-driven**, and **interactive** — turning Anvil from a thinking exercise into an indispensable decision-making tool.

## Features

### 1. Decision Frameworks (`--framework`)

**Priority: 1 — High impact, low effort**

The Synthesizer currently outputs free-form analysis. Many decisions have established formats that teams already use. Frameworks give Anvil structured, actionable output.

```
/anvil:anvil "Should we migrate to Postgres?" --framework adr
/anvil:anvil "Launch in EU market?" --framework pre-mortem
/anvil:anvil "New auth architecture" --framework rfc
```

| Framework | Output format | Best for |
|---|---|---|
| `adr` | Architecture Decision Record (context, decision, consequences) | Technical architecture decisions |
| `pre-mortem` | "It's 6 months later and this failed. Why?" — reverse-engineered failure modes | Risk assessment, launch decisions |
| `red-team` | Threat model with attack vectors, severity, mitigations | Security decisions, system design |
| `rfc` | Request for Comments (problem, proposed solution, alternatives considered) | Team-wide proposals |
| `risks` | Pure risk register: risk, likelihood, impact, mitigation | Compliance, project planning |

**Implementation:** New `prompts/frameworks/` directory with synthesizer output templates. The `--framework` flag selects which template the Synthesizer uses. Advocate and Critic phases are unaffected — only the Synthesizer's output structure changes.

**Combinable:** `--framework` works with any `--mode`. E.g., `--mode philosopher --framework pre-mortem` gives Socratic exploration with a pre-mortem synthesis.

---

### 2. Code-Aware Debates (`--context`)

**Priority: 2 — Very high impact, medium effort**

The single biggest differentiator. Anvil runs inside Claude Code — it has access to the codebase. This is currently unused. With `--context`, debates are grounded in actual project code.

```
/anvil:anvil "Should we refactor auth to JWT?" --context src/auth/
/anvil:anvil "Is this PR ready to merge?" --context --pr 42
/anvil:anvil "Are these changes safe?" --context --diff
```

| Variant | What it reads | Use case |
|---|---|---|
| `--context path/` | Files in directory (overview + key symbols) | Architecture debates |
| `--context file.ts` | Specific file(s) | Focused code decisions |
| `--context --pr N` | PR diff via `gh pr diff N` | PR review debates |
| `--context --diff` | Current uncommitted changes | Pre-commit sanity check |

**Implementation:** `setup-anvil.sh` reads the context source and appends a `## Codebase Context` section to the initial prompt. For directories, it generates a file tree + symbol overview (not full file contents — that would blow the context window). For PRs/diffs, it includes the diff output.

**Key constraint:** Context must be concise. A full directory dump would consume too much of the context window and leave no room for the actual debate. The setup script should generate a **summary** — file tree, key types/interfaces, function signatures — not dump raw source.

---

### 3. Focus Lens (`--focus`)

**Priority: 3 — High impact, low effort**

Narrows the debate to a specific evaluation dimension. Both sides argue through the same lens.

```
/anvil:anvil "Should we adopt GraphQL?" --focus security
/anvil:anvil "Should we adopt GraphQL?" --focus developer-experience
/anvil:anvil "Should we adopt GraphQL?" --focus operational-cost
```

| Focus | Debate emphasis |
|---|---|
| `security` | Attack surface, vulnerabilities, compliance, data exposure |
| `performance` | Latency, throughput, resource consumption, scalability |
| `developer-experience` | Learning curve, tooling, debugging, onboarding |
| `operational-cost` | Infrastructure, maintenance, licensing, team size |
| `maintainability` | Complexity, coupling, testability, upgrade path |

**Implementation:** A `--focus` flag adds a "Focus Lens" section to both Advocate and Critic prompts, constraining their arguments to the specified dimension. Custom focus values are also allowed — the prompt simply says "Evaluate exclusively through the lens of: [user value]".

**Combinable:** Works with `--mode`, `--framework`, and `--research`. E.g., `--mode analyst --focus security --framework red-team --research` = security-focused analyst debate with web research, output as threat model.

---

### 4. Interactive Mode (`--interactive`)

**Priority: 4 — High impact, medium effort**

The user can intervene between rounds to steer the debate.

```
/anvil:anvil "Monolith vs. Microservices" --interactive
```

After each Advocate/Critic round, instead of automatically proceeding, Anvil pauses and asks:

> **Round 1 complete.** The Advocate argued X. The Critic countered Y.
>
> Steer the next round? (Leave empty to continue automatically)
> - "Focus on team size constraints"
> - "The Critic ignored our 99.9% uptime SLA"
> - "Explore the migration cost angle"

User input is prepended to the next phase's prompt as a directive.

**Implementation:** The stop hook checks for `interactive: true` in state. Instead of immediately blocking with the next prompt, it outputs a summary and a user prompt. The user's response is captured and injected as steering context. This likely requires a different hook flow — possibly using the `reason` field to ask a question rather than give a directive.

**Challenge:** This changes the UX model from "fire and forget" to "guided conversation." Needs careful design to not feel clunky.

---

### 5. Stakeholder Simulation (`--mode stakeholders`)

**Priority: 5 — High impact, medium effort**

A new mode where instead of Advocate/Critic, each round represents a different stakeholder perspective.

```
/anvil:anvil "We want to rewrite the frontend in Svelte" --mode stakeholders
```

Default stakeholder rotation:
- Round 1: Engineering Team perspective
- Round 2: Product/UX perspective
- Round 3: Business/Management perspective
- Synthesis: Where is there alignment? Where conflict? What did no stakeholder consider?

**Customizable:** `--stakeholders "security,legal,end-user"` to define custom stakeholder perspectives.

**Implementation:** New mode prompt in `prompts/modes/stakeholders.md`. The stop hook maps round numbers to stakeholder roles instead of alternating advocate/critic. Each "round" is a single stakeholder analysis, not an advocate+critic pair.

**State machine change:** Instead of `advocate → critic → advocate → critic → synthesizer`, it becomes `stakeholder-1 → stakeholder-2 → stakeholder-3 → synthesizer`. This requires a modified phase transition in the stop hook.

---

### 6. Debate Chains (`--follow-up`, `--versus`)

**Priority: 6 — Medium impact, low effort**

Debates don't exist in isolation. Real decisions are iterative.

**Follow-up:** Continue from a previous debate's conclusion:
```
/anvil:anvil "What about the cost implications?" --follow-up .claude/anvil-result.local.md
```
The previous result is injected as context. The new debate builds on established conclusions rather than starting from scratch.

**Versus:** Pit two previous results against each other:
```
/anvil:anvil --versus result-microservices.md result-monolith.md
```
Advocate argues for Result A, Critic argues for Result B, Synthesizer determines which conclusion is stronger.

**Implementation:** `--follow-up` reads the file and prepends it as "Prior Analysis" context. `--versus` is essentially a new mode where the two results become the positions for advocate and critic.

---

### 7. Custom Personas (`--persona`)

**Priority: 7 — Medium impact, medium effort**

Replace generic Advocate/Critic with named personas that have specific worldviews, priorities, and expertise.

```
/anvil:anvil "Should we add AI features?" \
  --persona "skeptical CTO who's been burned by hype" \
  --persona "product manager obsessed with user retention"
```

**Presets available:**
- `--persona security-engineer`
- `--persona startup-cfo`
- `--persona junior-developer`
- `--persona end-user`

**Custom personas:** Free-text descriptions become the persona's system prompt.

**Implementation:** Personas replace the Advocate/Critic role prompts entirely. Each persona argues from their perspective rather than a generic for/against stance. With two personas, Round 1 = Persona A, Round 2 = Persona B, alternating. With 3+ personas, each gets one round.

**Design question:** How do personas interact with modes? Probably `--persona` and `--mode` are mutually exclusive — personas ARE the mode.

---

### 8. Confidence Calibration

**Priority: 8 — Medium impact, low effort**

Improve the Synthesizer's confidence assessment from subjective gut feeling to evidence-based calibration.

**Current:** Confidence is `high/medium/low` based on the Synthesizer's judgment.

**Improved:** Confidence is derived from debate dynamics:
- Arguments that survived multiple rounds of critique → high weight
- Arguments the opponent couldn't counter → strong signal
- Points both sides independently raised → very high confidence
- Arguments that were dismantled → low weight, noted as "fell"

**Implementation:** Update `prompts/synthesizer.md` with explicit calibration instructions. Add a "Confidence Methodology" section that forces the Synthesizer to show its work — which arguments survived, which fell, and how that maps to the final confidence rating.

---

## Combinability Matrix

Features are designed to compose freely:

| | `--mode` | `--framework` | `--focus` | `--research` | `--context` | `--interactive` | `--follow-up` |
|---|---|---|---|---|---|---|---|
| `--mode` | — | Yes | Yes | Yes | Yes | Yes | Yes |
| `--framework` | Yes | — | Yes | Yes | Yes | Yes | Yes |
| `--focus` | Yes | Yes | — | Yes | Yes | Yes | Yes |
| `--research` | Yes | Yes | Yes | — | Yes | Yes | Yes |
| `--context` | Yes | Yes | Yes | Yes | — | Yes | Yes |
| `--interactive` | Yes | Yes | Yes | Yes | Yes | — | Yes |
| `--follow-up` | Yes | Yes | Yes | Yes | Yes | Yes | — |

Exception: `--persona` replaces `--mode` (mutually exclusive).

## Power Combos

```bash
# Security review of a PR with web research, output as threat model
/anvil:anvil "Is this PR safe to merge?" --context --pr 42 --focus security --framework red-team --research

# Pre-mortem on a launch decision, grounded in codebase
/anvil:anvil "Should we launch v2 next week?" --context src/ --framework pre-mortem --mode analyst

# Interactive philosophical exploration with follow-up
/anvil:anvil "Is our AI feature ethical?" --mode philosopher --interactive
# ... then later ...
/anvil:anvil "How do we address the consent issue?" --follow-up .claude/anvil-result.local.md

# Stakeholder simulation with custom perspectives
/anvil:anvil "Rewrite backend in Rust" --mode stakeholders --stakeholders "engineering,security,cfo"
```
