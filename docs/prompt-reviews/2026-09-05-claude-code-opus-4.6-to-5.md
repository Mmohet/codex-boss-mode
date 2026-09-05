# Prompt review: Claude Code Opus 4.6 → Opus 5

Observed on 2026-09-05 using the project's local timezone, `America/New_York`.
This is a historical harness review, not a runtime prompt import.

| Field | Value |
|---|---|
| Source repository | `https://github.com/asgeirtj/system_prompts_leaks.git` |
| Source revision | `eb47bcf82b686bc1ea0244442ce31dfa8481d2c5` |
| Baseline | `Anthropic/claude-code/claude-code-opus-4.6.md` |
| Candidate | `Anthropic/claude-code/claude-code-opus-5.md` |
| Captured baseline | 2,854 lines; SHA-256 `e6ede76d8625d34ff6ac59d543367b242de5d00a39008ea6ccc2673eaa3ca8c6` |
| Captured candidate | 2,511 lines; SHA-256 `f7345c386585870a8bb46fe3be6db61718b15a2c06e11b240747ea74f32ff51b` |
| Runtime files changed | no |
| Boss `base.md` / `main.md` changed | no |

## Why this is a formal sample

This is the second cross-vendor comparison in the maintenance history, after
GPT-5.6 → GPT-6 Astra. It tests whether the same decision lens survives a
different agent harness: identify the behavior change, trace its provenance,
separate correlation from causation, place it in Main/Worker/runtime, and ask
whether a real failure justifies changing Boss Mode.

## Decision table

| Change family | Bucket | Main decision | Reason |
|---|---|---|---|
| Exploratory-question gate in 4.6 versus Opus 5's action-forward “deliver the whole task” framing | `THINK` | Preserve the Boss gate; no sync | The baseline explicitly separates exploration from implementation. The candidate makes “enough information to act” and full completion the default. Boss Main already protects the discussion-to-execution boundary. |
| Completion drive, persistence, and continuing under assumptions | `WORKER-ONLY` | Exclude from Main | This changes task worldview and when work should continue or count as complete. It belongs with execution-oriented workers, not the owner-side reasoning layer. |
| Anti-jargon, concise answers, and direct response style | `THINK` | Covered; no sync | These explain part of the user-facing contrast, but the current Boss base already carries plain-language and direct-answer constraints. The diff is evidence for a hypothesis, not a demonstrated Boss failure. |
| AgentTool/workflow restriction in Opus 5 versus more proactive exploration guidance in 4.6 | `OPERATE` | Do not import | This is tool/delegation routing after the action boundary. The project has its own explicit maintenance trigger and worker policy; vendor-specific routing would conflict or duplicate it. |
| Permission handling, corrections, context management, memory, and compaction mechanics | `THINK` / `OPERATE` | Review item by item; no bundle sync | Some mechanics are useful, but the candidate also changes product plumbing and harness assumptions. Keep only a narrowly rephrased rule when the current base leaves a concrete gap. |
| Tool schemas, EndConversation, provider metadata, and product-specific sections | `IGNORE` | Exclude | These are harness/product implementation details, not a Boss contract. |

## Causal and architectural limits

The diff proves that the two harness versions changed at the same time; it does
not prove that any one prompt section caused a particular user experience. This
project has no controlled Claude rollout or output corpus that isolates the
effect, so the cross-vendor agent-harness evolution pattern remains a supported
hypothesis rather than a causal measurement.

Architecturally, the useful split is unchanged:

- Main keeps the conversation-to-execution judgment and the `why / who / success`
  orientation;
- workers may retain the installed model's stronger execution persistence;
- runtime changes still require a source seam or compatibility failure.

## Result

`base/main changed: no`.

The review is historical evidence for the maintenance method, not permission to
copy Claude Code Opus 5 wholesale. Preserve the standing SOURCES rule:

> Take how its tools are used. Do not take what it thinks it should be doing.
