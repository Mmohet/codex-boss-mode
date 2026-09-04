#!/bin/zsh
# Shared helpers for the build and update scripts. Not meant to be run directly.
#
# Everything here resolves from the repository's own location and from the
# upstream checkout's own pins. There are no absolute paths to any particular
# machine, and nothing outside this repository and $CODEX_HOME is touched.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${(%):-%x}")/.." && pwd)}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

# Upstream Codex checkout. Kept inside the repo (and gitignored) so the build
# cache below it stays with the project instead of wandering.
UPSTREAM_DIR="${BOSS_UPSTREAM_DIR:-$REPO_ROOT/upstream}"
UPSTREAM_URL="${BOSS_UPSTREAM_URL:-https://github.com/openai/codex.git}"

# Build cache. Cargo's workspace root is codex-rs/, so without an explicit
# target dir it starts a second, empty cache there and recompiles everything
# from cold on every run. Pinning it is the whole point.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$REPO_ROOT/target}"

# Low-pressure defaults: the machine stays usable while a build runs, at the
# cost of wall-clock time. Override with BOSS_JOBS if you want it faster.
BOSS_JOBS="${BOSS_JOBS:-3}"
BOSS_NICE="${BOSS_NICE:-20}"
BOSS_MIN_FREE_GB="${BOSS_MIN_FREE_GB:-25}"

APP="${CODEX_APP:-/Applications/ChatGPT.app}"
BOSS_CLI="${CODEX_BOSS_CLI:-$CODEX_HOME/boss/bin/codex}"

fail() { print -u2 "${SCRIPT_NAME:-boss}: $1"; exit 1 }
note() { print "${SCRIPT_NAME:-boss}: $1" }

# Resolve the toolchain the upstream checkout pins, through rustup. Never a
# hardcoded install location: rustup is asked for its own host triple, and the
# channel comes from upstream's rust-toolchain.toml.
boss_toolchain_bin() {
  local ch host bin
  [[ -f "$UPSTREAM_DIR/codex-rs/rust-toolchain.toml" ]] \
    || fail "no upstream checkout at $UPSTREAM_DIR; run scripts/build.sh first"
  ch=$(sed -n 's/^channel *= *"\(.*\)"/\1/p' "$UPSTREAM_DIR/codex-rs/rust-toolchain.toml")
  [[ -n "$ch" ]] || fail "no channel found in the upstream rust-toolchain.toml"
  command -v rustup >/dev/null 2>&1 \
    || fail "rustup is required to resolve the pinned toolchain ($ch); see https://rustup.rs"
  host=$(rustup show 2>/dev/null | sed -n 's/^Default host: *//p')
  [[ -n "$host" ]] || fail "rustup will not report its default host"
  bin="$(rustup show home 2>/dev/null)/toolchains/${ch}-${host}/bin"
  if [[ ! -x "$bin/cargo" ]]; then
    note "installing the pinned toolchain $ch ..."
    rustup toolchain install "$ch" >/dev/null \
      || fail "could not install the pinned toolchain $ch"
  fi
  [[ -x "$bin/cargo" ]] || fail "the pinned toolchain is still not present at $bin"
  "$bin/rustc" --version >/dev/null 2>&1 \
    || fail "the pinned toolchain is present but will not run: $bin/rustc"
  print -r -- "$bin"
}

# The version of the CLI the installed Desktop ships. Boss has to match it: the
# code-mode host is a link into the app bundle, so a mismatched pair means an
# old CLI talking to a new helper.
boss_bundle_version() {
  local v
  v=$("$APP/Contents/Resources/codex" --version 2>/dev/null) \
    || fail "cannot read the CLI version from the app bundle at $APP"
  print -r -- "${v##* }"
}

# Run a command with low scheduling priority and throttled disk I/O. Both are
# inherited by child processes, which matters because the work is done by rustc,
# not by cargo. macOS has no enforceable memory cap (setrlimit(RLIMIT_AS) is not
# honoured and taskpolicy's memory limit is not inherited), so this reduces
# contention -- it cannot guarantee a ceiling.
boss_low_pressure() {
  if command -v taskpolicy >/dev/null 2>&1; then
    nice -n "$BOSS_NICE" taskpolicy -d throttle "$@"
  else
    nice -n "$BOSS_NICE" "$@"
  fi
}

boss_check_disk() {
  local free
  free=$(df -g "$REPO_ROOT" | tail -1 | awk '{print $4}')
  (( free >= BOSS_MIN_FREE_GB )) \
    || fail "only ${free}G free here, below the ${BOSS_MIN_FREE_GB}G floor; a build could fill the disk
  raise the floor with BOSS_MIN_FREE_GB if you know what you are doing"
}

# Cargo silently starts a second cache in codex-rs/target when the target dir is
# not pinned. If one is there, something ran without these scripts.
boss_check_stray_cache() {
  local stray="$UPSTREAM_DIR/codex-rs/target"
  [[ -d "$stray" ]] || return 0
  print -u2 "${SCRIPT_NAME:-boss}: a stray build cache is present at"
  print -u2 "    $stray"
  print -u2 "  It was created by a build that did not pin CARGO_TARGET_DIR and shares"
  print -u2 "  nothing with $CARGO_TARGET_DIR. Nothing needs it. Remove it yourself:"
  print -u2 "    rm -rf '$stray'"
  fail "refusing to build while a stray cache is present"
}

boss_build_binary() {
  local tc built
  tc=$(boss_toolchain_bin)
  boss_check_stray_cache
  boss_check_disk

  note "building (-j $BOSS_JOBS, nice $BOSS_NICE, disk I/O throttled)"
  note "  toolchain  : $tc"
  note "  target dir : $CARGO_TARGET_DIR"
  note "  This takes a while. Peak memory is roughly 5-6GB, set by the"
  note "  single-threaded LTO link at the end, which -j cannot reduce."

  ( cd "$UPSTREAM_DIR/codex-rs" \
    && PATH="$tc:$PATH" boss_low_pressure \
       cargo build -j "$BOSS_JOBS" --release -p codex-cli --bin codex ) \
    || fail "build failed; any previously installed Boss binary was left untouched"

  built="$CARGO_TARGET_DIR/release/codex"
  [[ -x "$built" ]] || fail "the build reported success but produced no binary at $built"
  "$built" --version >/dev/null 2>&1 || fail "the freshly built binary will not run: $built"

  mkdir -p "${BOSS_CLI:h}"
  cp "$built" "$BOSS_CLI"
  ln -sfn "$APP/Contents/Resources/codex-code-mode-host" "${BOSS_CLI:h}/codex-code-mode-host"

  note ""
  note "installed $("$BOSS_CLI" --version | sed 's/.* //') -> $BOSS_CLI"
  note "  A running Codex Desktop still holds the previous binary. Nothing was"
  note "  restarted. Launch Boss Mode with bin/codex-boss whenever it suits you."
}
