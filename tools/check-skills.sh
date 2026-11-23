#!/usr/bin/env bash
# Check every skills/<name>/SKILL.md against the Agent Skills rules shared by Claude Code,
# VS Code and Visual Studio: frontmatter present, name matches the folder, name is lowercase
# letters, digits and hyphens (max 64), description present (max 1024 characters).
# Read-only. Run from anywhere:  bash tools/check-skills.sh
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
for f in "$repo"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$f")")"
  front="$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}' "$f")"
  name="$(printf '%s\n' "$front" | sed -n 's/^name: *//p' | head -1)"
  desc="$(printf '%s\n' "$front" | sed -n 's/^description: *//p' | head -1)"
  problems=()
  [[ -z "$front" ]] && problems+=("no frontmatter")
  [[ "$name" != "$dir" ]] && problems+=("name '$name' doesn't match folder")
  [[ ! "$name" =~ ^[a-z0-9-]{1,64}$ ]] && problems+=("name has invalid characters or is too long")
  [[ -z "$desc" ]] && problems+=("no description")
  (( ${#desc} > 1024 )) && problems+=("description is ${#desc} characters (max 1024)")
  # A ': ' or ' #' inside an unquoted value breaks strict YAML parsers (VS Code reports
  # "Nested mappings are not allowed in compact mappings").
  if [[ ! "$desc" =~ ^[\"\'] ]] && [[ "$desc" == *": "* || "$desc" == *" #"* ]]; then
    problems+=("description has ': ' or ' #' unquoted (invalid YAML); reword or quote it")
  fi
  if (( ${#problems[@]} )); then echo "FAIL $dir: ${problems[*]}"; fail=1; else echo "ok   $dir (${#desc} chars)"; fi
done
exit $fail
