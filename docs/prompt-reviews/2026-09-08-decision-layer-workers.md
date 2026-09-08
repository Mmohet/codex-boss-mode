# Boss decision layer and worker execution

Date: 2026-09-08 (America/New_York)

## Reason for the change

Long implementation and test loops can make a small Main model mistake a local
slice for the user's whole outcome. The remedy is to keep Main responsible for
understanding, judgment, source retrieval, worker control, and acceptance while
moving substantial engineering execution into an isolated Worker context.

## Decisions

| Surface | Decision |
|---|---|
| Main role | Add a short decision-layer statement and keep worker use conditional on attention cost, not on technical keywords. |
| Main to Worker | Natural-language outcome, constraints, non-goals, corrections, authorization, and evidence boundary; no fixed JSON handoff or prescribed implementation sequence. |
| Worker to Main | Natural-language reality: actual changes, observed behavior, checks actually run, findings handled, and unverified areas. Status labels are not completion evidence. |
| Worker identity | Preserve the existing hybrid composition: inherited Boss chat base plus the exact stock base for the final child model. |
| Nested workers | Record and remove the prior stock suffix before adding the exact stock base for the final child model; old and new model prompts are never mixed. |
| Main local execution | The opt-in `boss_main_decision_layer` feature keeps root shell/stdin available for read-only source retrieval, narrows the root filesystem profile, and hides apply-patch, permission-escalation, and code-mode surfaces. Spawned Workers restore the configured execution profile and are excluded from this root-only boundary. |
| External tools | MCP/connectors remain available and governed by their own runtime permissions. The boundary is not an operating-system security sandbox. |
| Independent verification | Fresh verifier Workers are risk-selected and optional, not a mandatory pipeline. |

## Evidence boundary

The runtime regression covers tool planning for root versus spawned Worker turns,
the root code-mode escape hatch, root read-only permission narrowing, Worker
permission restoration, and nested hybrid-base replacement. Desktop and CLI
profile assembly were smoke-checked after rebuilding the patched binary;
external connector permissions are intentionally outside this local tool-surface
regression.

`base.md` was not expanded for this change. `main.md`, the portable profile role,
the live profile role, the runtime patch, and the worker adapter remain the
surfaces that carry the decision-layer behavior.
