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
    || fail "the pinned toolchain is present but will not run: $bin/rustc
  Repair it with: rustup toolchain install $ch"
  [[ -x "$bin/rustfmt" ]] && "$bin/rustfmt" --version >/dev/null 2>&1 \
    || fail "the pinned toolchain's rustfmt will not run: $bin/rustfmt
  Repair it with: rustup component add rustfmt --toolchain $ch"
  print -r -- "$bin"
}

# The directory in the app bundle that holds the bundled CLI and its code-mode
# host. Newer Desktop builds keep them in codex-cli/bin; older ones kept them
# directly in Resources.
boss_bundle_bin() {
  local dir
  for dir in "$APP/Contents/Resources/codex-cli/bin" "$APP/Contents/Resources"; do
    [[ -x "$dir/codex" ]] && { print -r -- "$dir"; return 0; }
  done
  print -r -- "$APP/Contents/Resources/codex-cli/bin"
}

# The version of the CLI the installed Desktop ships. Boss should match it, so
# the Desktop app talks to the CLI version it was released with.
boss_bundle_version() {
  local v
  v=$("$(boss_bundle_bin)/codex" --version 2>/dev/null) \
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

# The code-mode host links V8 built with pointer compression and the sandbox.
# The v8 crate only knows its own release page, which does not carry that
# variant, so point it at the copies OpenAI publishes for Codex, checked against
# the checksums pinned in the upstream checkout. Prints the two variables for
# env(1), or nothing when the caller already chose (V8_FROM_SOURCE, or both
# RUSTY_V8_* set).
boss_v8_env() {
  [[ "${V8_FROM_SOURCE:-}" == (1|true|yes) ]] && return 0
  [[ -n "${RUSTY_V8_ARCHIVE:-}" && -n "${RUSTY_V8_SRC_BINDING_PATH:-}" ]] && return 0
  local rs="$UPSTREAM_DIR/codex-rs" version triple profile=ptrcomp_sandbox_release
  version=$(awk '$0=="name = \"v8\"" {getline; gsub(/version = |"/, ""); print; exit}' "$rs/Cargo.lock")
  [[ -n "$version" ]] || fail "cannot find the v8 version in $rs/Cargo.lock"
  case "$(uname -m)" in
    arm64) triple=aarch64-apple-darwin ;;
    x86_64) triple=x86_64-apple-darwin ;;
    *) fail "no published V8 archive for $(uname -m); set V8_FROM_SOURCE=1" ;;
  esac
  local trusted="$UPSTREAM_DIR/third_party/v8/rusty_v8_${version//./_}_release_manifests.sha256"
  [[ -f "$trusted" ]] || fail "no pinned V8 checksums at $trusted"
  local url="https://github.com/openai/codex/releases/download/rusty-v8-v$version"
  local dir="$CARGO_TARGET_DIR/rusty-v8-$version-$triple"
  local manifest="rusty_v8_${profile}_${triple}.sha256"
  local archive="librusty_v8_${profile}_${triple}.a.gz"
  local binding="src_binding_${profile}_${triple}.rs"
  mkdir -p "$dir"

  # name, expected sha256
  _boss_v8_fetch() {
    local file="$dir/$1" want="$2"
    [[ -f "$file" && "$(shasum -a 256 "$file" | cut -d' ' -f1)" == "$want" ]] && return 0
    curl -fsSL --retry 3 -o "$file.part" "$url/$1" || fail "could not download $url/$1"
    [[ "$(shasum -a 256 "$file.part" | cut -d' ' -f1)" == "$want" ]] \
      || { rm -f "$file.part"; fail "checksum mismatch for $1"; }
    mv "$file.part" "$file"
  }
  local want
  want=$(awk -v n="$manifest" '$2==n {print $1}' "$trusted")
  [[ -n "$want" ]] || fail "$trusted has no entry for $manifest"
  _boss_v8_fetch "$manifest" "$want"
  for name in "$archive" "$binding"; do
    want=$(awk -v n="$name" '$2==n {print $1}' "$dir/$manifest")
    [[ -n "$want" ]] || fail "$manifest has no entry for $name"
    _boss_v8_fetch "$name" "$want"
  done
  print -r -- "RUSTY_V8_ARCHIVE=$dir/$archive"
  print -r -- "RUSTY_V8_SRC_BINDING_PATH=$dir/$binding"
}

boss_build_binary() {
  local tc built v8_env
  tc=$(boss_toolchain_bin)
  boss_check_stray_cache
  boss_check_disk
  v8_env=(${(f)"$(boss_v8_env)"})

  note "building (-j $BOSS_JOBS, nice $BOSS_NICE, disk I/O throttled)"
  note "  toolchain  : $tc"
  note "  target dir : $CARGO_TARGET_DIR"
  note "  This takes a while. Peak memory is roughly 5-6GB, set by the"
  note "  single-threaded LTO link at the end, which -j cannot reduce."

  # Use the pinned rustup binaries directly. Homebrew's rustc/rustfmt may be
  # earlier on PATH and can carry a stale absolute libLLVM dependency; inherited
  # compiler overrides can cause the same mismatch even when cargo is healthy.
  ( cd "$UPSTREAM_DIR/codex-rs" \
    && export PATH="$tc:$PATH" RUSTC="$tc/rustc" RUSTDOC="$tc/rustdoc" \
       RUSTFMT="$tc/rustfmt" \
    && unset RUSTC_WRAPPER \
    && boss_low_pressure "$tc/cargo" \
       build -j "$BOSS_JOBS" --release -p codex-cli --bin codex \
    && boss_low_pressure env "${v8_env[@]}" "$tc/cargo" \
       build -j "$BOSS_JOBS" --release -p codex-code-mode-host --bin codex-code-mode-host ) \
    || fail "build failed; any previously installed Boss binary was left untouched"

  built="$CARGO_TARGET_DIR/release/codex"
  [[ -x "$built" ]] || fail "the build reported success but produced no binary at $built"
  "$built" --version >/dev/null 2>&1 || fail "the freshly built binary will not run: $built"
  built_host="$CARGO_TARGET_DIR/release/codex-code-mode-host"
  [[ -x "$built_host" ]] || fail "the build reported success but produced no code-mode host at $built_host"

  mkdir -p "${BOSS_CLI:h}"
  cp "$built" "$BOSS_CLI"
  # The CLI finds the code-mode host next to itself and talks to it over a
  # protocol that changes between versions, so the host is built from the same
  # source rather than linked from the app bundle, which a Desktop update
  # replaces. Remove first: an older install left a link here, and copying onto
  # it would write into the bundle.
  local host="${BOSS_CLI:h}/codex-code-mode-host"
  rm -f "$host"
  cp "$built_host" "$host"
  # macOS may reject a copied ad-hoc-signed Mach-O at the live path until its
  # signature is refreshed. This does not touch the signed Desktop bundle.
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$BOSS_CLI" >/dev/null 2>&1 \
      || fail "could not ad-hoc sign the installed Boss binary at $BOSS_CLI"
    codesign --force --sign - "$host" >/dev/null 2>&1 \
      || fail "could not ad-hoc sign the installed code-mode host at $host"
  fi

  local installed_version
  installed_version=$("$BOSS_CLI" --version) \
    || fail "the installed Boss binary will not run: $BOSS_CLI"
  note ""
  note "installed ${installed_version##* } -> $BOSS_CLI"
  note "  A running Codex Desktop still holds the previous binary. Nothing was"
  note "  restarted. Launch Boss Mode with bin/codex-boss whenever it suits you."
}
