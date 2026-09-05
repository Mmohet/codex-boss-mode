#!/bin/zsh
# Build a patched Codex CLI matching the Codex Desktop you have installed.
#
# The patch is small and touches slow-moving seams, so it three-way applies
# across a range of upstream versions rather than only its own baseline. This
# script therefore targets *your installed version*, applies the nearest patch
# set to it, and only stops if the merge actually fails. The signed app bundle
# is never modified; the patched binary is staged next to a link to the stock
# code-mode host and loaded through CODEX_CLI_PATH by bin/codex-boss.
set -euo pipefail
SCRIPT_NAME=build
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
source "$REPO_ROOT/scripts/common.sh"

# Target the installed Desktop, not the patch's baseline. Overridable for
# deliberately building a mismatched pair.
if [[ -n "${BOSS_TARGET:-}" ]]; then
  TARGET="$BOSS_TARGET"
else
  TARGET="rust-v$(boss_bundle_version)"
fi

# Nearest patch set: an exact match if this repo has one, otherwise the newest.
if [[ -d "$REPO_ROOT/patches/$TARGET" ]]; then
  PATCH_SET="$TARGET"
else
  PATCH_SET="$(ls "$REPO_ROOT/patches" | sort -V | tail -1)"
  [[ -n "$PATCH_SET" ]] || fail "no patch sets in $REPO_ROOT/patches"
fi
PATCH_DIR="$REPO_ROOT/patches/$PATCH_SET"

note "target      : $TARGET  (from the installed Codex Desktop)"
if [[ "$PATCH_SET" == "$TARGET" ]]; then
  note "patch set   : $PATCH_SET  (exact match)"
else
  note "patch set   : $PATCH_SET  (no exact match; three-way merging onto $TARGET)"
fi

boss_check_stray_cache

# Put the upstream checkout on the target tag. Shallow throughout: the patch is
# applied, never rebased, so no shared history is needed.
if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  note "cloning upstream Codex at $TARGET ..."
  git clone --depth 1 --branch "$TARGET" "$UPSTREAM_URL" "$UPSTREAM_DIR" \
    || fail "could not clone $UPSTREAM_URL at $TARGET
  If that tag does not exist upstream, check what Codex Desktop reports:
    $APP/Contents/Resources/codex --version"
else
  current=$( cd "$UPSTREAM_DIR" && git describe --tags --exact-match HEAD 2>/dev/null || print "" )
  if [[ "$current" != "$TARGET" ]]; then
    note "moving the upstream checkout to $TARGET ..."
    ( cd "$UPSTREAM_DIR" \
      && git fetch --depth 1 --quiet origin "refs/tags/${TARGET}:refs/tags/${TARGET}" ) \
      || fail "could not fetch $TARGET into $UPSTREAM_DIR"
  fi
  # Drop any previous patch application so the merge starts from clean upstream.
  ( cd "$UPSTREAM_DIR" && git reset --hard --quiet "$TARGET" && git clean -fdq -e /codex-rs/target ) \
    || fail "could not reset $UPSTREAM_DIR to $TARGET"
fi

# `git apply -3` needs the blobs the patch was generated against, and a shallow
# clone of the target tag does not have them: without this it silently degrades
# to plain context matching, which cannot merge. Fetch the baseline shallowly.
if [[ "$PATCH_SET" != "$TARGET" ]]; then
  ( cd "$UPSTREAM_DIR" \
    && git fetch --depth 1 --quiet origin "refs/tags/${PATCH_SET}:refs/tags/${PATCH_SET}" ) \
    || note "warning: could not fetch the $PATCH_SET baseline; the merge will fall back to plain context matching"
fi

for p in "$PATCH_DIR"/*.patch; do
  if ! ( cd "$UPSTREAM_DIR" && git apply -3 "$p" ); then
    conflicted=$( cd "$UPSTREAM_DIR" && git diff --name-only --diff-filter=U )
    print -u2 ""
    print -u2 "$SCRIPT_NAME: ${p:t} did not merge onto $TARGET."
    if [[ -n "$conflicted" ]]; then
      print -u2 "  Conflicting files:"
      print -u2 "$conflicted" | sed 's/^/    /'
      print -u2 "  The checkout is left in place with the conflicts, so you can resolve"
      print -u2 "  them in $UPSTREAM_DIR, confirm it builds, and record the result:"
      print -u2 "    mkdir -p patches/$TARGET"
      print -u2 "    (cd upstream && git diff $TARGET -- codex-rs/) > patches/$TARGET/0001-boss-mode.patch"
    fi
    fail "upstream moved further than this patch can follow on its own"
  fi
  note "applied ${p:t}"
done

boss_build_binary

# The patch travelled to a version it was not generated against and the build
# worked. Keep the adapted patch in ignored state by default so a routine
# runtime update does not dirty the public release checkout. Set
# BOSS_RECORD_ADAPTED_PATCH=1 when the adaptation has been reviewed and should
# become a tracked patch set.
if [[ "$PATCH_SET" != "$TARGET" ]]; then
  if [[ "${BOSS_RECORD_ADAPTED_PATCH:-0}" == "1" ]]; then
    adapted_dir="$REPO_ROOT/patches/$TARGET"
    adapted_note="recorded the adapted patch as patches/$TARGET/0001-boss-mode.patch"
    promote_note=""
  else
    adapted_dir="$REPO_ROOT/.boss/state/adapted-patches/$TARGET"
    adapted_note="kept the adapted patch in ignored state at .boss/state/adapted-patches/$TARGET/0001-boss-mode.patch"
    promote_note="  To promote it after review: BOSS_RECORD_ADAPTED_PATCH=1 ./scripts/build.sh"
  fi
  mkdir -p "$adapted_dir"
  ( cd "$UPSTREAM_DIR" && git diff "$TARGET" -- codex-rs/ ) \
    > "$adapted_dir/0001-boss-mode.patch"
  note ""
  note "$adapted_note"
  [[ -n "$promote_note" ]] && note "$promote_note"
fi
