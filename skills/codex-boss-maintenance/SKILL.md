---
name: codex-boss-maintenance
description: >-
  Maintain the Codex Boss Mode runtime patch or review a new Chat, Codex,
  Claude Code, or other agent-harness prompt capture against the recorded
  baseline. Trigger only for Desktop/upstream updates, patch drift or
  conflicts, rebuild/test requests, or explicit prompt/capability maintenance.
  Do not trigger for ordinary Boss Mode use, persona tuning, or general
  repository work.
metadata:
  short-description: Deterministic Boss runtime updates and narrow prompt reviews
---

# Codex Boss maintenance

This skill owns two maintenance lanes. Keep them separate because runtime
compatibility and prompt judgment have different evidence and different failure
modes.

## Entry gate

Read the project root `AGENTS.md`, then `.boss/workspace.local.toml`. Run:

```bash
scripts/check-state.sh --local
```

Add `--remote` when the current public commit, upstream tags, or prompt-source
revision can change the decision. If the manifest is missing, stop and restore
it from `.boss/workspace.example.toml`; do not rediscover paths from shell
history.

The public checkout is the durable source of truth. The live profile, live
prompt copies, patched binary, source checkout, and build cache are derived
state. Preserve unrelated changes in the source checkout and public worktree.

## Decision lens

Before changing Boss Mode, distinguish:

1. observed behavior;
2. instruction/runtime provenance;
3. causal evidence;
4. architectural placement; and
5. whether a real failure justifies the change.

A newer prompt, model, tool, or upstream implementation is not itself a
reason to change Boss Mode. Prefer preserving a known-good behavior until a
concrete failure or clearly superior general rule justifies changing it.

## Lane A: Runtime/Patch maintenance

Use this lane when Codex Desktop or the upstream Codex source changed, the Boss
binary and Desktop CLI disagree, the host link moved, or a patch needs to be
rebuilt.

1. Run `scripts/check-state.sh --remote` and record the installed Desktop
   version, the local source branch/head, the baseline tag, the patch/source
   comparison, and the binary/host relationship.
2. If the source checkout is dirty, run
   `scripts/check-state.sh --local --repair-mechanical-lock` only when the
   checker proves that the tracked change is the exact mechanical Cargo.lock
   normalization. Other tracked changes remain drift and require inspection.
3. Run `scripts/update.sh` when the Desktop version changed, or
   `scripts/build.sh` when the target is explicit. These scripts select the
   installed version, use the nearest versioned patch, and keep the signed app
   bundle untouched.
4. Run `scripts/test.sh --cargo` when the patch was applied or regenerated.
   The cheap checks in `scripts/test.sh` remain useful when a compiler run is
   intentionally deferred.
5. If patch application conflicts, stop at the named files. Inspect the
   upstream seam and decide whether the existing behavior still has the same
   meaning. Only then resolve the conflict, regenerate
   `patches/<tag>/0001-boss-mode.patch`, and rerun the checks.
6. If the seam's semantics changed, write the decision into a dated project
   note before changing the patch. Do not hide a semantic rewrite inside a
   mechanical rebase.
7. After a source change is validated, push the reproducible `boss-mode` branch
   to the manifest's Codex fork. The fork is a recoverable source-development
   workspace; the public `codex-boss-mode` repository remains the release
   source of truth.

The model is not needed for a clean version move, a successful three-way patch,
or a passing targeted test. It is needed for a real conflict or for evidence
that the upstream seam no longer preserves the Boss contract:

- the main agent receives the curated base as a replacement;
- workers receive the curated base plus their own model's stock Codex base;
- profile selection survives an embedding host;
- connector inventory remains runtime metadata;
- the Boss role is not inherited as a worker role.

The broad upstream `cargo test -p codex-core --lib config` suite is a known
upstream/local issue on this checkout: it reaches an existing stack overflow in
`session::tests::session_configured_reports_permission_profile_for_external_sandbox`.
Use the targeted Boss tests as the maintenance gate unless the upstream or local
test environment changes.

## Lane B: Prompt/Capability maintenance

Use this lane when a new Chat, Codex, Claude Code, or other agent-harness prompt
capture is available or a capability change needs review. The input is a pinned
capture path and revision, not a prompt to copy into runtime. The decision lens
is vendor-neutral; the source path and revision are the adapter.

There are two distinct maintenance outcomes:

- **Boss-principle maintenance:** use any vendor's prompt to test whether the
  current Boss principles have a real gap or whether a clearly better general
  rule exists for Main. A newer prompt is evidence to evaluate, not an upgrade
  to apply.
