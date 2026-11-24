#!/usr/bin/env bash
# Tests for hooks/guard-bash.sh and hooks/run-check.sh. Works only in temporary folders.
# Run from anywhere:  bash tools/test-hooks.sh
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo/hooks/guard-bash.sh"
check="$repo/hooks/run-check.sh"
fail=0
T="$(mktemp -d)"; S="$(mktemp -d)"; trap 'rm -rf "$T" "$S"' EXIT

git -C "$T" init -q -b main
git -C "$T" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init

decision() { # $1 = command; prints none|ask|deny
  local out
  out="$(jq -n --arg c "$1" --arg d "$T" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | bash "$guard")"
  if [[ -z "$out" ]]; then echo none; else printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'; fi
}
expect() { # $1 = expected, $2 = command
  local got; got="$(decision "$2")"
  if [[ "$got" == "$1" ]]; then echo "ok   $1  $2"; else echo "FAIL expected $1, got $got:  $2"; fail=1; fi
}

echo "guard-bash.sh"
expect none 'git status && git diff'
expect none 'git log --oneline | head'
expect none 'echo push'
expect none 'rm -rf node_modules dist'
expect none 'git restore --staged file.txt'
expect none 'git branch -d merged-branch'
expect none 'git worktree add ../x -b x'
expect ask  'git push -u origin main'
expect ask  'cd sub && git push'
expect ask  'git -C ~/projects/x push'
expect ask  'git reset --hard HEAD~1'
expect ask  'git rebase main'
expect ask  'git commit --amend --no-edit'
expect ask  'git clean -fd'
expect ask  'git branch -D old'
expect ask  'git checkout -- file.txt'
expect ask  'git checkout .'
expect ask  'git restore file.txt'
expect ask  'git stash drop'
expect ask  'rm -rf /'
expect ask  'rm -rf *'
expect ask  'rm -rf ./*'
expect ask  'find . -name x && rm -rf .'
expect ask  'rm -rf ~/projects'
expect ask  'rm -r -f ../other'
expect ask  'rm -rf "$HOME"/x'
expect ask  'ssh user@host uptime'
expect ask  'sftp -b batch user@host'
expect ask  'rsync -a dir/ host:/backup/'

echo 'hello' > "$T/notes.txt"
expect none 'git add notes.txt && git commit -m "notes"'
printf 'API_KEY=abcd1234efgh5678\n' > "$T/config.ini"
expect ask  'git add -A && git commit -m config'
rm "$T/config.ini"
printf 'key = "%s"\n' "ghp_$(printf 'a%.0s' {1..36})" > "$T/token.txt"
expect deny 'git add -A && git commit -m token'
rm "$T/token.txt"
touch "$T/.env"
expect deny 'git commit -am env'
rm "$T/.env"
out="$(jq -n --arg d "$T" '{tool_input:{command:"git commit -m x"},cwd:$d}' | bash "$guard")"
mkdir -p "$T/k"; printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nAAAA\n' > "$T/k/deploy"
out="$(jq -n --arg d "$T" '{tool_input:{command:"git add . && git commit -m k"},cwd:$d}' | bash "$guard")"
if printf '%s' "$out" | grep -q 'AAAA'; then echo "FAIL guard printed secret content"; fail=1; else echo "ok   reason doesn't include secret content"; fi
rm -rf "$T/k" "$T/notes.txt"

