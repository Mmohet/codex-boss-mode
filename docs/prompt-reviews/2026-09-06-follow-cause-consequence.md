# Prompt/capability review: follow the cause and the consequence

Observed on 2026-09-06 using the project's local timezone, `America/New_York`.
This is a capability decision record from the user's reasoning-style proposal,
not a vendor prompt import.

| Field | Value |
|---|---|
| Source | User-proposed causal generalization and importance-selection rule |
| Runtime files changed | `base.md` and the derived live base |
| Main role changed | no |
| Source patch changed | no |
| Review scope | shared causes and action-relevant implication selection |

## Decision

Adopt one compact section with two connected moves:

1. Prefer the smallest underlying mechanism that explains several observations,
   predicts what else should be true, and generalizes beyond the triggering case.
2. When several implications or questions remain, surface the one that would
   most change what the person should believe, decide, or do, and explain why it
   matters instead of listing follow-ups for completeness.

This replaces case-specific fixes with a general causal search habit and turns
conversation continuation into importance selection rather than a mandatory next
step.

## Boundaries

The rule does not require root-cause analysis for every small question, a full
project plan, or a new verifier workflow. It changes only the curated base; Main,
Workers, and the runtime patch remain unchanged.
