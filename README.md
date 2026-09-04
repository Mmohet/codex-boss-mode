# Codex Boss Mode

An **unofficial, experimental** customization of [OpenAI Codex](https://github.com/openai/codex)
that keeps the main agent a thinking partner rather than a coding agent, with
Codex workers available as an execution capability when the work calls for one.

> Not affiliated with, endorsed by, or supported by OpenAI. It patches a
> third-party application. Expect it to break when Codex changes.

## What it does

Stock Codex gives every agent the same coding-agent base instructions. That is
right for a worker and wrong for the person steering the work: ask about a
project's status and you get commit history, because the only lens available is
an engineering one.

Boss Mode changes the composition:

| | Base instructions |
|---|---|
| **Main agent** | a curated general-assistant base that **replaces** the stock Codex base, rather than stacking on top of it |
| **Spawned workers** | that same base **plus** the stock Codex base for whichever model the worker actually runs |
| **Normal Codex** | unchanged |

Everything is opt-in through a Codex profile and an environment variable. The
signed application bundle is never modified, your normal config is never written
to, and there is nothing to undo: launch without the profile and you are back to
stock.

## Two ways to install

### 1. Config only — no compiler

Installs the prompts and a profile overlay. Takes a few seconds.

```bash
./scripts/install-config.sh
codex --profile boss
```

You get the Boss role, the curated base as a profile-scoped instruction file,
and the source-routing and tool-usage discipline in `base.md`.

**What you do not get:** the stock Codex base is still underneath the main
agent, because replacing it is what the source patch does. The curated base is
layered on rather than substituted.

### 2. Full Boss Mode — build a patched CLI

```bash
./scripts/install-config.sh
./scripts/build.sh
./bin/codex-boss
```

`build.sh` fetches upstream Codex at the pinned baseline, applies the patch,
builds a release CLI, and stages it next to a link to the stock code-mode host.
`bin/codex-boss` launches Codex Desktop with `CODEX_CLI_PATH` and
`CODEX_CONFIG_PROFILE` pointed at it. `bin/codex-normal` launches stock.

Requirements: macOS, Codex Desktop installed, `git`, and
[rustup](https://rustup.rs).

**What the build downloads.** `build.sh` needs the network on first run and
fetches two things:

| From | What | Roughly |
|---|---|---|
| `github.com/openai/codex` | a `--depth 1` checkout of the pinned tag, into `upstream/` | a few hundred MB |
| rustup / crates.io | the toolchain upstream pins, plus the crate dependencies | 1-2 GB the first time |

Both land inside this repository (`upstream/` and `target/`, both gitignored)
rather than anywhere else on your system, so removing the directory removes
everything the build created. Later builds reuse that cache and need the
network only for new dependencies. Set `BOSS_UPSTREAM_URL` to use a mirror.

Budget several GB of free disk; the scripts refuse to start below 25 GB free
(`BOSS_MIN_FREE_GB`).

Nothing here calls any service at runtime beyond what Codex itself already
does. The prompts and config are local files.

**The build is slow on purpose.** It runs at low scheduling priority with
throttled disk I/O and few parallel jobs, so the machine stays usable. Expect
tens of minutes. Peak memory is around 5-6 GB and is set by the single-threaded
LTO link at the end, which more or fewer jobs cannot change.

```bash
BOSS_JOBS=6 ./scripts/build.sh     # faster, more contention
BOSS_JOBS=2 ./scripts/build.sh     # slower, slightly gentler
```

macOS has no enforceable memory cap for this — `setrlimit(RLIMIT_AS)` is not
honoured and `taskpolicy`'s memory limit is not inherited by child processes, so
it cannot cap `rustc`. These settings reduce contention; they do not guarantee a
ceiling.

## Keeping up with Codex updates

Codex Desktop updates itself. That replaces the bundled CLI **and** the
code-mode host your patched binary links to, so an old Boss binary ends up
talking to a new helper. `bin/codex-boss` detects the mismatch and says so.

```bash
./scripts/update.sh
```

It reads the version from the installed bundle, puts the upstream checkout on
that tag, applies the patch, rebuilds, and installs. **It does not restart
anything** — relaunch when it suits you.

### The patch follows versions on its own

You do not need a patch set for your exact Codex version. The build always
targets *your installed version*; if this repository has no exact match it takes
the nearest patch set, fetches that baseline so `git apply` has real three-way
merge material, and merges the patch onto your version. It stops only if the
merge genuinely conflicts, and then it names the conflicting files and leaves
the checkout in place so you can finish by hand.

The patch is small and touches slow-moving seams, which is why this works.
Measured against a `rust-v0.153.0` patch set:

| Upstream tag | Result |
|---|---|
| `rust-v0.150.0` | fails |
| `rust-v0.151.0` | applies |
| `rust-v0.153.0` … `rust-v0.153.2` | applies |
| `rust-v0.154.0-alpha.1` … `alpha.3` | applies |

Roughly four minor versions forward and one back, at the time of writing. That
is an observation, not a guarantee — upstream can refactor these files at any
time.

When the patch does travel to a version it was not generated against and the
build succeeds, the adapted patch is written to `patches/rust-v<your version>/`
as a new untracked file. Commit it to carry that version, or delete it.

## No live demo

This is a command-line customization, not a web project: there is nothing to
host and no GitHub Pages site. The only way to see it work is to install it
against your own Codex.

## What is in here

```
base.md                     curated general-assistant base for the main agent
main.md                     the Boss role, layered on top of it
SOURCES.md                  provenance: what base.md is and is not
boss.config.example.toml    profile overlay; copy to $CODEX_HOME/boss.config.toml
bin/codex-boss              launch Codex Desktop in Boss Mode
bin/codex-normal            launch it normally
patches/<tag>/              source patch against that upstream tag
scripts/                    install, build, update
```

No Codex source is vendored here and no compiled binary is distributed. The
patch is applied to a checkout you fetch yourself.

## About `base.md`

`base.md` is **not an official OpenAI prompt** and is not claimed to be one. It
was written by hand, using a third-party prompt capture as a source corpus for
deciding which general-assistant principles generalize to a local coding
environment. Nothing is read from those captures at runtime and they are not
vendored here. Sources are pinned by revision in [SOURCES.md](SOURCES.md).

## Configuration

`boss.config.example.toml` is a Codex profile overlay. Codex reads it only when
the `boss` profile is selected, so normal Codex never sees any of it. The parts
that matter:

| Key | Effect |
|---|---|
| `model_instructions_file` | the curated base for the main agent |
| `developer_instructions` | the Boss role |
| `features.boss_custom_base_replaces_stock` | send the custom base as a real replacement instead of an additive layer |
| `features.boss_hybrid_subagent_base` | give each worker the chat base plus the stock base for its own model |
| `features.boss_connector_inventory` | render reachable data sources from their own metadata at runtime |
| `features.boss_profile_role_survives_host` | keep this profile's role when an embedding host sends developer instructions of its own |
| `features.multi_agent_v2.subagent_developer_instructions` | stop the Boss role from being inherited as a worker's role |
| `memories.dedicated_tools` | use Codex's memory retrieval tools instead of grepping memory files through `exec` |

The three `boss_*` features exist only in the patched binary. The rest work on
stock Codex, which is what the config-only tier gives you.

## Licence

Apache-2.0. The patches are derived from OpenAI Codex (Apache-2.0, Copyright
2025 OpenAI); see [NOTICE](NOTICE) and [LICENSE](LICENSE).
