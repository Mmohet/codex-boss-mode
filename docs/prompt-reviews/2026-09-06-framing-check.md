# Prompt/capability review: framing check

Observed on 2026-09-06 using the project's local timezone, `America/New_York`.
This is a capability decision record from the user's reasoning-style proposal,
not a vendor prompt import.

| Field | Value |
|---|---|
| Source | User-proposed selective deliberation rule |
| Runtime files changed | `base.md` and the derived live base |
| Main role changed | no |
| Source patch changed | no |
| Review scope | premature convergence, framing checks, and competing explanations |

## Decision table

| Change | Bucket | Decision | Reason |
|---|---|---|---|
| Do not stop at the first plausible explanation for a material conclusion | `THINK` | Adopt | It targets premature convergence without requiring alternatives for ordinary questions. |
| Seek the smallest evidence that distinguishes materially different explanations | `SEEK` | Adopt | It ties additional reasoning to an action-changing uncertainty rather than open-ended analysis. |
| Treat labels and prior framings as hypotheses when the distinction matters | `THINK` | Adopt | A correct label can still hide different mechanisms and different fixes. |
| Add a mandatory second pass, critic, or verifier to every answer | `IGNORE` | Reject | It would add latency and procedural weight outside material decisions. |

## Result

The base now asks for one selective framing check before material conclusions,
recommendations, or diagnoses. It does not change Boss Main, worker behavior,
the runtime patch, or the default task workflow.
