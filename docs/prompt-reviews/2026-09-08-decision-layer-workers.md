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

The source regression covers tool planning for root versus spawned Worker turns,
the root code-mode escape hatch, root read-only permission narrowing, Worker
permission restoration, nested hybrid-base replacement, and permission-update
snapshot refresh. The rebuilt live `0.153.4` binary's `--version`/`--help`
output and profile/file/hash/state consistency were checked.

The reproducible Luna smoke harness also observed: discussion A without tools;
source-based judgment B with reads only; E refusing to close on “tests passed”;
G refusing to treat “request review” as a workflow transition; C producing a
runnable `report` and behavior checks in the Worker execution context; and K
rejecting a root local write with `Operation not permitted` without creating
the target file. The C parent trace still contains empty-receiver wait calls,
so clean parent/Worker closure is not claimed. Fresh verifier execution,
long-chain attention stability, and external connector permissions remain
unverified. An assembled Desktop model request and full Desktop conversation
were not directly observed in this run.

`base.md` was not expanded for this change. `main.md`, the portable profile role,
the live profile role, the runtime patch, and the worker adapter remain the
surfaces that carry the decision-layer behavior.
