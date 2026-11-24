#!/usr/bin/env bash
# Install or update Agent Playbook for Claude Code and/or GitHub Copilot on Linux, WSL or macOS.
#
#   bash install/install.sh                      # DryRun: show what would change (default)
#   bash install/install.sh --execute            # do it
#   bash install/install.sh --uninstall          # DryRun of removing everything it installed
#   bash install/install.sh --uninstall --execute
#   bash install/install.sh --target claude,copilot --execute
#
# Targets (default: claude):
#   claude   skills -> ~/.claude/skills/<name>/, core rules and local profile -> ~/.claude/agent-playbook.md,
#            and an "@~/.claude/agent-playbook.md" import line in ~/.claude/CLAUDE.md;
#            hooks/*.sh -> ~/.claude/hooks/agent-playbook/, the Bash guard registered in
#            ~/.claude/settings.json, worktree.baseRef "head" if unset, and ".claude/worktrees/"
#            in the global git ignore file (needs jq; skipped with a message if it's missing)
#   copilot  skills -> ~/.copilot/skills/<name>/, core rules and local profile ->
#            ~/.copilot/instructions/agent-playbook.instructions.md (Copilot CLI, VS Code)
#   profile  local preferences -> ~/.agent-playbook/user-profile.md (created once, preserved on uninstall)
#
# Files are copied, not linked. Each installed skill folder holds a .agent-playbook marker;
# only marked folders are ever replaced or removed, so other skills are left alone.
# Any existing file it edits is backed up first as <file>.bak-<timestamp>.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
targets="claude"
execute=0
uninstall=0
marker=".agent-playbook"
stamp="$(date +%Y%m%d-%H%M%S)-$$"
import_line='@~/.claude/agent-playbook.md'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) execute=1 ;;
    --uninstall) uninstall=1 ;;
    --target) targets="${2:?--target needs a value such as claude,copilot}"; shift ;;
    *) echo "Unknown argument: $1 (see the comments at the top of this script)" >&2; exit 1 ;;
  esac
  shift
done

version="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then version="$version+uncommitted"; fi

mode="DryRun"; [[ $execute -eq 1 ]] && mode="Execute"
echo "Agent Playbook $version, $mode, $([[ $uninstall -eq 1 ]] && echo uninstall || echo install), targets: $targets"

do_or_say() { # prints the action; runs it only in Execute mode
  echo "  $*"
  if [[ $execute -eq 1 ]]; then "$@"; fi
}

backup() {
  local f="$1"
  if [[ -e "$f" ]]; then do_or_say cp -p -- "$f" "$f.bak-$stamp"; fi
}

sync_skills() { # $1 = destination skills folder
  local dest="$1" name src d
  [[ $uninstall -eq 0 ]] && do_or_say mkdir -p "$dest"
  # Remove playbook skills that are no longer in the repo (or all of them, on uninstall).
  if [[ -d "$dest" ]]; then
    for d in "$dest"/*/; do
      d="${d%/}"; name="$(basename "$d")"
      [[ -f "$d/$marker" && ! -L "$d" ]] || continue
      if [[ $uninstall -eq 1 || ! -f "$repo/skills/$name/SKILL.md" ]]; then
        do_or_say rm -rf -- "$d"
      fi
    done
  fi
  [[ $uninstall -eq 1 ]] && return 0
  for src in "$repo"/skills/*/; do
    src="${src%/}"; name="$(basename "$src")"
    d="$dest/$name"
    if [[ -L "$d" ]]; then
      echo "  SKIP $name: $d is a symlink from another setup. Remove it, then run again."
      continue
    elif [[ -e "$d" && ! -f "$d/$marker" ]]; then
      echo "  SKIP $name: $d exists and wasn't installed by Agent Playbook."
      continue
    fi
    [[ -e "$d" ]] && do_or_say rm -rf -- "$d"
    do_or_say cp -r -- "$src" "$d"
    echo "  (write $d/$marker)"
    if [[ $execute -eq 1 ]]; then printf 'Installed by Agent Playbook %s from %s on %s\n' "$version" "$repo" "$stamp" > "$d/$marker"; fi
  done
}

