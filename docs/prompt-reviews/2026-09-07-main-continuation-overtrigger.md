# Prompt/capability review: Main continuation over-trigger

Observed on 2026-09-07 using the project's local timezone, `America/New_York`.
This is a capability decision record from a natural-use regression, not a vendor
prompt import.

| Field | Value |
|---|---|
| Source | User-observed Boss response after a version/path diagnosis |
| Runtime files changed | Main role and its portable/live copies |
| Base changed | no |
| Source patch changed | no |
| Review scope | proactive continuation that was relevant but not part of the user's thread |

## Observation

The response correctly answered the version and launcher question, then added an
unrequested warning about `/opt/homebrew/bin/codex` and using absolute paths.
The warning was not false, but it was not needed to make the current reasoning
complete. It made the response feel like it had started a second topic.

## Decision

Remove the Main-only sentence that told the Boss to state an implication or next
move whenever it materially improved the user's position. The base still keeps
`Continue the shared thought`, including its explicit rule not to manufacture a
next step, and the Main role still permits expanding reasoning that will matter
later.

This is a subtraction, not a new prohibition: let relevant implications appear
as part of completing the current reasoning, rather than making continuation a
separate personality obligation.
