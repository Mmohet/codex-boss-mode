# Codex BOSS Token Analysis and Decisions

**Audit date:** 2026-09-14  
**Purpose:** Record the BOSS mode token findings, corrected measurement method, polling decision, configuration change, and the next controlled model comparison.

## Executive decision

The high aggregate usage is driven by delegated Luna workers, not by the Sol parent. In the Sol test task, the parent used 1.874M tokens while five Luna workers used 115.617M. Workers accounted for 98.405% of the combined 117.491M tokens. Token telemetry therefore does not justify changing the parent model solely because the aggregate total feels high.

The operational decision is to use `wait_agent` as the normal orchestration primitive and keep `list_agents` for observability, recovery, scheduling, and explicit status requests. The normal path should not poll with `list_agents`.

## 1 Scope and time windows

This record covers:

- The strict BOSS baseline from **2026-09-09 00:00:00 through 2026-09-13 19:28:10 EDT**, with the user-designated non-BOSS fragment excluded.
- The Sol parent task `01a09e11-28bf-7762-a2da-183f2b8c7d60`, which ran from **2026-09-13 23:58:44.328 through 2026-09-14 01:44:03.935 EDT**.
- Parent versus delegated worker usage, polling calls, input composition, compaction, and configuration behavior.

The audit did not include complete user prompts or raw reasoning content.

## 2 Measurement method and corrected estimates

The corrected method uses the per-response modern `usage` increment as the primary measure. Legacy cumulative usage is used only through positive difference checks. Parent context repeated in child rollouts is deduplicated by turn identity. Compaction resets are handled as a new usage segment; the nested `latest_token_usage_record` inside a compaction event is not counted again.

`reasoning_output_tokens` is a component of output tokens and is reported separately without being added a second time. For every aggregate, `input = cached input + uncached input` and `total = input + output`.

| Earlier result | Why it was wrong | Correct status |
|---|---|---|
| 65.4 billion tokens | Cumulative or repeated records were treated as new usage | Retired |
| 97.77M strict parent | Modern usage and legacy cumulative fields were double-counted; reset handling was incomplete | Retired |
| 94.81M parent and 730.15M combined | Intermediate result before the final business-labeled non-BOSS exclusion | Superseded |
| 94.356M parent and 729.691M combined | Modern increments plus legacy differences, deduplication, compaction handling, and exclusion applied | Current baseline |

## 3 Strict BOSS baseline

The corrected baseline is 2026-09-09 00:00:00 through 2026-09-13 19:28:10 EDT.

### Total usage

| Category | Total tokens | Share of combined |
|---|---:|---:|
| Strict BOSS parent | 94.356M | 12.93% |
| Delegated workers | 634.926M | — |
| System subagent | 0.409M | — |
| All subagents | 635.335M | 87.07% |
| Parent plus all subagents | 729.691M | 100.00% |

### Token types

| Category | Input | Cached input | Uncached input | Output | Reasoning output |
|---|---:|---:|---:|---:|---:|
| Strict BOSS parent | 94.121M | 88.286M | 5.834M | 0.235M | 0.147M |
| Delegated workers | 633.229M | 617.191M | 16.038M | 1.697M | 0.804M |
| System subagent | 0.407M | 0.340M | 0.067M | 0.002M | 0.0004M |
| All subagents | 633.636M | 617.531M | 16.105M | 1.699M | 0.804M |
| Parent plus all subagents | 727.756M | 705.817M | 21.939M | 1.934M | 0.952M |

## 4 Wait and list polling audit

### Definitions

- **Strictly effective `wait_agent`:** The wait is followed by a worker completion, new message, visible state change, or a next substantive action.
- **Strictly invalid `wait_agent`:** A repeated wait or timeout with no visible state change, worker message, or meaningful follow-up action.
- **Strictly effective `list_agents`:** The list differs from the previous list, or the call is immediately tied to `spawn_agent`, `followup_task`, or `interrupt`.
- **Strictly invalid `list_agents`:** The list is unchanged and no lifecycle event justifies the observation.
- **Broad classification:** Allows a lifecycle action or state change after an intervening list call, rather than requiring it to be adjacent.

### Strict classification

| Operation | Total calls | Effective | Invalid | Invalid rate | Invalid input | API-equivalent cost |
|---|---:|---:|---:|---:|---:|---:|
| `wait_agent` | 407 | 219 | 188 | 46.19% | 15.649M | $0.381293 |
| `list_agents` | 132 | 43 | 89 | 67.42% | 7.358M | $0.214575 |
| **Combined** | **539** | **262** | **277** | **51.39%** | **23.007M** | **$0.595868** |

