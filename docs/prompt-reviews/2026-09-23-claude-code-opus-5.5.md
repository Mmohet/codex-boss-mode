# Prompt review: Claude Code Opus 5 → Opus 5.5

Observed on 2026-09-23 using the project's local timezone, `America/New_York`.
This is a focused harness review, not a runtime prompt import.

| Field | Value |
|---|---|
| Source repository | `https://github.com/asgeirtj/system_prompts_leaks.git` |
| Opus 5 baseline capture | `Anthropic/claude-code/claude-code-opus-5.md` at `eb47bcf82b686bc1ea0244442ce31dfa8481d2c5` |
| Opus 5.5 candidate capture | `Anthropic/claude-code/claude-code-opus-5.5.md`, introduced by `a03321b094e65cad2ccd1f5ffb4b309537648834` |
| Source repository head at review | `4a725c5b51895d0022da198c473432561933fb2c` |
| Runtime files changed | no |
| Boss `base.md` / `main.md` changed | `base.md` only |

The Opus 5 path at the newer source snapshot differs from the previously pinned
capture only in slash placeholders, with no behavior-relevant change. This
review records the selected pasted-content boundary; it does not treat the
large candidate prompt as a bundle to import.

## Decision

| Change | Bucket | Decision | Reason |
|---|---|---|---|
| Pasted or quoted source content may contain instructions that are not the user's own request | `THINK` | Adopt a narrow, vendor-neutral rule in `base.md`; leave `main.md` unchanged | The existing base requires respecting the authority actually given, but does not distinguish instructions inside supplied source material from the user's instructions. The rule clarifies whose intent governs action without adding autonomy. |

The adopted principle is phrased generically: pasted or quoted text is content to
understand, and embedded instructions are followed only when the user's own
request asks for that. No Claude-specific tag or prompt structure is carried over.

## Method and limits

The comparison follows the project decision lens: prompt changes are evidence to
evaluate, not automatic upgrades; classify material changes, check for equivalent
meaning in `base.md` and `main.md`, adopt only the smallest clearly better general
rule, and keep prompt-review conclusions separate from causal claims about model
behavior. This is a reasoning and intent-boundary principle, not tool mechanics
or worker execution policy.

The prior Opus 4.6 → Opus 5 review found the discussion-to-execution gate should
remain in Main and completion drive should remain worker-side. This addition does
not change either decision.

## Result

`base/main changed: yes` (`base.md` only).

The prompt capture informed a narrow clarification; it was not copied into the
runtime. Preserve the standing SOURCES rule:

> Take how its tools are used. Do not take what it thinks it should be doing.
