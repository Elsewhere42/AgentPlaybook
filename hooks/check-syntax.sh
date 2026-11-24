#!/usr/bin/env bash
# Syntax-check every tracked or new (not ignored) file in the current git checkout, by type.
# A fast check for projects that are mostly scripts and config with no test suite.
# Read-only: parses files, never runs them, writes nothing.
#
#   check-syntax.sh            # from anywhere inside the repo
#
#   .sh .bash        bash -n
#   .py              Python parser (ast), no __pycache__ written
#   .js .mjs .cjs    node --check (as a module when it uses import/export)
#   .json            JSON parser (tsconfig*.json and .jsonc skipped: they allow comments)
#   .yaml .yml       YAML parser, unknown tags such as !secret or !include allowed
#   .ps1 .psm1 .psd1 PowerShell parser (only if pwsh is installed)
#
# A checker that isn't installed is reported once and skipped; it doesn't fail the check.
# Exit 0 when every file parses, 1 otherwise, listing each failing file.

set -uo pipefail
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "check-syntax: not in a git checkout" >&2; exit 1; }
cd "$top" || exit 1

sh=(); py=(); js=(); json=(); yaml=(); ps=()
while IFS= read -r -d '' f; do
  [[ -f "$f" ]] || continue
  case "$f" in
    */node_modules/*|node_modules/*|*/dist/*|dist/*|*/vendor/*) continue ;;
    *.sh|*.bash) sh+=("$f") ;;
    *.py) py+=("$f") ;;
    *.js|*.mjs|*.cjs) js+=("$f") ;;
    *.json) case "$(basename "$f")" in tsconfig*.json) ;; *) json+=("$f") ;; esac ;;
    *.yaml|*.yml) yaml+=("$f") ;;
    *.ps1|*.psm1|*.psd1) ps+=("$f") ;;
  esac
done < <(git ls-files -z -co --exclude-standard)

fail=0; count=0
bad() { echo "FAIL $1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | head -n 5 | sed 's/^/     /'; fail=1; }
list() { local -n a="$1"; (( ${#a[@]} )) && printf '%s\n' "${a[@]}"; }

for f in "${sh[@]}"; do
  count=$((count+1)); out="$(bash -n "$f" 2>&1)" || bad "$f" "$out"
done

if command -v node >/dev/null 2>&1; then
  for f in "${js[@]}"; do
    count=$((count+1))
    if [[ "$f" == *.mjs ]] || grep -qE '^[[:space:]]*(import[[:space:]{*"'\'']|export[[:space:]])' "$f"; then
      out="$(node --input-type=module --check < "$f" 2>&1)" || bad "$f" "$out"
    else
      out="$(node --check "$f" 2>&1)" || bad "$f" "$out"
    fi
  done
elif (( ${#js[@]} )); then echo "skip JavaScript: node not installed"; fi

if command -v python3 >/dev/null 2>&1; then
  for kind in py json yaml; do
    [[ -n "$(list "$kind")" ]] || continue
    out="$(list "$kind" | python3 -I -c '
import sys, ast, json
kind = sys.argv[1]
files = [f for f in sys.stdin.read().split("\n") if f]
try:
    import yaml
    class L(yaml.SafeLoader): pass
    L.add_multi_constructor("", lambda loader, tag, node: None)
except ImportError:
    yaml = None
if kind == "yaml" and yaml is None:
    print("skip YAML: PyYAML not installed"); sys.exit(0)
bad = 0
for f in files:
    try:
        text = open(f, encoding="utf-8-sig").read()
        if kind == "py": ast.parse(text, f)
        elif kind == "json": json.loads(text)
        else: list(yaml.load_all(text, Loader=L))
    except Exception as e:
        bad = 1; print("FAIL " + f); print("     " + str(e).splitlines()[0][:300])
print("count", len(files))
sys.exit(bad)
' "$kind")" || fail=1
    printf '%s\n' "$out" | grep -v '^count ' || true
    n="$(printf '%s\n' "$out" | sed -n 's/^count //p')"; count=$((count+${n:-0}))
  done
else
  (( ${#py[@]} + ${#json[@]} + ${#yaml[@]} )) && echo "skip Python, JSON and YAML: python3 not installed"
fi

if (( ${#ps[@]} )); then
  if command -v pwsh >/dev/null 2>&1; then
    out="$(list ps | pwsh -NoProfile -NonInteractive -Command '
      $files = [Console]::In.ReadToEnd().Split([char]10) | Where-Object { $_ }
      $bad = 0
      foreach ($f in $files) {
        $errs = $null
        [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$null, [ref]$errs) | Out-Null
        if ($errs) { $bad = 1; "FAIL $f"; $errs | Select-Object -First 3 | ForEach-Object { "     line $($_.Extent.StartLineNumber): $($_.Message)" } }
      }
      "count $($files.Count)"
      exit $bad
    ' 2>&1)" || fail=1
    printf '%s\n' "$out" | grep -v '^count ' || true
    n="$(printf '%s\n' "$out" | sed -n 's/^count //p')"; count=$((count+${n:-0}))
  else
    echo "skip PowerShell: pwsh not installed"
  fi
fi

if [[ $fail -eq 0 ]]; then echo "check-syntax: $count files ok"; else echo "check-syntax: failures above"; fi
exit $fail
