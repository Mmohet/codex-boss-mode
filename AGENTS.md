# Codex Boss Mode workspace

This repository is the durable project workspace for Codex Boss Mode. It owns
the curated prompt artifacts, the Boss role, the source patch, the launcher and
build/update scripts, maintenance records, and the maintenance skill.

## Start here in a new session

1. Read `.boss/workspace.local.toml`. It is intentionally gitignored because it
   contains machine-specific absolute paths.
2. Run `scripts/check-state.sh --local` for a fast local diagnosis. Add
   `--remote` when the live GitHub refs or the prompt-source head matter.
3. Read `skills/codex-boss-maintenance/SKILL.md` only when the request matches
   runtime/patch maintenance or prompt/capability maintenance.

If the local manifest is missing, copy `.boss/workspace.example.toml` to
`.boss/workspace.local.toml`, fill in the paths, and rerun the check. Do not
guess a path from an old session or a dated Codex conversation directory.

Dates on prompt reviews use the local calendar date in `project_timezone` from
the manifest. This project currently uses `America/New_York`; record UTC only
as an additional timestamp when it matters, never as a replacement filename.

## Source-of-truth rules

| Concern | Source of truth | Derived or disposable state |
|---|---|---|
| Public project and releaseable artifacts | this checkout and `origin/main` | any other public checkout |
| Main base, Boss role, provenance, config template | `base.md`, `main.md`, `SOURCES.md`, `boss.config.example.toml` | `$CODEX_HOME/boss/*`, `$CODEX_HOME/boss.config.toml` |
| Runtime source patch | `patches/<tag>/` in this repo | the patched source checkout and its build cache |
| Upstream code | the pinned OpenAI Codex tag named in the manifest | the local `upstream/` build checkout |
| Codex source-development fork | the fork remote and pushed `boss-mode` branch named in the manifest | a local-only source branch |
| Current runtime | the installed Desktop bundle plus the live paths in the manifest | an old Boss binary or stale host symlink |
| Prompt/capability decisions | a dated review under `docs/prompt-reviews/` | the raw capture itself |

The source checkout is a rebuildable development workspace, not a second
release project. Its `origin` points at `https://github.com/openai/codex.git`,
and its `fork` remote points at the real Codex fork recorded in the manifest.
The `boss-mode` branch is pushed to that fork so another machine can recover the
source-development state. Keep the public Boss repository as the only release
source of truth; do not treat the Codex fork as the place to publish Boss
artifacts.

The live profile may contain machine-specific MCP, hook, and environment
settings. Those are runtime state. The tracked config example defines the
portable Boss contract; `scripts/check-state.sh` checks the invariant links and
prompt hashes without overwriting the live profile.

## Maintenance boundary

Runtime/Patch maintenance starts with deterministic checks, then the existing
`scripts/update.sh` and `scripts/build.sh`, then the relevant tests. Keep the
source checkout clean between runs. If the only tracked source change is the
known mechanical `Cargo.lock` version normalization, use
`scripts/check-state.sh --repair-mechanical-lock`; any other tracked change is
drift. Model
judgment is reserved for a real patch conflict or a changed upstream seam whose
meaning is no longer preserved by context matching.

Prompt/Capability maintenance starts with a pinned capture diff against the last
baseline (use `scripts/prompt-diff.sh`) and classifies each change as `THINK`,
`SEEK`, `OPERATE`, `WORKER-ONLY`, or `IGNORE`. Do not copy a new Codex prompt
wholesale into the Boss base. Apply the standing SOURCES rule: **Take how its
tools are used. Do not take what it thinks it should be doing.**

Autonomy and persistence belong primarily to workers. Main-agent changes about
skill selection, conversation steering, compaction, and tool mechanics require
an explicit per-item decision recorded in the review; a capture does not itself
authorize a change to `base.md` or `main.md`.

## Recovery

The normal recovery path is:

```text
AGENTS.md
  -> .boss/workspace.local.toml
  -> scripts/check-state.sh --local [--remote]
  -> public artifacts / pinned patch / live derived paths
  -> scripts/update.sh or scripts/build.sh
  -> smoke test and record the result
```

The scripts never modify the signed Desktop bundle. A failed build leaves the
previous installed Boss binary in place. A failed patch application leaves the
upstream checkout available for inspection; resolve the seam, regenerate the
versioned patch, and rerun the checks.
