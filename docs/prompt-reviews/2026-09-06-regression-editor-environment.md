# Regression case: supporting evidence versus discriminating evidence

Observed on 2026-09-06 using the project's local timezone, `America/New_York`.
This is a natural-work regression case, not a synthetic benchmark.

## Case

### Context

The local editor page worked, the collection list worked, and a shell-detail
request returned HTTP 500 in the current target environment.

### Initial model conclusion

The model concluded that the current blocker was a backend/API or data-reading
problem rather than a local-page problem.

That explanation was plausible, but the evidence only established that this
request failed in this environment. It did not establish whether the backend,
the data, or the selected environment was the cause.

### Confirmation-oriented search

The model then checked the API client path, health endpoint, Vite defaults, and
the repository's `test.dev.hillresearch.ai` configuration. Those checks were
accurate, but they mostly showed that the current wiring was internally
consistent. They did not prove that `test.dev` was the correct environment for
the editor's real data.

### Missing discriminating evidence

The useful checks would have separated the remaining explanations, for example:

- whether the same real shell existed or worked in `ai.dev`;
- which environment the meeting or previous workflow actually identified;
- whether the collection and document were expected to exist in `test.dev`.

### Recovery

The question “could we be connected to the wrong backend?” caused the model to
retain both hypotheses:

1. the data or backend in `test.dev` is broken; or
2. `test.dev` is not the correct environment for this editor workflow.

The model then correctly distinguished repository default wiring from the
environment the task actually required.

## General lesson

Evidence that supports a working explanation is not necessarily evidence that
rules out the nearest material alternative. Prefer the smallest observable
distinction when the alternatives would change the next action.

This case should transfer to intended behavior, product contracts, tests that
pass, old documentation, API shapes, and other situations where “what exists”
can be mistaken for “what should govern this task.”
