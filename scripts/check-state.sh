#!/bin/zsh
# Diagnose the relationship between the public project, the local source
# checkout, the installed Boss runtime, and the pinned upstream/prompt sources.
# This script is read-only by default. The explicit repair option only backs up
# and restores the exact mechanical Cargo.lock normalization.
set -euo pipefail

SCRIPT_NAME=check-state
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
MANIFEST="${BOSS_WORKSPACE_MANIFEST:-$REPO_ROOT/.boss/workspace.local.toml}"
REMOTE_CHECK=0
ALLOW_PUBLIC_DIRTY=0
REPAIR_MECHANICAL_LOCK=0
DRIFT_COUNT=0

fail() { print -u2 "$SCRIPT_NAME: $1"; exit 1 }
note() { print "$SCRIPT_NAME: $1" }
drift() { DRIFT_COUNT=$((DRIFT_COUNT + 1)); print "$SCRIPT_NAME: DRIFT  $1" }
ok() { print "$SCRIPT_NAME: OK     $1" }
info() { print "$SCRIPT_NAME: INFO   $1" }

while (( $# )); do
  case "$1" in
    --remote) REMOTE_CHECK=1 ;;
    --local) REMOTE_CHECK=0 ;;
    --allow-public-dirty) ALLOW_PUBLIC_DIRTY=1 ;;
    --repair-mechanical-lock) REPAIR_MECHANICAL_LOCK=1 ;;
    -h|--help)
      print "usage: scripts/check-state.sh [--local|--remote] [--allow-public-dirty] [--repair-mechanical-lock]"
      print "  --local   inspect local state only (default)"
      print "  --remote  also query current GitHub branch/tag heads"
      print "  --allow-public-dirty  report public edits without failing the check"
      print "  --repair-mechanical-lock  back up and restore an exact Cargo.lock normalization"
      exit 0
      ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

[[ -f "$MANIFEST" ]] || fail "missing $MANIFEST; copy .boss/workspace.example.toml and fill its paths"

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

need() {
  local key="$1" value
  value="$(manifest_value "$key")"
  [[ -n "$value" ]] || fail "manifest key is empty or missing: $key"
  print -r -- "$value"
}

PUBLIC_REPO="$(need public_repo)"
PUBLIC_REMOTE="$(need public_remote)"
SOURCE_CHECKOUT="$(need source_checkout)"
SOURCE_BRANCH="$(need source_branch)"
UPSTREAM_REMOTE="$(need upstream_remote)"
SOURCE_FORK_REMOTE="$(need source_fork_remote)"
BASELINE_TAG="$(need upstream_baseline_tag)"
BASELINE_COMMIT="$(need upstream_baseline_commit)"
PROJECT_TIMEZONE="$(need project_timezone)"
EXPECTED_LOCK_VERSION="${BASELINE_TAG#rust-v}"
CODEX_HOME_PATH="$(need codex_home)"
DESKTOP_APP="$(need desktop_app)"
LIVE_PROFILE="$(need live_profile)"
LIVE_BOSS_DIR="$(need live_boss_dir)"
LIVE_BOSS_BINARY="$(need live_boss_binary)"
LIVE_HOST="$(need live_code_mode_host)"
LIVE_LAUNCHER="$(need live_launcher)"
PROMPT_REMOTE="$(need prompt_source_remote)"
PROMPT_REVISION="$(need prompt_source_revision)"
PROMPT_BASELINE_PATH="$(need prompt_baseline_path)"
PROMPT_CANDIDATE_PATH="$(need prompt_candidate_path)"

[[ "$PUBLIC_REPO" == "$REPO_ROOT" ]] || drift "manifest public_repo=$PUBLIC_REPO, script repo=$REPO_ROOT"

check_file() {
  local label="$1" path="$2"
  if [[ -f "$path" ]]; then ok "$label: $path"; else drift "$label missing: $path"; fi
}

check_dir() {
  local label="$1" path="$2"
  if [[ -d "$path" ]]; then ok "$label: $path"; else drift "$label missing: $path"; fi
}

sha256_file() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
}

binary_version() {
  "$1" --version 2>/dev/null | tail -1 | sed 's/^.* //'
}

profile_value() {
  awk -v key="$1" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/^[[:space:]]*"|"[[:space:]]*$/, "", $0)
      print $0
      exit
    }
  ' "$LIVE_PROFILE"
}

profile_role_hash() {
  awk '
    /^developer_instructions[[:space:]]*=[[:space:]]*"""[[:space:]]*$/ { inside=1; next }
    inside && /^"""[[:space:]]*$/ { exit }
    inside { print }
  ' "$LIVE_PROFILE" | shasum -a 256 | awk '{print $1}'
}