- **Tool-mechanics maintenance:** use Codex captures as the primary source for
  narrow mechanics such as search, shell, escaping, or test handling. Carry one
  directly only when it is action-local, fits this environment, and is not a
  duplicate. Mechanics from another vendor or product are candidates only after
  checking their adaptation to this tool/runtime boundary.

1. Read the baseline and candidate from the source named in the manifest. For a
   new capture, record its commit before comparing it.
2. Produce a focused diff grouped by behavior. Use
   `scripts/prompt-diff.sh BASELINE CANDIDATE` for the reproducible comparison.
   Do not paste the full prompt into `base.md`, `main.md`, or the live profile.
3. Classify every material change using exactly one of these buckets:

   | Bucket | Meaning in this project |
   |---|---|
   | `THINK` | owner-side reasoning, intent reconciliation, or decision framing that belongs in Main |
   | `SEEK` | source/tool routing, context lookup, or evidence-seeking mechanics that may improve Main |
   | `OPERATE` | tool execution mechanics that are useful only after the action is already chosen |
   | `WORKER-ONLY` | autonomy, persistence, execution drive, or worker role behavior |
   | `IGNORE` | persona, product plumbing, formatting taste, duplicated policy, or anything that would broaden Main's autonomy |

4. For `THINK` and `SEEK`, decide whether the current Boss principle is missing
   or inferior; adopt only the smallest clearly better general rule. For
   `OPERATE`, first check whether a narrow Codex mechanic can be carried over
   directly. For a non-Codex mechanic, record the environment adaptation check
   before considering adoption. A capture alone is not permission to edit
   `base.md` or `main.md`.
5. Before adding any rule, search the current `base.md`, `main.md`, and project
   instructions for an equivalent semantic rule. Replace, sharpen, or remove
   the duplicate instead of accumulating another phrasing. Keep one canonical
   rule when the behavior is already covered.
6. Record the review under `docs/prompt-reviews/YYYY-MM-DD-<model>.md`, including
   source revision, baseline revision, classifications, decisions, and explicit
   `base/main changed: yes|no`.
7. Keep the SOURCES rule visible in the review: **Take how its tools are used.
   Do not take what it thinks it should be doing.**

### First sample: GPT-6 Astra

The `gpt-6-astra.md` capture is the first recorded sample against
`gpt-5.6.md`. The default decisions are:

- new permission persistence and conversation continuity: review as `THINK` or
  `SEEK` only where the current Boss base leaves a concrete gap;
- autonomy and persistence language: `WORKER-ONLY`;
- skill selection, conversation steering, and compaction: `THINK`/`SEEK`,
  reviewed per rule and kept only when they improve owner-side judgment without
  turning a discussion into an automatic task;
- tool mechanics such as command escaping, test reporting, and structured
  handoff: `OPERATE`, and keep only the mechanics that are missing from the
  current base;
- personality, writing taste, visualization preferences, and generic skill
  loading policy: `IGNORE` unless a separate owner-side gap is demonstrated.

The review must end with a small decision table and a clear result. “No prompt
sync” is a valid result and should be recorded when the current base already
covers the useful mechanics.

### Historical sample: Claude Code 4.6 → Opus 5

The Claude Code Opus 4.6 → Opus 5 comparison is a second historical sample,
alongside GPT-5.6 → GPT-6 Astra. Treat it as evidence about agent-harness
evolution, not as a request to import Claude Code's prompt into Boss Mode.

The default decisions are:

- the weakened exploratory-question gate and the newer “deliver the whole task”
  framing are `THINK`; preserve Boss Main's discussion-to-execution boundary;
- completion drive, persistence, and “enough information → act” behavior are
  `WORKER-ONLY`; do not move that task worldview into Main;
- anti-jargon, concise user-facing communication, and direct answers are
  `THINK` only where the current Boss base leaves a concrete collaboration gap;
  otherwise record them as covered or style-only, with no sync;
- the stronger restriction on AgentTool/workflow use is `OPERATE`/`SEEK`; do not
  import it over this project's explicit maintenance and delegation policy;
- tool schemas, memory plumbing, permissions, and product-specific sections are
  reviewed for mechanics and provenance, not copied as a vendor bundle.

The sample supports a cross-vendor evolution hypothesis, but a prompt diff alone
does not prove that it caused a particular rollout behavior. Record the missing
causal evidence and keep `base/main changed: no` unless a concrete Boss failure
or a clearly superior general rule justifies a separate change.

## Completion

Finish with fresh evidence: the state check, the selected runtime tests or the
prompt diff/review, changed files, and unresolved boundaries. Do not claim that
runtime maintenance is complete when the binary version, host link, profile
references, or source patch are still unverified. Do not claim prompt
maintenance is complete when a full prompt copy replaced a considered decision.