install_claude() {
  local home_dir="$HOME/.claude" core="$HOME/.claude/agent-playbook.md" md="$HOME/.claude/CLAUDE.md"
  local profile_dir="$HOME/.agent-playbook" profile="$HOME/.agent-playbook/user-profile.md"
  echo "Claude Code:"
  sync_skills "$home_dir/skills"
  if [[ $uninstall -eq 1 ]]; then
    [[ -f "$core" ]] && do_or_say rm -f -- "$core"
    [[ -f "$profile" ]] && echo "  keep local user profile $profile"
    if [[ -f "$md" ]] && grep -qxF "$import_line" "$md"; then
      backup "$md"
      echo "  remove the line '$import_line' from $md"
      if [[ $execute -eq 1 ]]; then
        # Edit in place through the file (not a rename), so a symlinked CLAUDE.md stays a link.
        local tmp; tmp="$(mktemp)"; grep -vxF "$import_line" "$md" > "$tmp" || true; cat "$tmp" > "$md"; rm -f "$tmp"
      fi
    fi
    return 0
  fi
  if [[ ! -f "$profile" ]]; then
    echo "  create local user profile from template: $profile"
    if [[ $execute -eq 1 ]]; then
      mkdir -p -- "$profile_dir"
      cp -- "$repo/instructions/user-profile.template.md" "$profile"
    fi
  fi
  if [[ $execute -eq 1 ]]; then
    backup "$core"
    { cat "$repo/instructions/core.md"; printf '\n\n---\n\n'; cat "$profile"; } > "$core"
  else
    [[ -e "$core" ]] && backup "$core"
    echo "  write $core (core rules and local user profile)"
  fi
  if [[ -f "$md" ]] && grep -qxF "$import_line" "$md"; then
    echo "  $md already imports the core rules"
  else
    backup "$md"
    echo "  append the line '$import_line' to $md"
    if [[ $execute -eq 1 ]]; then printf '\n%s\n' "$import_line" >> "$md"; fi
  fi
}

