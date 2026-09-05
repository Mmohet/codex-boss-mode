# Sources and provenance

## What this modifies

Codex Desktop (`ChatGPT.app`, bundle id `com.openai.codex`) and the
`codex-cli` binary it embeds. The patched binary is loaded through the
`CODEX_CLI_PATH` environment variable; **the signed application bundle is
never modified**, and normal Codex is unaffected.

| Item | Value |
|---|---|
| Upstream project | [openai/codex](https://github.com/openai/codex) |
| Patch baseline | `rust-v0.153.0` |
| Baseline commit | `41e22fee981a63b3698df7ed36bad393cda24715` |
| Matching Desktop CLI | `codex-cli 0.153.0` |
| Build toolchain | pinned by upstream's `codex-rs/rust-toolchain.toml` |

The patch in `patches/rust-v0.153.0/` is generated against that tag. For a
different Codex version you have to regenerate or re-apply it yourself; see the
README.

## Where `base.md` comes from

`base.md` is **not an official OpenAI prompt** and is not claimed to be one.
It was written by hand, using a third-party prompt capture as a *source corpus*
for deciding which general-assistant principles were worth carrying into a local
coding environment. Nothing is read from those captures at runtime, and they are
not vendored into this repository.

| Capture consulted | Pinned revision | Captured |
|---|---|---|
| `OpenAI/gpt-5.6-sol.md` | `afb6df6912cf72c11f268bd55b0284f5b63d0fd5` | 2026-08-22 |
| `OpenAI/Codex/gpt-5.6-sol.md` | `48b9915063821f33489ff7da21ca448835bdd15b` | 2026-07-27 |

Repository: <https://github.com/asgeirtj/system_prompts_leaks>

## Selection notes

The ChatGPT capture is roughly 1,845 lines and is overwhelmingly product
plumbing for the ChatGPT web and app surface. The material that generalizes to a
local coding environment is a small fraction of it.

Kept, and rephrased as general principles:

- separating a stated requirement from a proposed method;
- treating discussion, correction, and uncertainty as normal rather than as
  tasks to be executed;
- not letting a coined label stand in for the problem it was meant to describe;
- plain-language communication, and stating technical facts in a checkable form;
- avoiding self-referential "honest take" framing;
- tools as capability rather than identity, and not claiming background work
  without a real mechanism;
- prior assistant output as context rather than settled truth;
- generic local safety: authorization, preserving existing work, scope limits on
  destructive or outward-facing actions, protecting secrets;
- source and tool routing discipline: resolving what a question refers to before
  choosing where to look, and not substituting a convenient local source for the
  one the question is actually about.

Deliberately excluded: document/spreadsheet/slides environment skills, artifact
sandbox and download-link rules, ads and sponsored content, subscription and
product-tier descriptions, Work/Canvas/writing-block guidance, image-generation
routing, memory citation syntax, ChatGPT model identity and date text,
web/genui/business/weather widget rules, copied tool schemas, file-download UI
conventions, parental controls, automation product surfaces, and any environment
path unavailable in a local Codex installation.

## What was taken from the Codex capture

The main agent's base *replaces* the stock Codex base rather than layering on it,
so anything mechanical that only lived in the stock base is lost unless it is
carried across. The Codex capture was mined for exactly that, under one rule:

> Take how its tools are used. Do not take what it thinks it should be doing.

The test applied to each line: *if the agent has already decided to take this
action, does this sentence only make the action go better?* Keep it. *Does this
sentence change whether the action is taken at all, how the request is read, how
the task is pushed forward, or when it counts as finished?* Drop it.

Carried across, rephrased:

- search with `rg` / `rg --files` before `grep` or `find`, and fall back quietly;
- issue independent tool calls together rather than serially;
- no printed separators chaining shell commands;
- backticks and `$()` in a command string still execute — escape with care and
  never let a command's output expose a credential;
- no blocking sleep or wait beyond about a minute;
- never repurpose `$HOME` or `$CODEX_HOME` for your own value;
- edit files with the file-editing tool, not `cat`, redirection, or a scripting
  language, with formatting runs and bulk mechanical rewrites as the exception;
- a dirty worktree belongs to the person: preserve, ignore what is unrelated,
  escalate rather than clear;
- never `git reset --hard` or `git checkout --` unasked; prefer non-interactive git;
- name a destructive target with an explicit checked path, never `$HOME`, `~`,
  `/`, a workspace root, a glob, or a command substitution; `mktemp -d` for
  temporary directories; prefer the recoverable form;
- expand a skill's short path alias before opening anything, and run or patch the
  scripts and assets it ships rather than recreating them;
- the renderer's contract for a clickable file link: plain label, absolute target,
  optional line number, angle brackets when the path has spaces, no backticks, no
  `file://` scheme, no line ranges.

Deliberately not carried across: the Codex persona and writing voice, the
commentary/final channel cadence, final-answer formatting and visualization
taste, and the autonomy-calibration section. Also left behind are the stock
skill *procedure* rules — when a skill must be used, who has to read it, whether
reading may be delegated, how several are sequenced. Those are agent workflow,
this project defines its own, and carrying both would stack two sets of rules on
top of each other.

The autonomy section is the one to be most careful about. It is what turns an
offhand question into inspect / gather evidence / progress the task / verify /
keep going — the employee reflex this project exists to get away from.

A worker's Codex layer is still resolved at runtime from the installed build's own
model metadata, never from a captured file. The extraction above matters only for
the main agent, which has no stock base underneath it.

## Prompt maintenance review ledger

Prompt captures are reviewed as dated diffs and are not copied into the runtime.
The first recorded comparison is `OpenAI/Codex/gpt-6-astra.md` against
`OpenAI/Codex/gpt-5.6.md`, both read from `asgeirtj/system_prompts_leaks` at
revision `eb47bcf82b686bc1ea0244442ce31dfa8481d2c5` on 2026-09-04. The review
and its per-change decisions live in
`docs/prompt-reviews/2026-09-04-gpt-6-astra.md`.

The second historical comparison is Claude Code Opus 4.6 against Opus 5 at the
same pinned revision, reviewed on 2026-09-05. It is recorded in
`docs/prompt-reviews/2026-09-05-claude-code-opus-4.6-to-5.md` as evidence about
agent-harness evolution only; it is not a source for copying a vendor prompt
into `base.md` or `main.md`.