echo "run-check.sh"
export XDG_STATE_HOME="$S"
stop() { jq -n --arg d "$T" --argjson a "${2:-false}" '{cwd:$d,stop_hook_active:$a}' | bash "$check" "$1"; }
r="$(stop 'false')"; [[ -z "$r" ]] && echo "ok   clean tree: check not run" || { echo "FAIL clean tree ran check: $r"; fail=1; }
echo '# doc' > "$T/README.md"
r="$(stop 'false')"; [[ -z "$r" ]] && echo "ok   Markdown-only change: check not run" || { echo "FAIL Markdown-only ran check"; fail=1; }
echo 'x=1' > "$T/app.sh"
r="$(stop 'echo all good')"; [[ -z "$r" ]] && echo "ok   passing check allows stop" || { echo "FAIL passing check: $r"; fail=1; }
r="$(stop 'echo SHOULD-NOT-RUN; exit 1')"
[[ "$(printf '%s' "$r" | jq -r '.decision // empty')" == block ]] && echo "ok   different command reruns and blocks" || { echo "FAIL changed command: $r"; fail=1; }
r="$(stop 'echo all good')"; [[ -z "$r" ]] && echo "ok   unchanged since pass: skipped" || { echo "FAIL rerun after pass: $r"; fail=1; }
echo 'x=2' > "$T/app.sh"
r="$(stop 'echo broke; exit 3')"
[[ "$(printf '%s' "$r" | jq -r '.decision')" == block ]] && printf '%s' "$r" | jq -r .reason | grep -q broke \
  && echo "ok   failing check blocks with output" || { echo "FAIL failing check: $r"; fail=1; }
r="$(stop 'echo broke; exit 3' true)"
[[ -n "$(printf '%s' "$r" | jq -r '.systemMessage // empty')" && -z "$(printf '%s' "$r" | jq -r '.decision // empty')" ]] \
  && echo "ok   same failure again: lets Claude stop, tells user" || { echo "FAIL repeat failure: $r"; fail=1; }
echo 'x=3' > "$T/app.sh"
r="$(stop 'echo broke; exit 3' true)"
[[ "$(printf '%s' "$r" | jq -r '.decision')" == block ]] && echo "ok   new change, still failing: blocks again" || { echo "FAIL after new change: $r"; fail=1; }

echo "check-syntax.sh"
syn="$repo/hooks/check-syntax.sh"
C="$(mktemp -d)"; git -C "$C" init -q -b main
printf 'echo ok\n' > "$C/a.sh"; printf 'x = 1\n' > "$C/a.py"; printf 'const a = 1;\n' > "$C/a.js"
printf 'import x from "./a.js";\nexport const b = x;\n' > "$C/m.js"; printf '{"a": 1}\n' > "$C/a.json"
printf '// comment\n{"compilerOptions": {}}\n' > "$C/tsconfig.json"; printf 'k: !secret v\nl: [1, 2]\n' > "$C/a.yaml"
mkdir -p "$C/node_modules/x"; printf 'broken(\n' > "$C/node_modules/x/i.js"
pwsh_ok=0; command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -NonInteractive -Command 1 >/dev/null 2>&1 && pwsh_ok=1
[[ $pwsh_ok -eq 1 ]] && printf '$a = 1\n' > "$C/a.ps1"
if (cd "$C" && bash "$syn" >/dev/null); then echo "ok   valid files pass (tsconfig comments, YAML tags, node_modules ignored)"; else echo "FAIL valid files:"; (cd "$C" && bash "$syn"); fail=1; fi
for bad in 'b.sh:if then fi' 'b.py:def (' 'b.js:const = ;' 'c.js:export const = ;' 'b.json:{"a": }' 'b.yaml:a: [1, 2'; do
  f="${bad%%:*}"; printf '%s\n' "${bad#*:}" > "$C/$f"
  if out="$(cd "$C" && bash "$syn" 2>&1)"; then echo "FAIL broken $f not caught"; fail=1
  elif printf '%s' "$out" | grep -q "FAIL $f"; then echo "ok   broken $f caught"; else echo "FAIL broken $f: wrong report: $out"; fail=1; fi
  rm "$C/$f"
done
if [[ $pwsh_ok -eq 1 ]]; then
  printf 'function f( {\n' > "$C/b.ps1"
  out="$(cd "$C" && bash "$syn" 2>&1)"
  if printf '%s\n' "$out" | grep -q 'FAIL b.ps1'; then echo "ok   broken b.ps1 caught"; else echo "FAIL broken b.ps1 not caught"; fail=1; fi
else
  echo "skip PowerShell cases: pwsh not usable here"
fi
rm -rf "$C"

exit $fail
