#!/bin/zsh
# Keep the live Boss prompts and owner-side role in sync with this checkout.
#
# The profile is rewritten as one atomic file after a timestamped backup. Only
# the developer_instructions block is generated from main.md; every other TOML
# setting is copied through unchanged.
set -euo pipefail

SCRIPT_NAME=sync-profile
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PROFILE="${CODEX_BOSS_PROFILE:-boss}"
DEST="$CODEX_HOME/boss"
PROFILE_FILE="$CODEX_HOME/${PROFILE}.config.toml"

fail() { print -u2 "$SCRIPT_NAME: $1"; exit 1 }

WORK_DIR=""
PROFILE_TMP=""
cleanup() {
  local status=$?
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
  if [[ -n "$PROFILE_TMP" && -e "$PROFILE_TMP" ]]; then
    rm -f "$PROFILE_TMP"
  fi
  return "$status"
}
trap cleanup EXIT

[[ -d "$CODEX_HOME" ]] || fail "no Codex home at $CODEX_HOME; set CODEX_HOME if it lives elsewhere"
[[ -f "$PROFILE_FILE" && -r "$PROFILE_FILE" ]] \
  || fail "profile missing or unreadable: $PROFILE_FILE; install it with scripts/install-config.sh"
for prompt in base.md main.md; do
  [[ -f "$REPO_ROOT/$prompt" && -r "$REPO_ROOT/$prompt" ]] \
    || fail "repository prompt missing or unreadable: $REPO_ROOT/$prompt"
done

mkdir -p "$DEST" || fail "could not create live Boss directory: $DEST"
WORK_DIR="$(mktemp -d "$DEST/.sync-profile.XXXXXX")" \
  || fail "could not create a staging directory under $DEST"
PROFILE_TMP="$(mktemp "$CODEX_HOME/.${PROFILE}.config.toml.sync.XXXXXX")" \
  || fail "could not create a profile staging file under $CODEX_HOME"

cp -p "$REPO_ROOT/base.md" "$WORK_DIR/base.md" \
  || fail "could not stage $REPO_ROOT/base.md"
cp -p "$REPO_ROOT/main.md" "$WORK_DIR/main.md" \
  || fail "could not stage $REPO_ROOT/main.md"

awk 'BEGIN { print "developer_instructions = \"\"\"" }
     { print }
     END { print "\"\"\"" }' \
  "$REPO_ROOT/main.md" > "$WORK_DIR/developer-instructions.block" \
  || fail "could not build the developer_instructions block from main.md"

awk -v replacement="$WORK_DIR/developer-instructions.block" '
  BEGIN {
    while ((getline line < replacement) > 0) {
      replacement_lines[++replacement_count] = line
    }
    close(replacement)
  }
  {
    if ($0 ~ /^[[:space:]]*developer_instructions[[:space:]]*=[[:space:]]*"""[[:space:]]*$/) {
      role_count++
      if (role_count > 1) {
        invalid = 1
        next
      }
      for (i = 1; i <= replacement_count; i++) print replacement_lines[i]
      inside = 1
      next
    }
    if (inside) {
      if ($0 ~ /^[[:space:]]*"""[[:space:]]*$/) inside = 0
      next
    }
    print
  }
  END {
    if (invalid || role_count != 1 || inside) exit 2
  }
' "$PROFILE_FILE" > "$PROFILE_TMP" \
  || fail "profile does not contain exactly one complete developer_instructions block: $PROFILE_FILE"

PROFILE_MODE="$(stat -f '%Lp' "$PROFILE_FILE")" \
  || fail "could not read profile permissions: $PROFILE_FILE"
chmod "$PROFILE_MODE" "$PROFILE_TMP" \
  || fail "could not preserve profile permissions on the staged file"

STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$PROFILE_FILE.bak-$STAMP"
BACKUP_SUFFIX=1
while [[ -e "$BACKUP" ]]; do
  BACKUP="$PROFILE_FILE.bak-$STAMP-$BACKUP_SUFFIX"
  BACKUP_SUFFIX=$((BACKUP_SUFFIX + 1))
done
cp -p "$PROFILE_FILE" "$BACKUP" \
  || fail "could not back up profile before updating it: $BACKUP"

# All staged files are on the destination filesystems. Rename each one into
# place; the profile is last so a prompt-file failure leaves the old profile
# selected rather than pointing it at a partially updated set.
mv -f "$WORK_DIR/base.md" "$DEST/base.md" \
  || fail "could not atomically install $DEST/base.md"
mv -f "$WORK_DIR/main.md" "$DEST/main.md" \
  || fail "could not atomically install $DEST/main.md"
mv -f "$PROFILE_TMP" "$PROFILE_FILE" \
  || fail "could not atomically install $PROFILE_FILE"
PROFILE_TMP=""

print "$SCRIPT_NAME: synced $DEST/base.md and $DEST/main.md"
print "$SCRIPT_NAME: updated developer_instructions in $PROFILE_FILE"
print "$SCRIPT_NAME: profile backup: $BACKUP"