install_claude_hooks() {
  # Hooks: copy hooks/*.sh to ~/.claude/hooks/agent-playbook/, register the Bash guard in
  # ~/.claude/settings.json, start worktrees from the local HEAD, and git-ignore worktree folders.
  local dir="$HOME/.claude/hooks/agent-playbook" settings="$HOME/.claude/settings.json"
  local guard_cmd='"$HOME/.claude/hooks/agent-playbook/guard-bash.sh"'
  local ignore
  ignore="$(git config --global core.excludesFile 2>/dev/null || true)"
  ignore="${ignore/#\~/$HOME}"; [[ -n "$ignore" ]] || ignore="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
  echo "Claude Code hooks:"
  if ! command -v jq >/dev/null 2>&1; then
    echo "  SKIP hooks: jq is not installed (sudo apt install jq, or brew install jq), then run again."
    return 0
  fi
  # Remove our entries (matched by the hooks folder in the command) from every hook event.
  local strip='if (.hooks|type)=="object" then .hooks |= (map_values(map(select(([.hooks[]?.command // ""] | any(test("/hooks/agent-playbook/"))) | not))) | with_entries(select(.value|length>0))) | (if .hooks=={} then del(.hooks) else . end) else . end'
  if [[ $uninstall -eq 1 ]]; then
    if [[ -f "$settings" ]] && jq -e '[.hooks[]?[]?.hooks[]?.command // empty | test("/hooks/agent-playbook/")] | any' "$settings" >/dev/null; then
      backup "$settings"
      echo "  remove Agent Playbook hook entries from $settings (worktree.baseRef is left as it is)"
      if [[ $execute -eq 1 ]]; then local tmp; tmp="$(mktemp)"; jq "$strip" "$settings" > "$tmp" && cat "$tmp" > "$settings"; rm -f "$tmp"; fi
    fi
    [[ -d "$dir" ]] && do_or_say rm -rf -- "$dir"
    echo "  keep the '.claude/worktrees/' line in $ignore"
    return 0
  fi
  do_or_say mkdir -p "$dir"
  local f
  for f in "$repo"/hooks/*.sh; do do_or_say install -m 755 -- "$f" "$dir/$(basename "$f")"; done
  [[ -f "$settings" ]] && ! jq -e . "$settings" >/dev/null 2>&1 && { echo "  SKIP settings: $settings isn't valid JSON. Fix it, then run again."; return 0; }
  local cur new
  cur="$( [[ -f "$settings" ]] && cat "$settings" || echo '{}')"
  new="$(printf '%s' "$cur" | jq --arg c "$guard_cmd" "$strip"' | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{matcher: "Bash", hooks: [{type: "command", command: $c, timeout: 30}]}]) | if .worktree.baseRef then . else .worktree.baseRef = "head" end')"
  if [[ "$(printf '%s' "$cur" | jq -S .)" == "$(printf '%s' "$new" | jq -S .)" ]]; then
    echo "  $settings already has the Bash guard hook"
  else
    backup "$settings"
    echo "  register the Bash guard (PreToolUse) in $settings; set worktree.baseRef to \"head\" if unset"
    if [[ $execute -eq 1 ]]; then printf '%s\n' "$new" > "$settings.tmp-$stamp" && cat "$settings.tmp-$stamp" > "$settings"; rm -f "$settings.tmp-$stamp"; fi
  fi
  if [[ -f "$ignore" ]] && grep -qxF '.claude/worktrees/' "$ignore"; then
    echo "  $ignore already ignores .claude/worktrees/"
  else
    [[ -f "$ignore" ]] && backup "$ignore"
    echo "  add '.claude/worktrees/' to the global git ignore file $ignore"
    if [[ $execute -eq 1 ]]; then mkdir -p "$(dirname "$ignore")"; printf '.claude/worktrees/\n' >> "$ignore"; fi
  fi
}

install_copilot() {
  local base="$HOME/.copilot" instr="$HOME/.copilot/instructions/agent-playbook.instructions.md"
  local profile_dir="$HOME/.agent-playbook" profile="$HOME/.agent-playbook/user-profile.md"
  echo "GitHub Copilot:"
  sync_skills "$base/skills"
  if [[ $uninstall -eq 1 ]]; then
    [[ -f "$instr" ]] && do_or_say rm -f -- "$instr"
    [[ -f "$profile" ]] && echo "  keep local user profile $profile"
    return 0
  fi
  do_or_say mkdir -p "$base/instructions"
  if [[ ! -f "$profile" ]]; then
    echo "  create local user profile from template: $profile"
    if [[ $execute -eq 1 ]]; then
      mkdir -p -- "$profile_dir"
      cp -- "$repo/instructions/user-profile.template.md" "$profile"
    fi
  fi
  echo "  write $instr (core rules and local user profile, applyTo all files)"
  if [[ $execute -eq 1 ]]; then
    backup "$instr"
    { printf -- '---\nname: Agent Playbook\ndescription: Core working rules for every project\napplyTo: "**"\n---\n\n'; cat "$repo/instructions/core.md"; printf '\n\n---\n\n'; cat "$profile"; } > "$instr"
  else
    [[ -e "$instr" ]] && backup "$instr"
  fi
}

IFS=',' read -ra list <<< "$targets"
for t in "${list[@]}"; do
  case "$t" in
    claude) install_claude; install_claude_hooks ;;
    copilot) install_copilot ;;
    *) echo "Unknown target: $t (use claude, copilot)" >&2; exit 1 ;;
  esac
done

if [[ $execute -eq 0 ]]; then
  echo
  echo "Nothing was changed. Run again with --execute to apply."
else
  echo
  echo "Done. Start a new session in each tool to pick up the changes."
fi
