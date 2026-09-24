#!/bin/zsh
# No-spend contract tests for scripts/claude-collab.sh. The mock never contacts
# Claude; the edit fixture is an isolated temporary Git repository.
set -euo pipefail

SCRIPT_NAME=test-claude-collab
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
HELPER="$REPO_ROOT/scripts/claude-collab.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/$SCRIPT_NAME.XXXXXX")"
FIXTURE="$TEST_ROOT/source-fixture"
PACKET="$TEST_ROOT/task-packet.md"
FAKE_DIR="$TEST_ROOT/fake-claude-dir"
WORKTREES=()
BRANCHES=()

fail() { print -u2 "$SCRIPT_NAME: $1"; exit 1 }
cleanup() {
  for worktree in "${WORKTREES[@]}"; do
    git -C "$FIXTURE" worktree remove --force "$worktree" >/dev/null 2>&1 || true
  done
  for branch in "${BRANCHES[@]}"; do
    git -C "$FIXTURE" branch -D "$branch" >/dev/null 2>&1 || true
  done
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

cat > "$TEST_ROOT/fake-claude" <<'PY'
#!/usr/bin/env python3
import json
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parent
args = sys.argv[1:]
environment_names = "\n".join(sorted(__import__("os").environ)) + "\n"

if args == ["--version"]:
    sys.stdout.write((root / "version.txt").read_text() if (root / "version.txt").exists() else "2.1.300 (Claude Code)\n")
    raise SystemExit(0)

if args[:3] == ["auth", "status", "--json"]:
    (root / "auth.called").write_text("called\n")
    (root / "auth.env").write_text(environment_names)
    sys.stdout.write((root / "auth-status.json").read_text())
    raise SystemExit(0)

tools = args[args.index("--tools") + 1]
mode = {"": "consult", "Read": "inspect", "Read,Edit,Write": "edit"}[tools]
(root / f"{mode}.args").write_text(
    f"cwd<{Path.cwd()}>\n" + "".join(f"arg<{arg}>\n" for arg in args)
)
(root / f"{mode}.input").write_text(sys.stdin.read())
(root / f"{mode}.env").write_text(environment_names)

if mode == "edit":
    sleep_mode = (root / "sleep-mode").exists()
    filename = "partial-edit.txt" if sleep_mode else "mock-edited.txt"
    Path(filename).write_text("written only by the fake Claude process\n")
    if sleep_mode:
        time.sleep(3)

print(json.dumps({"type": "result", "result": "mock response"}))
PY
chmod +x "$TEST_ROOT/fake-claude"
mkdir -p "$FAKE_DIR"
cp "$TEST_ROOT/fake-claude" "$FAKE_DIR/claude"
chmod +x "$FAKE_DIR/claude"
print -r -- '{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty","subscriptionType":"pro","email":"test-user@example.invalid","orgName":"Test Org"}' > "$FAKE_DIR/auth-status.json"
print -r -- 'Outcome: get an independent bounded review.' > "$PACKET"

TEST_CODEX_HOME="$TEST_ROOT/codex-home"
mkdir -p "$TEST_CODEX_HOME"
CODEX_HOME="$TEST_CODEX_HOME" "$REPO_ROOT/scripts/install-config.sh" \
  > "$TEST_ROOT/install.out" 2> "$TEST_ROOT/install.err"
[[ -x "$TEST_CODEX_HOME/boss/claude-collab.sh" ]] \
  || fail "config install did not install the collaboration helper"
cmp -s "$HELPER" "$TEST_CODEX_HOME/boss/claude-collab.sh" \
  || fail "config install did not copy the tracked helper exactly"
grep -Fq '## Claude Code collaboration' "$TEST_CODEX_HOME/boss/base.md" \
  || fail "fresh config install omitted the Claude capability guidance from base.md"
! grep -Fq 'claude-collab.sh' "$TEST_CODEX_HOME/boss.config.toml" \
  || fail "fresh config install put Claude tool routing into Main's persona instructions"
! grep -Fq 'claude-collab.sh' "$REPO_ROOT/main.md" \
  || fail "Main contains Claude tool routing instead of keeping it in base.md"
CODEX_HOME="$TEST_CODEX_HOME" "$REPO_ROOT/scripts/sync-profile.sh" \
  > "$TEST_ROOT/sync.out" 2> "$TEST_ROOT/sync.err"
cmp -s "$HELPER" "$TEST_CODEX_HOME/boss/claude-collab.sh" \
  || fail "profile sync did not refresh the installed helper"

assert_mock_json() {
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["type"] == "result" and d["result"] == "mock response"' "$1"
}
has_arg() { grep -Fqx "arg<$1>" "$2"; }
run_clean() {
  local safe_var
  local -a clean_env_args
  clean_env_args=(/usr/bin/env -i "PATH=$PATH" "HOME=$HOME" "TMPDIR=${TMPDIR:-/tmp}")
  for safe_var in LANG LC_ALL LC_CTYPE USER LOGNAME SHELL; do
    if /usr/bin/printenv "$safe_var" >/dev/null 2>&1; then
      clean_env_args+=("$safe_var=$(/usr/bin/printenv "$safe_var")")
    fi
  done
  "${clean_env_args[@]}" "$@"
}
mock_env() {
  local fake_cli="$1"
  shift
  run_clean \
    CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=1 \
    HTTP_PROXY=http://127.0.0.1:9 \
    BOSS_CLAUDE_CLI="$fake_cli" \
    BOSS_CLAUDE_MODEL=claude-opus-5-5 \
    BOSS_CLAUDE_TIMEOUT_SECONDS=30 \
    BOSS_CLAUDE_WORKTREE_ROOT="$TEST_ROOT/worktrees" \
    "$HELPER" "$@"
}

mock_env "$FAKE_DIR/claude" consult "$PACKET" \
  > "$TEST_ROOT/consult.out" 2> "$TEST_ROOT/consult.err" \
  || fail "consult mode failed with fake CLI"
assert_mock_json "$TEST_ROOT/consult.out" || fail "consult did not return valid JSON"
cmp -s "$PACKET" "$FAKE_DIR/consult.input" || fail "consult did not pass the packet on stdin"
[[ -f "$FAKE_DIR/auth.called" ]] || fail "consult omitted the auth-status preflight"
if grep -Fq 'test-user@example.invalid' "$TEST_ROOT/consult.out" "$TEST_ROOT/consult.err" \
  || grep -Fq 'Test Org' "$TEST_ROOT/consult.out" "$TEST_ROOT/consult.err"; then
  fail "auth status identity fields leaked into bridge output"
fi
has_arg --output-format "$FAKE_DIR/consult.args" || fail "consult omitted JSON output mode"
has_arg json "$FAKE_DIR/consult.args" || fail "consult omitted JSON output mode value"
has_arg --max-turns "$FAKE_DIR/consult.args" || fail "consult omitted its one-turn bound"
has_arg 1 "$FAKE_DIR/consult.args" || fail "consult omitted its one-turn bound value"
has_arg --no-session-persistence "$FAKE_DIR/consult.args" || fail "consult omitted session persistence guard"
has_arg --strict-mcp-config "$FAKE_DIR/consult.args" || fail "consult did not disable inherited MCP"
has_arg --restricted "$FAKE_DIR/consult.args" || fail "consult omitted restricted mode"
has_arg --safe-mode "$FAKE_DIR/consult.args" || fail "consult omitted safe mode"
has_arg --tools "$FAKE_DIR/consult.args" || fail "consult omitted explicit tool restriction"
has_arg '' "$FAKE_DIR/consult.args" || fail "consult did not disable all tools"
cmp -s "$FAKE_DIR/auth.env" "$FAKE_DIR/consult.env" \
  || fail "auth preflight and model request did not use the same child environment"
if grep -Eq '^(ANTHROPIC_|CLAUDE_CODE_|HTTP_PROXY$|HTTPS_PROXY$|ALL_PROXY$)' "$FAKE_DIR/consult.env"; then
  fail "provider or proxy environment leaked into the child process"
fi

mock_env "$FAKE_DIR/claude" inspect "$PACKET" "$REPO_ROOT" \
  > "$TEST_ROOT/inspect.out" 2> "$TEST_ROOT/inspect.err" \
  || fail "inspect mode failed with fake CLI"
assert_mock_json "$TEST_ROOT/inspect.out" || fail "inspect did not return valid JSON"
has_arg Read "$FAKE_DIR/inspect.args" || fail "inspect did not restrict tools to Read"
! has_arg 'Read,Edit,Write' "$FAKE_DIR/inspect.args" || fail "inspect unexpectedly received write tools"
grep -Fqx "cwd<$REPO_ROOT>" "$FAKE_DIR/inspect.args" \
  || fail "inspect did not run from the selected repository"

mkdir -p "$FIXTURE"
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name 'Claude collaboration test'
git -C "$FIXTURE" config user.email 'claude-collab-test@example.invalid'
print -r -- 'fixture source' > "$FIXTURE/README.md"
git -C "$FIXTURE" add README.md
git -C "$FIXTURE" commit -q -m 'fixture baseline'
SOURCE_HEAD="$(git -C "$FIXTURE" rev-parse HEAD)"

mock_env "$FAKE_DIR/claude" edit "$PACKET" "$FIXTURE" test-edit \
  > "$TEST_ROOT/edit.out" 2> "$TEST_ROOT/edit.err" \
  || fail "edit mode failed with fake CLI"
assert_mock_json "$TEST_ROOT/edit.out" || fail "edit did not return valid JSON"
WORKTREE="$(sed -n 's/^claude-collab: worktree: //p' "$TEST_ROOT/edit.err" | head -1)"
BRANCH="$(sed -n 's/^claude-collab: branch: //p' "$TEST_ROOT/edit.err" | head -1)"
[[ -n "$WORKTREE" && -d "$WORKTREE" ]] || fail "edit did not leave a reviewable worktree"
[[ -n "$BRANCH" ]] || fail "edit did not report its branch"
WORKTREES+=("$WORKTREE")
BRANCHES+=("$BRANCH")
[[ "$(git -C "$FIXTURE" rev-parse HEAD)" == "$SOURCE_HEAD" ]] || fail "edit changed the source checkout's HEAD"
[[ ! -e "$FIXTURE/mock-edited.txt" ]] || fail "edit wrote into the source checkout"
[[ -f "$WORKTREE/mock-edited.txt" ]] || fail "fake edit was not confined to its isolated worktree"
[[ "$(git -C "$WORKTREE" rev-parse HEAD)" == "$SOURCE_HEAD" ]] || fail "edit committed a change"
has_arg 'Read,Edit,Write' "$FAKE_DIR/edit.args" || fail "edit omitted its limited file tool set"
! has_arg Bash "$FAKE_DIR/edit.args" || fail "edit unexpectedly enabled shell execution"
has_arg --max-turns "$FAKE_DIR/edit.args" || fail "edit omitted its turn bound"
has_arg 8 "$FAKE_DIR/edit.args" || fail "edit omitted its turn bound value"
grep -Fq "$WORKTREE" "$FAKE_DIR/edit.args" || fail "Claude did not run from the isolated worktree"

# A repository-derived parent can be planted as a symlink before edit mode.
# It must fail closed instead of letting Git place the worktree in the source.
SYMLINK_ROOT="$TEST_ROOT/symlink-worktrees"
mkdir -p "$SYMLINK_ROOT"
FIXTURE_CANONICAL="$(cd "$FIXTURE" && pwd -P)"
FIXTURE_ID="$(printf '%s' "$FIXTURE_CANONICAL" | cksum | awk '{print $1}')"
FIXTURE_NAME="$(basename "$FIXTURE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')"
ln -s "$FIXTURE" "$SYMLINK_ROOT/${FIXTURE_NAME}-${FIXTURE_ID}"
rm -f "$FAKE_DIR/auth.called" "$FAKE_DIR/edit.args"
if run_clean \
  BOSS_CLAUDE_CLI="$FAKE_DIR/claude" \
  BOSS_CLAUDE_MODEL=claude-opus-5-5 \
  BOSS_CLAUDE_TIMEOUT_SECONDS=30 \
  BOSS_CLAUDE_WORKTREE_ROOT="$SYMLINK_ROOT" \
  "$HELPER" edit "$PACKET" "$FIXTURE" symlink-parent \
  > "$TEST_ROOT/symlink.out" 2> "$TEST_ROOT/symlink.err"; then
  fail "edit mode accepted a symlinked derived worktree parent"
fi
grep -Fq 'worktree parent must not be a symlink' "$TEST_ROOT/symlink.err" \
  || fail "symlink parent refusal did not explain the reason"
[[ ! -e "$FAKE_DIR/edit.args" ]] || fail "symlink parent refusal invoked a model request"
[[ "$(git -C "$FIXTURE" rev-parse HEAD)" == "$SOURCE_HEAD" ]] \
  || fail "symlink parent refusal changed the source checkout"
[[ -z "$(git -C "$FIXTURE" worktree list --porcelain | grep -F "$SYMLINK_ROOT" || true)" ]] \
  || fail "symlink parent refusal placed a worktree under the redirected path"

OLD_VERSION_DIR="$TEST_ROOT/old-version-claude"
mkdir -p "$OLD_VERSION_DIR"
cp "$TEST_ROOT/fake-claude" "$OLD_VERSION_DIR/claude"
chmod +x "$OLD_VERSION_DIR/claude"
cp "$FAKE_DIR/auth-status.json" "$OLD_VERSION_DIR/auth-status.json"
print -r -- '2.1.274 (Claude Code)' > "$OLD_VERSION_DIR/version.txt"
if mock_env "$OLD_VERSION_DIR/claude" consult "$PACKET" \
  > "$TEST_ROOT/old-version.out" 2> "$TEST_ROOT/old-version.err"; then
  fail "Opus 5.5 mode accepted a CLI older than 2.1.280"
fi
grep -Fq 'does not meet the Opus 5.5 minimum (2.1.280)' "$TEST_ROOT/old-version.err" \
  || fail "old CLI refusal did not explain the minimum version"
grep -Fq 'claude update' "$TEST_ROOT/old-version.err" \
  || fail "old CLI refusal omitted the update command"
[[ ! -e "$OLD_VERSION_DIR/auth.called" ]] \
  || fail "old CLI preflight ran auth/model work before refusing the version"

TIMEOUT_DIR="$TEST_ROOT/timeout-claude"
mkdir -p "$TIMEOUT_DIR"
cp "$TEST_ROOT/fake-claude" "$TIMEOUT_DIR/claude"
chmod +x "$TIMEOUT_DIR/claude"
cp "$FAKE_DIR/auth-status.json" "$TIMEOUT_DIR/auth-status.json"
touch "$TIMEOUT_DIR/sleep-mode"
if run_clean \
  BOSS_CLAUDE_CLI="$TIMEOUT_DIR/claude" \
  BOSS_CLAUDE_MODEL=claude-opus-5-5 \
  BOSS_CLAUDE_TIMEOUT_SECONDS=1 \
  BOSS_CLAUDE_WORKTREE_ROOT="$TEST_ROOT/worktrees" \
  "$HELPER" edit "$PACKET" "$FIXTURE" timeout-edit \
  > "$TEST_ROOT/timeout.out" 2> "$TEST_ROOT/timeout.err"; then
  fail "edit mode did not stop a timed-out fake Claude process"
else
  TIMEOUT_STATUS=$?
fi
[[ "$TIMEOUT_STATUS" == 124 ]] || fail "timeout returned status $TIMEOUT_STATUS instead of 124"
grep -Fq 'timed out after 1s' "$TEST_ROOT/timeout.err" \
  || fail "timeout did not report its wall-clock limit"
TIMEOUT_WORKTREE="$(sed -n 's/^claude-collab: worktree: //p' "$TEST_ROOT/timeout.err" | head -1)"
TIMEOUT_BRANCH="$(sed -n 's/^claude-collab: branch: //p' "$TEST_ROOT/timeout.err" | head -1)"
[[ -n "$TIMEOUT_WORKTREE" && -f "$TIMEOUT_WORKTREE/partial-edit.txt" ]] \
  || fail "timed-out edit did not preserve its partial worktree"
WORKTREES+=("$TIMEOUT_WORKTREE")
BRANCHES+=("$TIMEOUT_BRANCH")

for route_var in \
  ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL \
  CLAUDE_CODE_USE_ANTHROPIC_AWS CLAUDE_CODE_USE_MANTLE \
  CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST ANTHROPIC_AWS_API_KEY \
  ANTHROPIC_AWS_BASE_URL ANTHROPIC_BEDROCK_BASE_URL \
  ANTHROPIC_FOUNDRY_API_KEY ANTHROPIC_VERTEX_BASE_URL \
  AWS_ACCESS_KEY_ID GOOGLE_APPLICATION_CREDENTIALS; do
  rm -f "$FAKE_DIR/auth.called"
  if run_clean "$route_var=route-probe-dummy" \
    BOSS_CLAUDE_CLI="$FAKE_DIR/claude" \
    "$HELPER" consult "$PACKET" > "$TEST_ROOT/route.out" 2> "$TEST_ROOT/route.err"; then
    fail "provider override $route_var was accepted"
  fi
  grep -Fq "$route_var" "$TEST_ROOT/route.err" \
    || fail "provider override refusal omitted variable name $route_var"
  ! grep -Fq 'route-probe-dummy' "$TEST_ROOT/route.err" \
    || fail "provider override value leaked into diagnostics"
  [[ ! -e "$FAKE_DIR/auth.called" ]] || fail "provider override reached Claude auth status"
done

NO_SUB_DIR="$TEST_ROOT/no-subscription-claude"
mkdir -p "$NO_SUB_DIR"
cp "$TEST_ROOT/fake-claude" "$NO_SUB_DIR/claude"
chmod +x "$NO_SUB_DIR/claude"
print -r -- '{"loggedIn":true,"authMethod":"apiKey","apiProvider":"firstParty","subscriptionType":""}' > "$NO_SUB_DIR/auth-status.json"
if mock_env "$NO_SUB_DIR/claude" consult "$PACKET" \
  > "$TEST_ROOT/no-sub.out" 2> "$TEST_ROOT/no-sub.err"; then
  fail "non-subscription auth status was accepted"
fi
grep -Fq 'did not confirm a logged-in first-party Claude.ai subscription' "$TEST_ROOT/no-sub.err" \
  || fail "subscription refusal did not explain the required auth status"
[[ ! -e "$NO_SUB_DIR/consult.args" ]] || fail "non-subscription auth status invoked a model request"

print -r -- 'dirty source change' > "$FIXTURE/uncommitted.txt"
rm -f "$FAKE_DIR/edit.args"
if mock_env "$FAKE_DIR/claude" edit "$PACKET" "$FIXTURE" dirty-source \
  > "$TEST_ROOT/dirty.out" 2> "$TEST_ROOT/dirty.err"; then
  fail "edit mode accepted a dirty source worktree"
fi
grep -Fq 'source worktree is dirty' "$TEST_ROOT/dirty.err" \
  || fail "dirty source refusal did not explain the reason"
[[ ! -e "$FAKE_DIR/edit.args" ]] || fail "dirty source refusal invoked Claude"

print "$SCRIPT_NAME: fake-CLI checks passed; no Claude model request was made"
