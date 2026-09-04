#!/bin/zsh
# Lightweight tier: install the Boss prompts and profile overlay only.
#
# No compiler, no patched binary. You get the Boss role, the curated chat base
# as a profile-scoped instruction file, and the worker delegation settings that
# do not require the source patch. Normal Codex is untouched: everything lands
# under a profile that nothing reads unless you select it.
set -euo pipefail
SCRIPT_NAME=install-config
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PROFILE="${CODEX_BOSS_PROFILE:-boss}"
DEST="$CODEX_HOME/boss"
PROFILE_FILE="$CODEX_HOME/${PROFILE}.config.toml"

fail() { print -u2 "$SCRIPT_NAME: $1"; exit 1 }

[[ -d "$CODEX_HOME" ]] || fail "no Codex home at $CODEX_HOME; set CODEX_HOME if it lives elsewhere"

mkdir -p "$DEST"
for f in base.md main.md SOURCES.md; do
  cp "$REPO_ROOT/$f" "$DEST/$f"
  print "$SCRIPT_NAME: installed $DEST/$f"
done

if [[ -e "$PROFILE_FILE" ]]; then
  print -u2 "$SCRIPT_NAME: $PROFILE_FILE already exists; leaving it alone."
  print -u2 "  Compare it against $REPO_ROOT/boss.config.example.toml yourself."
else
  cp "$REPO_ROOT/boss.config.example.toml" "$PROFILE_FILE"
  print "$SCRIPT_NAME: installed $PROFILE_FILE"
fi

# The example references ~/.codex explicitly; fix it up if CODEX_HOME differs.
if [[ "$CODEX_HOME" != "$HOME/.codex" ]]; then
  print -u2 "$SCRIPT_NAME: note: CODEX_HOME is $CODEX_HOME, not ~/.codex."
  print -u2 "  Edit model_instructions_file in $PROFILE_FILE to point at $DEST/base.md"
fi

print ""
print "$SCRIPT_NAME: done. Select the profile to use it:"
print "    codex --profile $PROFILE"
print "  Nothing else changed. Delete $PROFILE_FILE to undo."
print ""
print "  This is the config-only tier. The main agent still runs on the stock"
print "  Codex base underneath, because replacing it requires the source patch."
print "  See the README for the full build."
