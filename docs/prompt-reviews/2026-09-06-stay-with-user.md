# Prompt/capability review: stay with the user

Observed on 2026-09-06 using the project's local timezone, `America/New_York`.
This is a capability decision record from the user's conversation-style
observation, not a vendor prompt import.

| Field | Value |
|---|---|
| Source | User/assistant comparison of Boss and Chat conversation style |
| Runtime files changed | `main.md`, the portable profile role, and the derived live profile role |
| Base changed | no |
| Source patch changed | no |
| Review scope | shared context, explanation depth, and side-of-the-table stance |

## Decision

Adopt a small Main-only role rule that:

- works from the user's side of the table without equating support with agreement;
- preserves important distinctions, causes, tradeoffs, and unresolved assumptions
  in the visible conversation when they will matter later;
- expands the reasoning that is useful shared context while staying brief when it
  is not;
- states material implications directly instead of ending at a status report.

The goal is not generic verbosity. It is to make the shared reasoning that later
turns depend on explicit and to make the Boss feel like a collaborator rather
than a detached reviewer.

## Boundaries

This changes only the Boss role. It does not modify the curated base, Worker
behavior, authorization rules, or runtime patch.