The strict invalid combined input was 23,006,873 tokens. Using the comparison formula below, it was about 18.53% of the strict parent API-equivalent cost of $3.214941. Under the broad classification, invalid calls were 209 / 539, or 38.78%, with 17.306M input and $0.462973 API-equivalent cost.

The comparison formula was:

```text
cached input × $0.02/M + uncached input × $0.20/M + output × $1.20/M
```

This is an API-equivalent comparison, not a Codex credits or subscription billing statement.

The polling wall-clock total was about 40,646.7 seconds across parent tasks. Strictly invalid waits accounted for about 18,355.1 seconds. These are accumulated across threads and are not the user's literal wait time.

The invalid label means that no useful evidence was visible in the rollout. It does not prove that a worker made no internal progress. Token attribution to an individual call uses the nearest subsequent usage record and is therefore approximate.

## 5 Sol parent task

### Parent, workers, and combined totals

All parent `turn_context` records in the target task show `gpt-5.6-sol` with `high` reasoning effort. All five direct workers show `gpt-5.6-luna`, with medium, max, or high effort.

| Scope | Model and effort | Turns / responses | Total | Input | Cached | Uncached | Output | Reasoning |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Parent | Sol / high | 6 / 40 | 1.874M | 1.861M | 1.788M | 0.073M | 0.013M | 0.006M |
| Five workers | Luna / medium, max, high | 16 / 652 | 115.617M | 115.416M | 113.682M | 1.734M | 0.201M | 0.084M |
| Combined | Sol parent plus Luna workers | 22 / 692 | 117.491M | 117.278M | 115.470M | 1.807M | 0.213M | 0.091M |

The parent averaged 46,852 total tokens and 46,537 input tokens per response. Its peak response was 62,363 total tokens with 61,623 input tokens. The parent cached-input rate was 96.07%.

### Worker distribution

| Worker | Model and effort | Responses | Total | Share of workers | Input | Uncached input |
|---|---|---:|---:|---:|---:|---:|
| Newton | Luna / medium | 61 | 7.882M | 6.82% | 7.861M | 0.239M |
| Sartre | Luna / medium | 41 | 4.375M | 3.78% | 4.363M | 0.193M |
| Raman | Luna / max | 262 | 47.169M | 40.80% | 47.084M | 0.612M |
| Confucius | Luna / max | 232 | 49.512M | 42.82% | 49.452M | 0.468M |
| Pauli | Luna / high | 56 | 6.678M | 5.78% | 6.656M | 0.222M |

Raman and Confucius together used 96.682M tokens, or 83.62% of all worker usage, and made 488 `exec` calls. This is the direct explanation for the high combined total.

### Call inventory

| Scope | `spawn_agent` | `wait_agent` | `followup_task` | `list_agents` | `send_message` | `exec` |
|---|---:|---:|---:|---:|---:|---:|
| Parent | 5 | 20 | 11 | 1 | 0 | 0 |
| Children | 0 | 0 | 0 | 0 | 0 | 633 |

Children also made one `wait` call and two `request_user_input` calls. Parent wait responses were approximately 968,593 total tokens, or 51.68% of parent usage, but the parent itself was only 1.595% of the combined total.

### Compaction and context pressure

One top-level compaction was observed in Raman's second turn at 2026-09-14 01:27:46.498 EDT. The preceding response used 320,020 input tokens, of which 318,720 were cached; the first response after compaction used 32,630 input tokens, of which 12,544 were cached and 20,086 were uncached.

No top-level compaction was observed in the parent, Newton, Sartre, Confucius, or Pauli rollouts. All selected sessions used paginated history and the observed `comp_hash` was stable at 3000. There is no explicit telemetry field proving repeated full-history replay.

## 6 Input composition

The aggregate usage record does not bind input tokens exactly to content categories. The observed and plausible categories are:

| Category | Role in input | Typical cache behavior |
|---|---|---|
| Fixed system, developer, skills, AGENTS, and environment context | Role, tools, project rules, and runtime state | Stable prefixes are usually cache-friendly after warmup |
| Historical conversation and task context | Keeps decisions, constraints, and unresolved work available | Re-submitted each turn; hit rate depends on prefix stability |
| Worker messages and tool output | Brings execution, file observations, and verification back to parent | New dynamic content is commonly uncached |
| Dynamic state | Worker status, mailbox events, tool returns, and scheduling state | Changes during polling and can create new input |
| Compaction and replay | Rebuilds a usable context after a reset | Can introduce a new uncached prefix |

