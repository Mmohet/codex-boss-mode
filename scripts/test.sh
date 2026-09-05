#!/bin/zsh
# Run the cheap, reproducible checks for a Boss Mode source/runtime pair.
# Add --cargo to run the Codex core configuration tests, which can take a while.
set -euo pipefail

SCRIPT_NAME=test
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
RUN_CARGO=0
[[ "${1:-}" == "--cargo" ]] && RUN_CARGO=1

"$REPO_ROOT/scripts/check-state.sh" --local --allow-public-dirty --repair-mechanical-lock
git -C "$REPO_ROOT" diff --check

MANIFEST="$REPO_ROOT/.boss/workspace.local.toml"
manifest_value() {
  awk -v key="$1" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/^"|"$/, "", $0)
      print $0
      exit
    }
  ' "$MANIFEST"
}

source_checkout="$(manifest_value source_checkout)"
source_branch="$(manifest_value source_branch)"
baseline_tag="$(manifest_value upstream_baseline_tag)"
patch_file="$REPO_ROOT/patches/$baseline_tag/0001-boss-mode.patch"
if [[ -f "$patch_file" ]] && diff -q "$patch_file" <(git -C "$source_checkout" diff --no-ext-diff "$baseline_tag..$source_branch" -- codex-rs) >/dev/null 2>&1; then
  print "$SCRIPT_NAME: patch/source diff agrees"
else
  print -u2 "$SCRIPT_NAME: patch/source diff mismatch"
  exit 1
fi

live_binary="$(manifest_value live_boss_binary)"
if [[ -x "$live_binary" ]]; then
  "$live_binary" --version >/dev/null
  print "$SCRIPT_NAME: live Boss binary runs"
else
  print -u2 "$SCRIPT_NAME: live Boss binary is unavailable; build it before runtime verification"
  exit 1
fi

if (( RUN_CARGO )); then
  toolchain="$(sed -n 's/^channel *= *"\(.*\)"/\1/p' "$source_checkout/codex-rs/rust-toolchain.toml")"
  if ! rustup run "$toolchain" rustc --version >/dev/null 2>&1; then
    print -u2 "$SCRIPT_NAME: pinned Rust toolchain $toolchain is installed but rustc will not start; cargo tests not run"
    exit 2
  fi
  rustc_path="$(rustup which rustc --toolchain "$toolchain")"
  cargo_path="$(rustup which cargo --toolchain "$toolchain")"
  ( cd "$source_checkout/codex-rs" && RUSTC="$rustc_path" "$cargo_path" test -p codex-core --lib boss_flag )
  ( cd "$source_checkout/codex-rs" && RUSTC="$rustc_path" "$cargo_path" test -p codex-models-manager --lib custom_base )
  ( cd "$source_checkout/codex-rs" && RUSTC="$rustc_path" "$cargo_path" test -p codex-models-manager --lib boss_flag )
  "$REPO_ROOT/scripts/check-state.sh" --local --allow-public-dirty --repair-mechanical-lock
else
  print "$SCRIPT_NAME: cargo tests skipped (rerun with --cargo)"
fi

print "$SCRIPT_NAME: checks complete"
