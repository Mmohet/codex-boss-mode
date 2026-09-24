#!/bin/zsh
# Keep the live Boss prompts and owner-side role in sync with this checkout.
#
# The profile is rewritten as one atomic file after a timestamped backup. The
# developer_instructions block is generated from main.md, and the explicitly
# managed multi-agent prompt fields are copied from boss.config.example.toml. Every
# other TOML setting is copied through unchanged.
set -euo pipefail

SCRIPT_NAME=sync-profile
REPO_ROOT="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PROFILE="${CODEX_BOSS_PROFILE:-boss}"
DEST="$CODEX_HOME/boss"
PROFILE_FILE="$CODEX_HOME/${PROFILE}.config.toml"
SOURCE_TEMPLATE="$REPO_ROOT/boss.config.example.toml"
MANAGED_SECTION="features.multi_agent_v2"
MANAGED_FIELDS=(root_agent_usage_hint_text multi_agent_mode_hint_text subagent_developer_instructions subagent_usage_hint_text)

fail() { print -u2 "$SCRIPT_NAME: $1"; exit 1 }

WORK_DIR=""
PROFILE_TMP=""
cleanup() {
  local exit_status=$?
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
  if [[ -n "$PROFILE_TMP" && -e "$PROFILE_TMP" ]]; then
    rm -f "$PROFILE_TMP"
  fi
  return "$exit_status"
}
trap cleanup EXIT

[[ -d "$CODEX_HOME" ]] || fail "no Codex home at $CODEX_HOME; set CODEX_HOME if it lives elsewhere"
[[ -f "$PROFILE_FILE" && -r "$PROFILE_FILE" ]] \
  || fail "profile missing or unreadable: $PROFILE_FILE; install it with scripts/install-config.sh"
[[ -f "$SOURCE_TEMPLATE" && -r "$SOURCE_TEMPLATE" ]] \
  || fail "repository config template missing or unreadable: $SOURCE_TEMPLATE"
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
cp -p "$REPO_ROOT/scripts/claude-collab.sh" "$WORK_DIR/claude-collab.sh" \
  || fail "could not stage $REPO_ROOT/scripts/claude-collab.sh"

awk 'BEGIN { print "developer_instructions = \"\"\"" }
     { print }
     END { print "\"\"\"" }' \
  "$REPO_ROOT/main.md" > "$WORK_DIR/developer-instructions.block" \
  || fail "could not build the developer_instructions block from main.md"

