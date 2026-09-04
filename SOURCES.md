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
| `OpenAI/Codex/gpt-5.6.md` | `48b9915063821f33489ff7da21ca448835bdd15b` | 2026-07-27 |

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

The Codex capture was read for comparison only. A worker's Codex layer is
resolved at runtime from the installed build's own model metadata, never from a
captured file.
