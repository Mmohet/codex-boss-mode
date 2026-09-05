#!/bin/zsh
# Compare two prompt captures without importing either into the runtime.
set -euo pipefail

SCRIPT_NAME=prompt-diff
if (( $# != 2 )); then
  print -u2 "usage: scripts/prompt-diff.sh BASELINE CANDIDATE"
  exit 2
fi

baseline="$1"
candidate="$2"
[[ -f "$baseline" ]] || { print -u2 "$SCRIPT_NAME: baseline not found: $baseline"; exit 1; }
[[ -f "$candidate" ]] || { print -u2 "$SCRIPT_NAME: candidate not found: $candidate"; exit 1; }

print "$SCRIPT_NAME: baseline=$baseline"
print "$SCRIPT_NAME: candidate=$candidate"
print "$SCRIPT_NAME: baseline_sha256=$(shasum -a 256 "$baseline" | awk '{print $1}')"
print "$SCRIPT_NAME: candidate_sha256=$(shasum -a 256 "$candidate" | awk '{print $1}')"
print "$SCRIPT_NAME: baseline_lines=$(wc -l < "$baseline" | tr -d ' ')"
print "$SCRIPT_NAME: candidate_lines=$(wc -l < "$candidate" | tr -d ' ')"
print ""

set +e
diff -u -- "$baseline" "$candidate"
diff_rc=$?
set -e
[[ $diff_rc -eq 0 || $diff_rc -eq 1 ]] || exit "$diff_rc"