# Extract only the project-managed prompt fields from the public example. The
# section and block shape are part of the sync contract; refuse an ambiguous or
# malformed template before touching either the live profile or prompt files.
for field in "${MANAGED_FIELDS[@]}"; do
  awk -v field="$field" -v target_section="$MANAGED_SECTION" '
    function table_header(line) {
      return line ~ /^[[:space:]]*\[\[[^]]+\]\][[:space:]]*$/ ||
             line ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/
    }
    function header_name(line, header) {
      header = line
      if (header ~ /^[[:space:]]*\[\[/) {
        sub(/^[[:space:]]*\[\[/, "", header)
        sub(/\]\][[:space:]]*$/, "", header)
      } else {
        sub(/^[[:space:]]*\[/, "", header)
        sub(/\][[:space:]]*$/, "", header)
      }
      return header
    }
    {
      if (inside) {
        if ($0 ~ /^[[:space:]]*"""[[:space:]]*$/) {
          print
          inside = 0
          complete = 1
        } else {
          if (table_header($0) || $0 ~ /^[[:space:]]*(root_agent_usage_hint_text|multi_agent_mode_hint_text|subagent_developer_instructions|subagent_usage_hint_text)[[:space:]]*=/) {
            invalid = 1
          }
          print
        }
        next
      }
      if (table_header($0)) {
        section = header_name($0)
        next
      }
      if ($0 ~ ("^[[:space:]]*" field "[[:space:]]*=")) {
        count++
        opens = ($0 ~ ("^[[:space:]]*" field "[[:space:]]*=[[:space:]]*\\\"\\\"\\\"[[:space:]]*$"))
        if (section != target_section || !opens) {
          invalid = 1
          next
        }
        if (count > 1) {
          invalid = 1
          next
        }
        print
        inside = 1
      }
    }
    END {
      if (inside || count != 1 || !complete || invalid) exit 2
    }
  ' "$SOURCE_TEMPLATE" > "$WORK_DIR/$field.block" \
    || fail "template does not contain exactly one complete $field block in [$MANAGED_SECTION]: $SOURCE_TEMPLATE"
done

MANAGED_TOOL_NAMESPACE="$(awk '
  /^[[:space:]]*tool_namespace[[:space:]]*=/ { count++; line = $0 }
  END { if (count != 1) exit 2; print line }
' "$SOURCE_TEMPLATE")" \
  || fail "template does not contain exactly one tool_namespace in [$MANAGED_SECTION]: $SOURCE_TEMPLATE"

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

# Replace or insert only the managed fields. The live profile may retain
# private settings and extra sections; they pass through this filter unchanged.
awk -v root_block="$WORK_DIR/root_agent_usage_hint_text.block" \
    -v mode_block="$WORK_DIR/multi_agent_mode_hint_text.block" \
    -v worker_block="$WORK_DIR/subagent_developer_instructions.block" \
    -v usage_block="$WORK_DIR/subagent_usage_hint_text.block" \
    -v target_section="$MANAGED_SECTION" '
  function load_block(path, name, line) {
    while ((getline line < path) > 0) {
      block[name, ++block_count[name]] = line
    }
    close(path)
    if (block_count[name] == 0) invalid = 1
  }
  function table_header(line) {
    return line ~ /^[[:space:]]*\[\[[^]]+\]\][[:space:]]*$/ ||
           line ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/
  }
  function header_name(line, header) {
    header = line
    if (header ~ /^[[:space:]]*\[\[/) {
      sub(/^[[:space:]]*\[\[/, "", header)
      sub(/\]\][[:space:]]*$/, "", header)
    } else {
      sub(/^[[:space:]]*\[/, "", header)
      sub(/\][[:space:]]*$/, "", header)
    }
    return header
  }
  function field_assignment(field, line) {
    return line ~ ("^[[:space:]]*" field "[[:space:]]*=")
  }
  function field_open(field, line) {
    return line ~ ("^[[:space:]]*" field "[[:space:]]*=[[:space:]]*\\\"\\\"\\\"[[:space:]]*$")
  }
  function managed_assignment(line) {
    return line ~ /^[[:space:]]*(root_agent_usage_hint_text|multi_agent_mode_hint_text|subagent_developer_instructions|subagent_usage_hint_text)[[:space:]]*=/
  }
  function out(line) {
    print line
    last_blank = (line ~ /^[[:space:]]*$/)
  }
  function emit_block(field, i) {
    for (i = 1; i <= block_count[field]; i++) out(block[field, i])
  }
  function emit_missing(i, field) {
    for (i = 1; i <= field_count; i++) {
      field = fields[i]
      if (!present[field]) {
        if (!last_blank) out("")
        emit_block(field)
        present[field] = 1
      }
    }
  }
  BEGIN {
    fields[1] = "root_agent_usage_hint_text"
    fields[2] = "multi_agent_mode_hint_text"
    fields[3] = "subagent_developer_instructions"
    fields[4] = "subagent_usage_hint_text"
    field_count = 4
    load_block(root_block, fields[1])
    load_block(mode_block, fields[2])
    load_block(worker_block, fields[3])
    load_block(usage_block, fields[4])
  }
  {
    if (inside_field != "") {
      if ($0 ~ /^[[:space:]]*"""[[:space:]]*$/) {
        inside_field = ""
      } else if (table_header($0) || managed_assignment($0)) {
        invalid = 1
      }
      next
    }

    if (table_header($0)) {
      next_table = header_name($0)
      if (in_target && next_table != target_section) {
        emit_missing()
        in_target = 0
      }
      if (next_table == target_section) {
        target_count++
        if (target_count > 1) invalid = 1
        in_target = 1
      } else {
        in_target = 0
      }
      out($0)
      next
    }

    for (i = 1; i <= field_count; i++) {
      field = fields[i]
      if (!field_assignment(field, $0)) continue

      if (present[field]) {
        invalid = 1
        out($0)
        if (field_open(field, $0)) inside_field = field
        next
      }
      if (!in_target || !field_open(field, $0)) {
        invalid = 1
        out($0)
        if (field_open(field, $0)) inside_field = field
        next
      }

      emit_block(field)
      present[field] = 1
      inside_field = field
      next
    }
    out($0)
  }
  END {
    if (inside_field != "") invalid = 1
    if (in_target) {
      emit_missing()
    } else if (target_count == 0) {
      if (NR > 0 && !last_blank) out("")
      out("[" target_section "]")
      emit_missing()
    }
    if (invalid || target_count > 1) exit 2
  }
' "$PROFILE_TMP" > "$WORK_DIR/profile-with-managed-prompts.toml" \
  || fail "profile does not contain valid managed prompt fields in [$MANAGED_SECTION]: $PROFILE_FILE"

mv -f "$WORK_DIR/profile-with-managed-prompts.toml" "$PROFILE_TMP" \
  || fail "could not stage managed prompt fields in $PROFILE_FILE"

awk -v target_header="[$MANAGED_SECTION]" -v managed_line="$MANAGED_TOOL_NAMESPACE" '
  {
    if ($0 ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/) {
      if (in_target && !seen) print managed_line
      in_target = ($0 == target_header)
      print
      next
    }
    if (in_target && $0 ~ /^[[:space:]]*tool_namespace[[:space:]]*=/) {
      count++
      if (count > 1) invalid = 1
      if (!seen) print managed_line
      seen = 1
      next
    }
    print
  }
  END {
    if (in_target && !seen) print managed_line
    if (invalid) exit 2
  }
' "$PROFILE_TMP" > "$WORK_DIR/profile-with-tool-namespace.toml" \
  || fail "profile contains duplicate tool_namespace fields in [$MANAGED_SECTION]: $PROFILE_FILE"

mv -f "$WORK_DIR/profile-with-tool-namespace.toml" "$PROFILE_TMP" \
  || fail "could not stage tool_namespace in $PROFILE_FILE"

# The [boss] table and its subtables (knobs and model-facing runtime text) are
# owned by the template: drop whatever the live profile has for them and append
# the template's copy. Header-looking lines inside multi-line strings are text,
# not tables, so the scan tracks which string delimiter is open.
BOSS_SECTIONS_AWK='
  function toggles(line, delim,   rest, n) {
    rest = line
    n = 0
    while ((i = index(rest, delim)) > 0) {
      n++
      rest = substr(rest, i + length(delim))
    }
    return n % 2
  }
  {
    if (open_delim != "") {
      if (toggles($0, open_delim)) open_delim = ""
      if (boss == want) print
      next
    }
    if ($0 ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/) {
      name = $0
      sub(/^[[:space:]]*\[/, "", name)
      sub(/\][[:space:]]*$/, "", name)
      boss = (name == "boss" || index(name, "boss.") == 1)
    }
    if (toggles($0, "\047\047\047")) open_delim = "\047\047\047"
    else if (toggles($0, "\"\"\"")) open_delim = "\"\"\""
    if (boss == want) print
  }
  END { if (open_delim != "") exit 2 }
'
awk -v want=1 "$BOSS_SECTIONS_AWK" "$SOURCE_TEMPLATE" > "$WORK_DIR/boss-sections.toml" \
  || fail "template has an unterminated multi-line string: $SOURCE_TEMPLATE"
[[ -s "$WORK_DIR/boss-sections.toml" ]] \
  || fail "template does not contain a [boss] table: $SOURCE_TEMPLATE"
awk -v want=0 "$BOSS_SECTIONS_AWK" "$PROFILE_TMP" > "$WORK_DIR/profile-without-boss.toml" \
  || fail "profile has an unterminated multi-line string: $PROFILE_FILE"
{
  awk '{ lines[NR] = $0; if ($0 !~ /^[[:space:]]*$/) last = NR }
       END { for (i = 1; i <= last; i++) print lines[i] }' "$WORK_DIR/profile-without-boss.toml"
  print
  cat "$WORK_DIR/boss-sections.toml"
} \
  > "$PROFILE_TMP" \
  || fail "could not stage the [boss] tables in $PROFILE_FILE"

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
mv -f "$WORK_DIR/claude-collab.sh" "$DEST/claude-collab.sh" \
  || fail "could not atomically install $DEST/claude-collab.sh"
mv -f "$PROFILE_TMP" "$PROFILE_FILE" \
  || fail "could not atomically install $PROFILE_FILE"
PROFILE_TMP=""

print "$SCRIPT_NAME: synced $DEST/base.md, $DEST/main.md, and $DEST/claude-collab.sh"
print "$SCRIPT_NAME: updated developer_instructions, tool_namespace, root_agent_usage_hint_text, multi_agent_mode_hint_text, subagent_developer_instructions, subagent_usage_hint_text, and the [boss] tables in $PROFILE_FILE"
print "$SCRIPT_NAME: profile backup: $BACKUP"
