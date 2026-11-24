#!/usr/bin/env bash
# Claude Code Stop hook: run a project's fast check before Claude finishes a turn.
# Installed by install/install.sh. A project turns it on in its own .claude/settings.json:
#
#   {"hooks": {"Stop": [{"hooks": [{"type": "command", "timeout": 600,
#     "command": "\"$HOME/.claude/hooks/agent-playbook/run-check.sh\" 'npm run check && npm test'"}]}]}}
#
# The single argument is run with bash -c at the root of the git checkout Claude is in
# (a worktree, if it's in one). The hook:
#   - does nothing when the checkout has no uncommitted changes, or only Markdown changes
#   - does nothing when the changes are the same as at the last passing check
#   - on failure, blocks the stop and hands Claude the last 60 lines of output to fix
#   - if it fails again with nothing changed since, lets Claude stop and tells the user,
#     so a check Claude can't fix doesn't loop
# If nvm is installed, its default Node (or the version in the project's .nvmrc) is used.
# Set AGENT_CHECK_TIMEOUT (seconds, default 300) to change how long the check may run.

set -uo pipefail

check="${1:-}"
input="$(cat)"
[[ -z "$check" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo '{"systemMessage":"Project check skipped: jq is not installed."}'; exit 0; }

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[[ -n "$cwd" && -d "$cwd" ]] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || exit 0

changed="$( { git -C "$top" diff HEAD --name-only; git -C "$top" ls-files -o --exclude-standard; } 2>/dev/null | sort -u)"
[[ -z "$changed" ]] && exit 0
printf '%s\n' "$changed" | grep -qvE '\.md$' || exit 0

state="${XDG_STATE_HOME:-$HOME/.local/state}/agent-playbook/checks"
mkdir -p "$state"
key="$(printf '%s' "$top" | sha1sum | cut -c1-16)"
fingerprint="$( { printf '%s\n' "$check"; git -C "$top" diff HEAD --no-color; \
  git -C "$top" ls-files -o --exclude-standard -z | (cd "$top" && xargs -0 -r sha1sum); } 2>/dev/null | sha1sum | cut -c1-40)"

[[ -f "$state/$key.pass" && "$(cat "$state/$key.pass")" == "$fingerprint" ]] && exit 0

# Claude Code may have been started without the login shell's setup (from a service, an IDE
# or a desktop shortcut), so a Node version manager isn't loaded. Load nvm's default Node,
# or the project's .nvmrc version, when nvm is installed.
nvm_sh="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
if [[ -s "$nvm_sh" ]]; then
  # shellcheck disable=SC1090
  source "$nvm_sh" --no-use >/dev/null 2>&1 && { if [[ -f "$top/.nvmrc" ]]; then nvm use --silent "$(cat "$top/.nvmrc")" >/dev/null 2>&1; else nvm use --silent default >/dev/null 2>&1; fi; } || true
fi

out="$(cd "$top" && timeout "${AGENT_CHECK_TIMEOUT:-300}" bash -c "$check" 2>&1)"
rc=$?
if [[ $rc -eq 0 ]]; then
  printf '%s' "$fingerprint" > "$state/$key.pass"
  rm -f "$state/$key.fail"
  exit 0
fi

tail_out="$(printf '%s\n' "$out" | tail -n 60)"
[[ $rc -eq 124 ]] && tail_out="(timed out after ${AGENT_CHECK_TIMEOUT:-300} s)"$'\n'"$tail_out"

if [[ -f "$state/$key.fail" && "$(cat "$state/$key.fail")" == "$fingerprint" ]]; then
  jq -n --arg m "Project check still failing (\`$check\`, exit $rc) and nothing changed since the last attempt. Claude stopped without fixing it." \
    '{systemMessage: $m}'
  exit 0
fi
printf '%s' "$fingerprint" > "$state/$key.fail"
jq -n --arg r "The project check failed (\`$check\`, exit $rc). Fix the cause, or if it can't pass for a reason outside your change, tell the user plainly. Last lines of output:
$tail_out" '{decision: "block", reason: $r}'
exit 0
