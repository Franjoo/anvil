# ADR-006: Interactive Steering via Meta-Phase

## Status

Accepted

## Context

Interactive mode (`--interactive`) lets users steer the debate between rounds. The challenge is capturing user input mid-debate when the stop hook only controls phase transitions. Three approaches were considered:

1. **In-band signaling** — Use a special comment syntax in the Critic's output to encode user feedback. Problem: unreliable — Claude may not produce the exact format, and parsing natural language for steering intent is fragile.

2. **Separate hook** — Use a different hook type (e.g., pre-tool) to intercept between phases. Problem: no suitable hook point exists between stop-hook invocations.

3. **Meta-phase insertion** — Introduce `interactive-pause` as a dedicated phase in the state machine. After the Critic phase, instead of transitioning to Advocate, transition to `interactive-pause`. This phase instructs Claude to summarize the round and use `AskUserQuestion` to get steering input. The response is parsed for an `<anvil-steering>` tag, and the extracted direction is injected into the next Advocate prompt.

## Decision

Meta-phase insertion (option 3). The state machine gains a new transition:

```
critic → interactive-pause → advocate (with steering)
```

The `interactive-pause` phase:
- Does NOT append its output to the debate transcript (it's meta-conversation)
- Instructs Claude to summarize the round and present options via `AskUserQuestion`
- Parses `<anvil-steering>...</anvil-steering>` tags from the output
- Supports "synthesize" / "skip" as steering values to end the debate early

Steering input is injected as a "User Steering Directive" block in the next Advocate prompt.

## Consequences

**Positive:**
- Clean separation of meta-conversation (steering) from debate content (transcript)
- Uses existing Claude Code tool (`AskUserQuestion`) for user interaction — native UX
- Early termination ("skip to synthesis") falls out naturally from the steering mechanism
- No changes to transcript format or extraction logic

**Negative:**
- Adds complexity to the state machine (new phase type, new transitions)
- The `<anvil-steering>` tag parsing is fragile — relies on Claude producing the exact format
- Interactive-pause output is discarded, so steering rationale is lost
- Not compatible with 3+ persona rotation mode (no critic phase to pause after)
