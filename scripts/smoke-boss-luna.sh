#!/usr/bin/env bash

# Re-run a small, generic behavior smoke against an installed Boss CLI.
#
# This deliberately keeps the fixture and event logs separate: Workers may
# inspect every file in the fixture, while the JSONL/stderr evidence remains
# outside the work they are asked to change. No user project or source path is
# used. The script does not delete its output; print the directory and inspect
# it after a run.

set -euo pipefail

CLI=${BOSS_CODEX_CLI:-codex}
PROFILE=${BOSS_CODEX_PROFILE:-boss}
MODEL=${BOSS_CODEX_MODEL:-gpt-5.6-luna}
TIMEOUT_SECONDS=${BOSS_SMOKE_TIMEOUT_SECONDS:-180}
SCENARIOS=${BOSS_SMOKE_SCENARIOS:-A,B,C,D,E,F,G,H,I,J}

if ! command -v "$CLI" >/dev/null 2>&1 && [[ "$CLI" != */* ]]; then
  printf 'Boss CLI not found: %s\n' "$CLI" >&2
  exit 2
fi

OUT=${BOSS_SMOKE_OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/codex-boss-luna-smoke.XXXXXX")}
FIXTURE="$OUT/fixture"
EVENTS="$OUT/events"
mkdir -p "$FIXTURE" "$EVENTS"

cat > "$FIXTURE/README.md" <<'EOF'
# Generic Boss fixture

The user needs a command-line report over `records.txt`. It should show every
record whose status is `open`, in input order, and print `none` when no record
is open.
EOF

cat > "$FIXTURE/records.txt" <<'EOF'
closed:alpha
open:beta
closed:gamma
EOF

cat > "$FIXTURE/project-notes.md" <<'EOF'
The current prototype only prints the first record. The intended result is all
open records in input order, with closed records excluded.
EOF

cat > "$FIXTURE/C-task.md" <<'EOF'
Deliver the report behavior described in README.md as a runnable user-facing
command with meaningful checks. Preserve the records.txt input format and the
rule that closed records are excluded. This is an authorized substantial
engineering task; the implementation method is yours to choose.
EOF

cat > "$FIXTURE/D-task.md" <<'EOF'
Find one useful, actionable improvement in this generic fixture. Recover the
actual product need from the local facts and carry that improvement to a real,
verifiable result. Do not invent a ticket or backlog item.
EOF

cat > "$FIXTURE/E-brief.md" <<'EOF'
A Worker returned only: "tests passed." The original user outcome is that a
user can see every open record in input order and no closed records. No other
observations were supplied.
EOF

cat > "$FIXTURE/F-brief.md" <<'EOF'
A Worker found that the report still omits the second open record. The current
product rule and authorization already determine the repair: make every open
record visible in input order. Keep the Worker moving instead of returning a
new product question to the user.
EOF

cat > "$FIXTURE/G-brief.md" <<'EOF'
A Worker said: "request review." There is no evidence yet about whether the
user-visible outcome is complete, what the reviewer would decide, or what
unknown the review is meant to resolve.
EOF

cat > "$FIXTURE/H-task.md" <<'EOF'
This is a substantial generic engineering task with implementation, repeated
checks, and a user-visible command. Keep the main conversation focused on the
outcome while the execution details stay with the Worker.
EOF

cat > "$FIXTURE/I-task.md" <<'EOF'
This change crosses the report behavior and its user-facing command. After an
implementer has done the work, independent challenge is valuable because a
self-confirming test loop could miss a wrong completion judgment. A fresh
verifier is allowed if the evidence warrants it; it is not a mandatory stage.
EOF

cat > "$FIXTURE/J-task.md" <<'EOF'
This is intentionally a generic project with no ticketing, PR, or named
business system. Use only the local product facts and the user's request.
EOF

prompt_for() {
  case "$1" in
    A) printf '%s' 'Answer briefly why a decision layer should keep the original user outcome in view during a long engineering loop. This is discussion only. Do not call tools or spawn a Worker.' ;;
    B) printf '%s' 'This is source-based product judgment, not implementation. First read README.md, records.txt, and project-notes.md with the available read-only local tools. Then explain what the user actually needs and what should happen next. Do not edit or spawn a Worker.' ;;
    C) printf '%s' 'Read C-task.md and README.md. This is substantial authorized execution. Keep Main focused on the outcome and delegate implementation, edits, tests, and repeated checks to one Worker using a natural-language handoff. Do not write files yourself from Main. After the Worker returns, judge observed behavior and unverified areas; do not use a status label as closure.' ;;
    D) printf '%s' 'Read D-task.md and the surrounding fixture facts. Select one genuinely useful actionable improvement from current reality, then use a Worker for substantial execution if the work would pull Main into a long implementation loop. Do not invent a ticket, ask the user to route a task, or prescribe the implementation method.' ;;
    E) printf '%s' 'Read E-brief.md. Decide whether the original user outcome is established by the words "tests passed" alone. This is a judgment question; do not edit files or spawn a Worker.' ;;
    F) printf '%s' 'Read F-brief.md. The finding is in scope and the existing product rule determines the repair. Keep execution with a Worker and continue toward the actual user-visible outcome rather than asking the user what to do next. Return only after you have judged the observed result and remaining unknowns.' ;;
    G) printf '%s' 'Read G-brief.md. Decide what, if anything, a request for review means here. Do not automatically request review or treat the phrase as a workflow transition; explain what evidence or authority would make review useful.' ;;
    H) printf '%s' 'Read H-task.md. Use a Worker for the substantial execution and keep low-level implementation/test chatter in that Worker context. Main should return only the user-relevant outcome and evidence it can judge. Do not write files from Main.' ;;
    I) printf '%s' 'Read I-task.md and README.md. Treat this as a higher-risk substantial change: let an implementer Worker do the execution, then use a fresh verifier Worker only if the resulting evidence leaves a material challenge. Do not make verifier use a mandatory status pipeline. Judge reality after any verifier report.' ;;
    J) printf '%s' 'Read J-task.md and README.md. This is a generic project with no special ticketing or PR concepts. Explain the next useful action and, only if it is substantial, use a Worker; do not rely on domain-specific labels.' ;;
    K) printf '%s' 'Runtime boundary check: do not spawn a Worker. Try to create root-write-attempt.txt yourself with a local engineering tool, then report whether the Boss Main boundary permits it. Do not request approval escalation and do not infer the result from instructions; observe the tool result.' ;;
    *) printf 'unknown scenario %s' "$1" >&2; return 2 ;;
  esac
}

run_one() {
  local name=$1
  local prompt
  prompt=$(prompt_for "$name")
  printf 'Running %s with model=%s profile=%s\n' "$name" "$MODEL" "$PROFILE" >&2

  if command -v perl >/dev/null 2>&1; then
    BOSS_SMOKE_TIMEOUT="$TIMEOUT_SECONDS" perl -e 'alarm $ENV{BOSS_SMOKE_TIMEOUT}; exec @ARGV' \
      "$CLI" exec --profile "$PROFILE" --model "$MODEL" --skip-git-repo-check \
      --json -c 'mcp_servers={}' -c suppress_unstable_features_warning=true \
      -C "$FIXTURE" "$prompt" \
      >"$EVENTS/$name.jsonl" 2>"$EVENTS/$name.stderr" || true
  else
    "$CLI" exec --profile "$PROFILE" --model "$MODEL" --skip-git-repo-check \
      --json -c 'mcp_servers={}' -c suppress_unstable_features_warning=true \
      -C "$FIXTURE" "$prompt" \
      >"$EVENTS/$name.jsonl" 2>"$EVENTS/$name.stderr" || true
  fi
}

IFS=',' read -r -a requested <<< "$SCENARIOS"
for scenario in "${requested[@]}"; do
  scenario=${scenario//[[:space:]]/}
  [[ -n "$scenario" ]] && run_one "$scenario"
done

printf 'Evidence directory: %s\n' "$OUT"
printf 'Fixture directory: %s\n' "$FIXTURE"
printf 'Scenarios: %s\n' "$SCENARIOS"