Within the parent totals, input represented approximately 99.3% to 99.7% of total tokens. Cached-input coverage across the strict baseline and Sol target parent was approximately 93.8% to 96.1%. This should not be confused with the parent share of combined usage, which was only 1.595% in the Sol task.

The direct mechanism behind high parent input is repeated submission of a long context during the orchestration loop. The telemetry cannot precisely attribute cached or uncached tokens to a particular system block, message, file, or tool output.

## 7 Final configuration decision

| Capability | Role | Normal path |
|---|---|---|
| `wait_agent` | Orchestration primitive | Use after `spawn_agent`, `followup_task`, or `send_message`; after a timeout, wait again directly |
| `list_agents` | Observability, recovery, and scheduling primitive | Use only after a prolonged absence of mailbox events, for diagnosis, or when the user explicitly asks for a listing |

The configuration change is complete, but the policy is a soft constraint. `list_agents` remains callable for exception and recovery scenarios.

- `default_wait_timeout_ms = 300000`
- Live configuration: `/Users/chengzhang/.codex/boss.config.toml`
- Versioned example configuration: `/Users/chengzhang/Dev/codex-boss-public/boss.config.example.toml`
- No changes to Codex source, global `AGENTS.md`, Boss base, Boss main, or the `list_agents` schema.

## 8 Activation and maintenance

The configuration does not require a rebuild to be read by a new process. The safe activation options are:

1. Restart Boss Desktop or the launcher.
2. Start a new task after the configuration change.
3. Verify one worker handoff: `spawn_agent` followed by a long `wait_agent`, and verify that `list_agents` remains available for an exception case.

The configuration inspection indicates that `update.sh` and `build.sh` normally do not overwrite the live configuration. `sync-profile.sh` can synchronize `developer_instructions`, so profile synchronization or an upstream update can change live behavior. After upgrades, compare the live file and example file and recheck the timeout, root usage hint, and worker defaults.

The restart path was not exercised end to end in this audit; the activation statement is based on configuration loading and maintenance behavior inspection.

## 9 Follow-up A B and acceptance metrics

Compare Sol and Luna using the same task corpus, worker fanout, worker effort, tool permissions, and starting context. Change only the parent model, repeat across multiple tasks, and record both cost and result quality.

| Metric | Measurement | Suggested acceptance criterion |
|---|---|---|
| Actual model and effort | Model and reasoning effort per turn | No implicit model or effort drift |
| Token usage | Parent, workers, and combined total; input, cached, uncached, output, reasoning | Compare at equal task quality; report parent and worker separately |
| Polling efficiency | Strictly invalid wait/list calls and their input share | At least halve the 51.39% invalid rate; target below 10% |
| Policy adherence | Normal-path `list_agents` calls and exception reason | Zero normal-path list polling; exception calls have a recorded reason |
| Context stability | Compaction count, largest input, and uncached peaks | No increase caused by the policy change |
| Result quality | Task success, verification, rework, and human score | No quality regression; quality takes priority over token savings |
| Wall-clock time | Task start to final completion and worker-active intervals | No material latency increase at equal quality |

## Evidence and limitations

The audit read the parent rollout, five direct child rollouts, session metadata, turn contexts, function calls, modern usage records, legacy cumulative usage, and compaction events. The primary Sol parent evidence is:

`/Users/chengzhang/.codex/sessions/2026/09/13/rollout-2026-09-13T23-58-39-01a09e11-28bf-7762-a2da-183f2b8c7d60.jsonl`

The corrected strict baseline and polling results were recorded in the 2026-09-13 audit rollout:

`/Users/chengzhang/.codex/sessions/2026/09/13/rollout-2026-09-13T19-28-10-01a09d19-8580-73a2-8221-720472e23bd8.jsonl`

Remaining limitations:

- Tool-level token attribution is approximate because the server may group several calls into one response usage record.
- A strictly invalid call is an absence of visible evidence, not proof of worker inactivity.
- Cached input cannot be tied exactly to a content category from aggregate telemetry.
- There is no same-task, controlled Sol-versus-Luna parent A B yet, so causal model cost or quality differences remain unverified.