mechanical_lock_diff_only() {
  git -C "$SOURCE_CHECKOUT" diff --unified=0 -- codex-rs/Cargo.lock 2>/dev/null | awk -v expected="$EXPECTED_LOCK_VERSION" '
    /^diff --git / || /^index / || /^--- / || /^\+\+\+ / || /^@@ / { next }
    /^-version = "0\.0\.0"$/ { removed++; next }
    $0 == "+version = \"" expected "\"" { added++; next }
    { invalid=1 }
    END { exit !(removed > 0 && removed == added && !invalid) }
  '
}

print ""
note "manifest: $MANIFEST"
note "mode: $([[ $REMOTE_CHECK -eq 1 ]] && print remote || print local)"

print ""
note "public project"
check_dir "public checkout" "$PUBLIC_REPO"
public_head=""
if public_head="$(git -C "$PUBLIC_REPO" rev-parse --verify HEAD 2>/dev/null)"; then
  public_branch="$(git -C "$PUBLIC_REPO" branch --show-current 2>/dev/null)"
  public_origin_head="$(git -C "$PUBLIC_REPO" rev-parse --verify refs/remotes/origin/main 2>/dev/null || print none)"
  note "branch=$public_branch head=$public_head origin/main=$public_origin_head"
  public_url="$(git -C "$PUBLIC_REPO" remote get-url origin 2>/dev/null || print none)"
  [[ "$public_url" == "$PUBLIC_REMOTE" ]] && ok "public origin=$public_url" || drift "public origin=$public_url (manifest=$PUBLIC_REMOTE)"
  public_status="$(git -C "$PUBLIC_REPO" status --short --branch 2>/dev/null)"
  public_dirty="$(git -C "$PUBLIC_REPO" status --porcelain 2>/dev/null)"
  if [[ -z "$public_dirty" ]]; then
    ok "public worktree clean"
  elif (( ALLOW_PUBLIC_DIRTY )); then
    info "public worktree has local edits (allowed for this check): ${public_status//$'\\n'/; }"
  else
    drift "public worktree has local changes: ${public_status//$'\\n'/; }"
  fi
else
  drift "public checkout is not a Git repository: $PUBLIC_REPO"
fi

print ""
note "source patch checkout"
check_dir "source checkout" "$SOURCE_CHECKOUT"
source_head=""
if source_head="$(git -C "$SOURCE_CHECKOUT" rev-parse --verify "refs/heads/$SOURCE_BRANCH" 2>/dev/null)"; then
  source_current_branch="$(git -C "$SOURCE_CHECKOUT" branch --show-current 2>/dev/null)"
  source_origin="$(git -C "$SOURCE_CHECKOUT" remote get-url origin 2>/dev/null || print none)"
  source_fork="$(git -C "$SOURCE_CHECKOUT" remote get-url fork 2>/dev/null || print none)"
  note "branch=$source_current_branch head=$source_head origin=$source_origin fork=$source_fork"
  [[ "$source_current_branch" == "$SOURCE_BRANCH" ]] || drift "source branch is $source_current_branch (manifest=$SOURCE_BRANCH)"
  [[ "$source_origin" == "$UPSTREAM_REMOTE" ]] && ok "source origin points at upstream" || drift "source origin=$source_origin (manifest=$UPSTREAM_REMOTE)"
  [[ "$source_fork" == "$SOURCE_FORK_REMOTE" ]] && ok "source fork points at Codex fork" || drift "source fork=$source_fork (manifest=$SOURCE_FORK_REMOTE)"
  fork_local_head="$(git -C "$SOURCE_CHECKOUT" rev-parse --verify "refs/remotes/fork/$SOURCE_BRANCH" 2>/dev/null || print none)"
  [[ "$fork_local_head" == "$source_head" ]] && ok "local fork/$SOURCE_BRANCH matches source HEAD" || drift "local fork/$SOURCE_BRANCH=$fork_local_head (source HEAD=$source_head)"
  baseline_sha="$(git -C "$SOURCE_CHECKOUT" rev-parse "$BASELINE_TAG^{commit}" 2>/dev/null || print none)"
  [[ "$baseline_sha" == "$BASELINE_COMMIT" ]] && ok "baseline $BASELINE_TAG=$baseline_sha" || drift "baseline $BASELINE_TAG=$baseline_sha (manifest=$BASELINE_COMMIT)"
  if git -C "$SOURCE_CHECKOUT" merge-base --is-ancestor "$BASELINE_TAG" "$SOURCE_BRANCH" 2>/dev/null; then
    ok "$SOURCE_BRANCH contains $BASELINE_TAG"
  else
    drift "$SOURCE_BRANCH does not contain $BASELINE_TAG"
  fi
  patch_file="$PUBLIC_REPO/patches/$BASELINE_TAG/0001-boss-mode.patch"
  if [[ -f "$patch_file" ]] && diff -q "$patch_file" <(git -C "$SOURCE_CHECKOUT" diff --no-ext-diff "$BASELINE_TAG..$SOURCE_BRANCH" -- codex-rs) >/dev/null 2>&1; then
    ok "public patch matches source diff for $BASELINE_TAG"
  else
    drift "public patch does not match source diff for $BASELINE_TAG"
  fi
  source_tracked_status="$(git -C "$SOURCE_CHECKOUT" status --short --untracked-files=no 2>/dev/null)"
  if [[ "$source_tracked_status" == ' M codex-rs/Cargo.lock' ]] && mechanical_lock_diff_only; then
    if (( REPAIR_MECHANICAL_LOCK )); then
      state_dir="$REPO_ROOT/.boss/state"
      mkdir -p "$state_dir"
      backup_path="$state_dir/codex-rs-Cargo.lock.$(date +%Y%m%d-%H%M%S).bak"
      cp "$SOURCE_CHECKOUT/codex-rs/Cargo.lock" "$backup_path"
      git -C "$SOURCE_CHECKOUT" restore --worktree -- codex-rs/Cargo.lock
      info "backed up mechanical Cargo.lock diff to $backup_path"
      source_tracked_status=""
      source_status="$(git -C "$SOURCE_CHECKOUT" status --short --ignored 2>/dev/null)"
    else
      drift "source has the exact mechanical Cargo.lock normalization; rerun with --repair-mechanical-lock"
    fi
  else
    source_status="$(git -C "$SOURCE_CHECKOUT" status --short --ignored 2>/dev/null)"
  fi
  if [[ -z "$source_tracked_status" && -z "$source_status" ]]; then
    ok "source worktree clean"
  elif [[ -z "$source_tracked_status" ]]; then
    info "source worktree has ignored build cache(s) only"
  else
    drift "source worktree has changes: ${source_status//$'\\n'/; }"
  fi
