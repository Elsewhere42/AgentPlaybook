#!/usr/bin/env bash
# Claude Code PreToolUse hook for the Bash tool. Installed by install/install.sh.
#
# Reads the hook JSON on stdin and answers in one of three ways:
#   - nothing, exit 0      the command goes through the normal permission rules
#   - permissionDecision "ask"   the user is prompted, whatever the permission mode
#   - permissionDecision "deny"  the command is refused and Claude is told why
#
# "ask": git push, history rewrites, discarding work, broad recursive deletes,
#        commands on another machine (ssh, sftp, scp, rsync to host:).
# "deny": a git commit whose changes contain a likely secret or a key/env file.
#         Lower-confidence secret matches ("password = ...") ask instead.
#
# It never prints a matched secret, only the file, line and kind of match.
# Requires jq. If jq is missing it asks for every command rather than failing open.

set -uo pipefail

input="$(cat)"

emit() { # $1 = ask|deny, $2 = reason
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg d "$1" --arg r "$2" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"Agent Playbook guard: jq is not installed, so every command needs approval."}}\n' "$1"
  fi
  exit 0
}

command -v jq >/dev/null 2>&1 || emit ask "jq missing"

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[[ -z "$cmd" ]] && exit 0
[[ -n "$cwd" && -d "$cwd" ]] || cwd="$PWD"

# One segment per simple command, split on ; & | and newlines, so a pattern such as
# "git ... push" can't match across "git status && echo push".
segments="$(printf '%s\n' "$cmd" | sed -E 's/(\|\||&&|[;&|])/\n/g')"

has() { printf '%s\n' "$segments" | grep -qE -e "$1"; }

reasons=()
G='(^|[[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
has "${G}push([[:space:]]|$)"                       && reasons+=("git push publishes commits")
has "${G}reset[[:space:]].*--hard"                  && reasons+=("git reset --hard discards work")
has "${G}rebase([[:space:]]|$)"                     && reasons+=("git rebase rewrites history")
has "${G}commit[[:space:]].*--amend"                && reasons+=("git commit --amend rewrites the last commit")
has "${G}(filter-branch|filter-repo)"               && reasons+=("rewrites repository history")
has "${G}clean[[:space:]]+(-[a-zA-Z]*f|--force)"    && reasons+=("git clean deletes untracked files")
has "${G}branch[[:space:]].*(-D|--delete[[:space:]]+--force)" && reasons+=("git branch -D deletes an unmerged branch")
has "${G}stash[[:space:]]+(drop|clear)"             && reasons+=("git stash drop/clear loses stashed work")
has "${G}checkout[[:space:]]+(.*[[:space:]])?(--[[:space:]]|\.$|\.[[:space:]])" && reasons+=("git checkout of paths discards uncommitted changes")
if has "${G}restore([[:space:]]|$)" && ! has "${G}restore[[:space:]].*--staged" ; then
  reasons+=("git restore discards uncommitted changes")
fi
has "--force([[:space:]]|$)|--force-with-lease"     && has "${G}" && reasons+=("forced git operation")

