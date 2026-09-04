#!/bin/zsh
# Bring Boss Mode back in step with a Codex Desktop that updated itself.
#
# Desktop updates replace the bundled CLI and the code-mode host the Boss binary
# links to, leaving an old CLI talking to a new helper. This rebuilds against
# whatever is installed now. It never restarts anything: relaunch when it suits
# you.
set -euo pipefail
SCRIPT_NAME=update
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
source "$REPO_ROOT/scripts/common.sh"

installed=$(boss_bundle_version)
target="rust-v$installed"

current_cli=""
[[ -x "$BOSS_CLI" ]] && current_cli=$("$BOSS_CLI" --version 2>/dev/null | sed 's/.* //')

note "installed Codex Desktop CLI : $installed"
note "current Boss binary         : ${current_cli:-none built yet}"

if [[ -n "$current_cli" && "$current_cli" == "$installed" ]]; then
  note "Already in step. Rebuilding anyway would change nothing; pass BOSS_FORCE=1"
  note "to rebuild regardless (for example after editing the patch)."
  [[ -n "${BOSS_FORCE:-}" ]] || exit 0
fi

if [[ -d "$UPSTREAM_DIR/.git" ]]; then
  print ""
  print "  The upstream checkout at $UPSTREAM_DIR will be reset to $target."
  print "  Any local edits there are discarded; a copy is kept first."
  print -n "  Proceed? [y/N] "
  read -r ans
  [[ "$ans" == [yY] ]] || fail "cancelled; nothing was changed"

  if ! ( cd "$UPSTREAM_DIR" && git diff --quiet && git diff --cached --quiet ); then
    backup="$UPSTREAM_DIR.backup-$(date +%Y%m%d-%H%M%S)"
    cp -R "$UPSTREAM_DIR" "$backup" || fail "could not back up the checkout"
    note "local edits backed up to $backup"
  fi
fi

exec "$REPO_ROOT/scripts/build.sh"
