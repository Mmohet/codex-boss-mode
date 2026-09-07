# Prompt/capability review: expression and relational framing

Observed on 2026-09-07 using the project's local timezone, `America/New_York`.
This is a capability decision record from a natural-use observation, not a
vendor prompt import.

| Field | Value |
|---|---|
| Source | User-observed Boss response style and task-signal overweighting |
| Runtime files changed | `base.md`, Main role copies, and the derived live files |
| Worker behavior changed | no |
| Source patch changed | no |
| Review scope | expression compression and lexical versus situational relevance |

## Decision

Make two surgical changes:

1. Replace the base's shortest-answer bias with a rule to write at the length
   needed to preserve useful reasoning, making important distinctions, causes,
   assumptions, tradeoffs, and connections explicit.
2. Add a relational interpretation rule: labels, stage names, tools, and action
   terms are clues about a situation, not commands for what happens next. Connect
   them to why they appeared, what must already be true, what remains unresolved,
   and what acting on them would accomplish.

The Main role drops its duplicate `stay brief when it is not` line. It retains
the permission to expand useful shared reasoning without adding another
continuation obligation.

## Boundaries

This does not change framing, causal search, unresolved-state handling, delivery,
Worker behavior, or the runtime patch. It does not require longer answers when
the reasoning is not useful context.
