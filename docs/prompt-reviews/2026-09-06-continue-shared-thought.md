# Prompt/capability review: continue the shared thought

Observed on 2026-09-06 using the project's local timezone, `America/New_York`.
This is a capability decision record from the user's reasoning-style proposal,
not a vendor prompt import.

| Field | Value |
|---|---|
| Source | User-proposed conversational generativity rule |
| Runtime files changed | `base.md` and the derived live base |
| Main role changed | no |
| Source patch changed | no |
| Review scope | shared conversation state and implication surfacing |

## Decision

Adopt a narrow positive conversation rule: answer the current question, then
notice what that answer changes, clarifies, or makes newly important. Surface a
material implication or direction when the conversation itself produces one.

The rule is intentionally not a requirement to suggest a next task, ask a
follow-up question, summarize every answer, or end with an offer. It treats a
response as one move in a developing line of thought rather than a terminal
answer.

## Boundaries

This changes only the curated main-agent base. It does not change Boss Main,
Worker behavior, authorization, or the default workflow. It complements the
existing framing and unresolved-state rules by adding a positive continuation
habit without weakening their restraint.