else
  drift "source branch missing: $SOURCE_BRANCH"
fi

print ""
note "live Boss files"
check_file "live profile" "$LIVE_PROFILE"
check_dir "live Boss directory" "$LIVE_BOSS_DIR"
check_file "live Boss binary" "$LIVE_BOSS_BINARY"
check_file "live code-mode host link" "$LIVE_HOST"
check_file "live launcher" "$LIVE_LAUNCHER"
check_dir "Codex home" "$CODEX_HOME_PATH"
check_dir "Desktop app" "$DESKTOP_APP"

for artifact in base.md main.md SOURCES.md; do
  live="$LIVE_BOSS_DIR/$artifact"
  tracked="$PUBLIC_REPO/$artifact"
  if [[ -f "$live" && -f "$tracked" ]]; then
    live_sha="$(sha256_file "$live")"
    tracked_sha="$(sha256_file "$tracked")"
    [[ "$live_sha" == "$tracked_sha" ]] && ok "live $artifact matches public artifact ($tracked_sha)" || drift "live $artifact differs from public artifact"
  fi
done

if [[ -f "$LIVE_PROFILE" ]]; then
  instructions_path="$(profile_value model_instructions_file)"
  [[ "$instructions_path" == "$LIVE_BOSS_DIR/base.md" ]] && ok "profile model_instructions_file points at live base" || drift "profile model_instructions_file=$instructions_path"
  role_sha="$(profile_role_hash)"
  main_sha="$(sha256_file "$PUBLIC_REPO/main.md")"
  [[ "$role_sha" == "$main_sha" ]] && ok "profile developer_instructions matches public main.md" || drift "profile developer_instructions differs from public main.md"
  reason_effort="$(profile_value model_reasoning_effort)"
  info "profile model_reasoning_effort=$reason_effort (portable example may choose a different value)"
  for feature in boss_custom_base_replaces_stock boss_hybrid_subagent_base boss_connector_inventory boss_profile_role_survives_host; do
    feature_pattern='^[[:space:]]*'"$feature"'[[:space:]]*=[[:space:]]*true[[:space:]]*$'
    if rg -q "$feature_pattern" "$LIVE_PROFILE"; then
      ok "profile feature $feature=true"
    else
      drift "profile feature $feature is not enabled"
    fi
  done
  if rg -q '^[[:space:]]*subagent_developer_instructions[[:space:]]*=' "$LIVE_PROFILE"; then
    ok "profile has worker role isolation"
  else
    drift "profile is missing worker role isolation"
  fi
fi

boss_version=""
if [[ -x "$LIVE_BOSS_BINARY" ]]; then
  boss_version="$(binary_version "$LIVE_BOSS_BINARY" || print unknown)"
  info "live Boss binary version=$boss_version"
