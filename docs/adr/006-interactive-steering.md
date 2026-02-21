# ADR-006: Interactive Steering via Meta-Phase

## Status

Accepted

## Context

Interactive mode (`--interactive`) lets users steer the debate between rounds. The challenge is
capturing user input mid-debate when the stop hook only controls phase transitions. Three approaches
were considered:

1. **Direct hook prompting** — Have the stop hook itself present a user-facing question (via the
   JSON `reason` field) and parse the response. Problem: the stop hook's JSON response blocks the
   session with a prompt — it cannot wait for a second user response before deciding the next phase.
   Hooks are fire-and-forget, not interactive.

2. **Two-step hook with state flag** — Set an `awaiting_steering: true` flag in state, let Claude's
   next output contain user input, then parse it on the subsequent stop-hook invocation. Problem:
   the user would need to type their steering into Claude's regular input, which conflates debate
   steering with normal session usage. No way to distinguish steering from unrelated messages.

3. **Meta-phase insertion** — Introduce `interactive-pause` as a dedicated phase in the state
   machine. After the Critic phase, instead of transitioning to Advocate, transition to
   `interactive-pause`. This phase instructs Claude to summarize the round and use `AskUserQuestion`
   to get steering input. The response is parsed for an `<anvil-steering>` tag, and the extracted
   direction is injected into the next Advocate prompt.

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
