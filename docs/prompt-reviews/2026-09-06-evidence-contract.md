# Prompt/capability review: evidence contract

Observed on 2026-09-06 using the project's local timezone, `America/New_York`.
This is a capability decision record from the user's design proposal, not a
vendor prompt import.

| Field | Value |
|---|---|
| Source | User-proposed Boss/Worker quality split |
| Runtime files changed | `main.md`, `boss.config.example.toml`, and the derived live profile |
| Source patch changed | no |
| Review scope | completion evidence and risk-triggered verification |

## Decision table

| Change | Bucket | Decision | Reason |
|---|---|---|---|
| Define the user-visible result, non-regressions, and non-goals before substantial delegation | `THINK` | Adopt as a thin Main rule | Boss owns the acceptance boundary; it does not need to own line-by-line code review. |
| Keep outcome satisfaction separate from technical confidence | `THINK` | Adopt | A worker can report passing checks without proving that the user's real outcome was achieved. |
| Require `result`, `checks actually run`, `observed outcomes`, and `unverified areas` in worker handoffs | `WORKER-ONLY` | Adopt in the worker adapter | The implementer supplies inspectable evidence without changing the Main personality or task boundary. |
| Use deterministic checks first and add independent verification for risky or hard-to-validate changes | `OPERATE` / `WORKER-ONLY` | Adopt | This gives high-risk work another attempt to find real bugs without forcing every task through a review pipeline. |
| Make every task use implementer → verifier → reviewer | `IGNORE` | Reject | It would turn Boss Main into a workflow manager and add cost where the change is small or directly observable. |

## Result

The change adds a thin owner-side completion rule and a structured worker
handoff. It does not add a verifier personality, change the worker's stock
coding base, or change the runtime patch.
