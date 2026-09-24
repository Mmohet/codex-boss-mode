# Capability review: user-directed Claude Code collaboration

Observed on 2026-09-23 using the project's local timezone, `America/New_York`.
This review records a direct user request to use Claude Code alongside Boss;
it does not import instructions from a vendor prompt.

| Field | Value |
|---|---|
| User direction | Build all three described modes: bounded second opinion, read-only source inspection, and isolated code editing with Boss review |
| Relevant prompt capture review | `docs/prompt-reviews/2026-09-23-claude-code-opus-5.5.md` (separate prompt-source judgment) |
| Local Claude Code CLI observed | `2.1.281` after updating from `2.1.274` |
| Authentication status observed | `loggedIn=true`, `authMethod=claude.ai`, `apiProvider=firstParty`, `subscriptionType=pro`; email and organization details suppressed |
| Runtime integration | explicit helper, config install/sync path, source-state check, no-spend mock tests |
| Boss capability source | `base.md`; Claude tool guidance is not in persona/methodology `main.md` or its template block |
| Fresh-install path | `scripts/install-config.sh` already installs `base.md` and the helper; `sync-profile.sh` already refreshes both |

## Decisions

| Change | Bucket | Decision | Reason |
|---|---|---|---|
| Let Boss use Claude when the user asks | `OPERATE` | Put brief capability guidance in `base.md`; keep Claude tool routing out of Main persona/methodology and the template's `developer_instructions` block | The general Boss-facing instruction belongs in the base role. The installed base and helper are already copied by config installation and refreshed by profile sync. |
| Pass a compact packet and select consult, inspect, or edit mode | `OPERATE` | Implement in `scripts/claude-collab.sh` and document the packet contract | Each mode has a clear information and tool boundary; provider overrides are refused by name and the CLI runs under an environment allowlist, auth status is checked before model use, calls are bounded by turn and wall-clock limits, and JSON is returned for Boss assessment. |
| Allow Claude to edit code | `WORKER-ONLY` | Require task-specific edit authority and a clean source checkout; create an unmerged worktree with no shell or MCP tools | The lead can review the diff and run project checks before deciding whether to integrate. No automatic commit or merge is permitted. |

## Provenance and limits

The requested capability comes from the user's own request on 2026-09-23, not
from copying the Opus 5.5 prompt. The helper's CLI flags were checked against
the [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference)
and the installed CLI's local help. Anthropic's official
[Claude Code v2.1.280 release](https://github.com/anthropics/claude-code/releases/tag/v2.1.280)
added the `claude-opus-5-5` model, so the helper gates that model on CLI 2.1.280
or later. The initial 2.1.274 CLI was below this minimum, a plausible but
unconfirmed cause of the first fast smoke failure. `claude update --help`
reports “Check for updates and install if available.” The standard updater
updated the user-level CLI from 2.1.274 to 2.1.281. A pinned 2.1.232 process
launched by Arc remained alive on its original binary path throughout; it was
not terminated or replaced.

`claude auth status --json` reported the status fields in the table above;
sensitive identity fields were filtered before display. The helper repeats
this check before each model request, under the same minimal environment as the
request, and fails closed if it cannot confirm a first-party Claude.ai
subscription.

The no-spend mock suite exercises the real wrapper and a temporary Git
repository with a fake Claude executable. An initial bounded Opus 5.5 smoke on
CLI 2.1.274 returned exit 1 after 2.44 seconds; the captured diagnostic was
generic, so it did not establish whether a request reached the model or used
subscription quota. After updating to 2.1.281, one consult smoke with the same
harmless phrase-only packet succeeded in 3.61 seconds wall time
(2,198 ms reported CLI duration), one turn, no tools. JSON parsed with `type`,
`result`, and `usage`; the response was `bridge-smoke-ok`, with 2 input tokens,
95 output tokens, 540 cache-read input tokens, and 3,461 cache-creation input
tokens. The CLI also reported `total_cost_usd=0.029704`; this is a response
metric, not evidence of API billing. The sanitized preflight confirmed
`claude.ai` / first-party / Pro, so this request used the Claude.ai subscription
route. No account identity was retained. Authentication can change, so the
preflight remains part of each invocation.

After the consult smoke, one bounded `edit` smoke ran against a newly created
temporary clean Git repository, with a 90-second timeout and a packet asking
for exactly one text file. It completed in 10.07 seconds using four turns. The
returned JSON was a `result`; the requested file was exact, the isolated
worktree contained only that untracked file, its HEAD still matched the source,
and the source HEAD, tracked file bytes, and clean status were unchanged. The
worktree was under the configured temporary root; no commit was made. The
temporary repo, worktree, and branch were removed after verification. This
confirmed the real edit path without touching the user's repositories or live
Boss profile.

The operating rule is explicit opt-in: Boss does not call Claude simply because
a task is complex. When the user asks to involve Claude, Codex stays responsible
for the outcome, and the Worker returns Claude's result and any worktree path
for inspection.

## Result

Claude capability guidance now lives in `base.md`; the earlier routing cue was
removed from `main.md` and the template. Pre-existing edits in both prompt files
were preserved. The existing install/sync path already copies `base.md` and the
helper, so no change to live profile installation logic is needed.

This is a narrow collaboration path around Claude Code. It does not replace the
Boss role or treat Claude's output as a verdict.