# Recursive delete of something broad: /, ~, $HOME, .., ., * or a path outside the repo.
rmre='(^|[[:space:]])rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]+-[a-zA-Z-]+)*[[:space:]]+'
if has "${rmre}"; then
  while IFS= read -r seg; do
    [[ "$seg" =~ $rmre ]] || continue
    targets="${seg#*"${BASH_REMATCH[0]}"}"
    set -f; for t in $targets; do
      t="${t//[\"\']/}"
      case "$t" in
        -*) continue ;;
        /|/*|'~'|'~/'*|'$HOME'*|'${HOME}'*|..|../*|.|./|'*'|./'*') reasons+=("recursive delete of '$t'") ;;
      esac
    done; set +f
  done <<< "$segments"
fi

has '(^|[[:space:]])(ssh|sftp|scp)[[:space:]]'      && reasons+=("runs on or copies to another machine")
has '(^|[[:space:]])rsync[[:space:]].*[^[:space:]]+:' && reasons+=("rsync to another machine")

# Secret scan for commits.
if has "${G}commit([[:space:]]|$)"; then
  repo="$cwd"
  if [[ "$cmd" =~ (^|[[:space:]])cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*(\&\&|;) ]]; then
    d="${BASH_REMATCH[2]}"; d="${d/#\~/$HOME}"; [[ "$d" = /* ]] || d="$cwd/$d"; [[ -d "$d" ]] && repo="$d"
  fi
  if [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    d="${BASH_REMATCH[1]}"; d="${d/#\~/$HOME}"; [[ "$d" = /* ]] || d="$cwd/$d"; [[ -d "$d" ]] && repo="$d"
  fi
  if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    files="$( { git -C "$repo" diff --cached --name-only; git -C "$repo" diff --name-only; \
                git -C "$repo" ls-files -o --exclude-standard; } 2>/dev/null | sort -u)"
    deny=(); ask=()
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      case "$(basename "$f")" in
        .env|.env.*|*.pem|*.key|*.p12|*.pfx|*.kdbx|id_rsa|id_ed25519|id_ecdsa|*.keystore)
          case "$f" in *.example|*.sample|*.template) ;; *) deny+=("$f: key or environment file") ;; esac ;;
      esac
    done <<< "$files"
    # Added lines only, from staged, unstaged and new files. Each output line is file<TAB>text.
    added="$( { git -C "$repo" diff --cached -U0 --no-color; git -C "$repo" diff -U0 --no-color; } 2>/dev/null \
      | awk '/^\+\+\+ b\//{f=substr($0,7); n=0; next} /^@@/{split($3,a,/[+,]/); n=a[2]; next} /^\+/{print f":"n"\t"substr($0,2); n++}')"
    while IFS= read -r f; do
      [[ -n "$f" && -f "$repo/$f" ]] || continue
      [[ $(wc -c < "$repo/$f") -lt 1000000 ]] || continue
      grep -Iq . "$repo/$f" 2>/dev/null || continue
      added+=$'\n'"$(awk -v f="$f" '{print f":"NR"\t"$0}' "$repo/$f")"
    done <<< "$(git -C "$repo" ls-files -o --exclude-standard 2>/dev/null)"
    while IFS=$'\t' read -r loc text; do
      [[ -z "$loc" ]] && continue
      if   [[ "$text" =~ -----BEGIN[A-Z\ ]*PRIVATE\ KEY----- ]]; then deny+=("$loc: private key")
      elif [[ "$text" =~ (AKIA|ASIA)[0-9A-Z]{16} ]]; then deny+=("$loc: AWS access key")
      elif [[ "$text" =~ (ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,} ]]; then deny+=("$loc: GitHub token")
      elif [[ "$text" =~ sk-ant-[A-Za-z0-9_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{32,} ]]; then deny+=("$loc: API key")
      elif [[ "$text" =~ xox[abprs]-[A-Za-z0-9-]{10,} ]]; then deny+=("$loc: Slack token")
      elif [[ "$text" =~ eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,} ]]; then ask+=("$loc: JSON web token")
      elif [[ "${text,,}" =~ (password|passwd|secret|token|api[_-]?key|apikey)[\"\']?[[:space:]]*[:=][[:space:]]*[\"\']?([^\"\'[:space:]\<\$\{]{8,}) ]]; then
        ask+=("$loc: looks like a credential assignment")
      fi
    done <<< "$added"
    if (( ${#deny[@]} )); then
      emit deny "Agent Playbook guard: this commit would include likely secrets. Remove them (use the project's .env or secret store, and .gitignore), then commit again. Do not print the values. Found: $(printf '%s; ' "${deny[@]:0:10}")"
    fi
    (( ${#ask[@]} )) && reasons+=("commit may contain secrets: $(printf '%s; ' "${ask[@]:0:10}")")
  fi
fi

if (( ${#reasons[@]} )); then
  emit ask "Agent Playbook guard: $(printf '%s; ' "${reasons[@]}" | sed 's/; $//')"
fi
exit 0
