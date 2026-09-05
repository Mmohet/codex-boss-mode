# Workspace map

The public repository is the only durable project root. The local manifest maps
the logical roles below to this machine's absolute paths.

```mermaid
flowchart LR
  P[public repo\nMmohet/codex-boss-mode\norigin/main] --> A[tracked Boss artifacts\nbase.md / main.md / SOURCES.md\nconfig example / patch / scripts]
  P --> K[maintenance records\ndocs/prompt-reviews]
  P --> S[maintenance skill\nskills/codex-boss-maintenance]
  P -. reads .boss/workspace.local.toml .-> L
  L[local manifest\ngitignored absolute paths] --> C[Codex Desktop bundle]
  L --> R[live Boss profile\nbase / main / binary / host link]
  L --> U[source checkout\nlocal boss-mode branch]
  U --> O[OpenAI Codex upstream\npinned baseline tag]
  U --> F[Codex fork\npushed boss-mode branch\nsource-development only]
  K --> Q[prompt capture source\npinned revision]
  A --> R
  A --> U
```

## Ownership

| Role | Durable owner | What the check compares |
|---|---|---|
| Public project | this repository and `origin/main` | branch, HEAD, remote URL, clean worktree |
| Runtime prompt files | tracked `base.md`, `main.md`, `SOURCES.md` | SHA-256 against the live copies |
| Source patch | `patches/<tag>/0001-boss-mode.patch` | byte-for-byte equality with the source checkout's baseline-to-branch diff |
| Upstream input | `upstream_remote` plus `upstream_baseline_tag` in the manifest | baseline commit, ancestor relation, live tag heads with `--remote` |
| Codex source-development fork | `source_fork_remote` plus pushed `boss-mode` branch in the manifest | local source HEAD and remote fork branch with `--remote` |
| Live runtime | manifest paths under the Codex home and Desktop app | profile links/features, binary version, host symlink |
| Prompt review | dated files in `docs/prompt-reviews/` | source revision and classification record |

## Commands

```bash
scripts/check-state.sh --local
scripts/check-state.sh --remote
scripts/test.sh
scripts/test.sh --cargo
```

`check-state.sh` is read-only unless the explicit
`--repair-mechanical-lock` option is given; that option only backs up and
restores the exact known Cargo.lock normalization. `test.sh` runs the state
check, shell syntax and patch/source comparisons, and a live binary smoke test.
`--cargo` adds the targeted Codex core configuration tests.

The current live state is intentionally not copied into this document. Run the
check against the local manifest when a new session starts; this avoids turning
an old path or version into a false source of truth.

Prompt review filenames use the local calendar date from `project_timezone` in
the manifest. The current project timezone is `America/New_York`.

## Known test boundary

The broad upstream `cargo test -p codex-core --lib config` suite is not the
maintenance gate. On this checkout it ran 592 tests and then hit the existing
stack overflow in `session::tests::session_configured_reports_permission_profile_for_external_sandbox`.
The maintenance gate therefore uses targeted Boss tests plus build, binary, and
state checks; revisit the broad suite only when the upstream or local test
environment changes.
