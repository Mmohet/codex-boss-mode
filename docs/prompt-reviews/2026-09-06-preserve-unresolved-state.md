# Prompt/capability review: preserve unresolved state

Observed on 2026-09-06 using the project's local timezone, `America/New_York`.
This is a capability decision record from the user's reasoning-style proposal,
not a vendor prompt import.

| Field | Value |
|---|---|
| Source | User-proposed general closure behavior |
| Runtime files changed | `base.md` and the derived live base |
| Main role changed | no |
| Source patch changed | no |
| Review scope | premature closure and state compression |

## Decision

Adopt the three-line rule:

> Do not compress unresolved state into a clean conclusion merely because one
> plausible explanation or subtask is complete.
>
> Keep material uncertainty open until resolving it would no longer change the
> conclusion or action.
>
> Partial resolution is not global closure.

This generalizes across diagnosis, implementation completion, Worker reports,
multi-source research, and corrections without naming individual failure cases.
It complements `Check the framing before settling`: the framing rule keeps
competing explanations open, while this rule keeps materially open state from
being collapsed after partial progress.

## Boundaries

The rule does not require a second pass for every answer, preserve immaterial
uncertainty, or add a verifier workflow. It closes a question when the remaining
uncertainty no longer changes what the user should believe or do.