else
  drift "live Boss binary is not executable"
fi
bundle_cli="$DESKTOP_APP/Contents/Resources/codex"
if [[ -x "$bundle_cli" ]]; then
  bundle_version="$(binary_version "$bundle_cli" || print unknown)"
  info "Desktop bundle CLI version=$bundle_version"
  [[ -n "$boss_version" && "$boss_version" == "$bundle_version" ]] && ok "Boss binary and Desktop CLI versions agree" || drift "Boss binary and Desktop CLI versions differ"
else
  drift "Desktop bundle CLI missing: $bundle_cli"
fi

host_target="$(readlink "$LIVE_HOST" 2>/dev/null || print none)"
expected_host="$DESKTOP_APP/Contents/Resources/codex-code-mode-host"
[[ "$host_target" == "$expected_host" ]] && ok "code-mode host link targets the installed Desktop" || drift "code-mode host target=$host_target (expected=$expected_host)"

print ""
note "build and update scripts"
for script in scripts/common.sh scripts/build.sh scripts/update.sh scripts/install-config.sh scripts/check-state.sh scripts/test.sh scripts/prompt-diff.sh bin/codex-boss bin/codex-normal; do
  script_path="$PUBLIC_REPO/$script"
  if [[ -f "$script_path" ]]; then
    if zsh -n "$script_path" >/dev/null 2>&1; then ok "$script parses"; else drift "$script has shell syntax errors"; fi
    case "$script" in
      scripts/*.sh|bin/*) [[ -x "$script_path" ]] && ok "$script is executable" || drift "$script is not executable" ;;
    esac
  else
    drift "missing project script: $script"
  fi
done

if (( REMOTE_CHECK )); then
  print ""
  note "live remote refs (read-only)"
  if remote_main="$(git ls-remote "$PUBLIC_REMOTE" refs/heads/main 2>/dev/null)"; then
    remote_sha="${remote_main%%$'\t'*}"
    info "public origin/main=$remote_sha"
    [[ "$remote_sha" == "$public_head" ]] && ok "local public HEAD matches live origin/main" || drift "local public HEAD=$public_head, live origin/main=$remote_sha"
  else
    drift "could not query public remote"
  fi
  if upstream_main="$(git ls-remote "$UPSTREAM_REMOTE" refs/heads/main 2>/dev/null)"; then
    info "upstream origin/main=${upstream_main%%$'\t'*}"
  else
    drift "could not query upstream main"
  fi
  if fork_branch="$(git ls-remote "$SOURCE_FORK_REMOTE" "refs/heads/$SOURCE_BRANCH" 2>/dev/null)"; then
    fork_remote_sha="${fork_branch%%$'\t'*}"
    info "Codex fork $SOURCE_BRANCH=$fork_remote_sha"
    [[ "$fork_remote_sha" == "$source_head" ]] && ok "remote Codex fork/$SOURCE_BRANCH matches source HEAD" || drift "remote Codex fork/$SOURCE_BRANCH=$fork_remote_sha (source HEAD=$source_head)"
  else
    drift "could not query Codex fork branch $SOURCE_BRANCH"
  fi
  for tag in "$BASELINE_TAG" rust-v0.153.1 rust-v0.153.2 rust-v0.153.3 rust-v0.153.4; do
    if tag_line="$(git ls-remote "$UPSTREAM_REMOTE" "refs/tags/$tag^{}" 2>/dev/null)"; then
      info "upstream $tag=${tag_line%%$'\t'*}"
    elif tag_line="$(git ls-remote "$UPSTREAM_REMOTE" "refs/tags/$tag" 2>/dev/null)"; then
      info "upstream $tag=${tag_line%%$'\t'*} (lightweight tag)"
    else
      drift "could not query upstream tag $tag"
    fi
  done
  if prompt_main="$(git ls-remote "$PROMPT_REMOTE" refs/heads/main 2>/dev/null)"; then
    prompt_sha="${prompt_main%%$'\t'*}"
    info "prompt source main=$prompt_sha"
    [[ "$prompt_sha" == "$PROMPT_REVISION" ]] && ok "prompt source revision is pinned to manifest" || drift "prompt source moved: manifest=$PROMPT_REVISION live=$prompt_sha"
  else
    drift "could not query prompt source"
  fi
  info "project timezone=$PROJECT_TIMEZONE"
  info "prompt baseline=$PROMPT_BASELINE_PATH candidate=$PROMPT_CANDIDATE_PATH"
fi

print ""
if (( DRIFT_COUNT == 0 )); then
  ok "state check complete with no detected drift"
  exit 0
fi
drift "state check complete with $DRIFT_COUNT detected issue(s)"
exit 1
