# Verify: Agent Playbook

Run after any change of the matching kind.

| When | Check | Command or steps | Pass looks like |
|---|---|---|---|
| Any skill change | Frontmatter valid | `bash tools/check-skills.sh` | Every line `ok` |
| Any hook change | Hooks and the syntax checker behave as expected | `bash tools/test-hooks.sh` (outside a sandbox that blocks `pwsh`'s profile folders, or the PowerShell case fails) | Every line `ok`, exit 0 |
| Installer change (bash) | Hooks merge into settings without disturbing other entries, idempotently, and uninstall cleanly | `T=$(mktemp -d); mkdir $T/.claude; echo '{"model":"x","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo other"}]}]}}' > $T/.claude/settings.json; HOME=$T bash install/install.sh --execute; HOME=$T bash install/install.sh --execute; jq . $T/.claude/settings.json; HOME=$T bash install/install.sh --uninstall --execute; jq . $T/.claude/settings.json` | One `PreToolUse` Bash entry after two runs, `model` and the other Stop hook kept, `worktree.baseRef` `head`; after uninstall only the guard entry is gone |
| After installing on a machine | Guard is live | New Claude Code session in a scratch repo, ask it to run `git push` | A permission prompt naming "Agent Playbook guard" |
| Any change to distributed files | No personal or machine-specific details | `grep -rnE '(192\.168\.\|\b10\.[0-9]{1,3}\.[0-9]\|172\.(1[6-9]\|2[0-9]\|3[01])\.)' instructions skills install hooks` | No output |
| Any commit | No personal names, accounts or paths anywhere in the repo | `git grep -n -i -E "$(git config user.name \| tr ' ' '\|')\|/home/\|C:\\\\Users" -- . ':!docs/Verify.md'` | No output |
| Installer change (bash) | Works against a throwaway directory | `T=$(mktemp -d); HOME=$T bash install/install.sh --target claude,copilot --execute; grep -R 'User preferences' $T/.claude/agent-playbook.md $T/.copilot/instructions/agent-playbook.instructions.md; HOME=$T bash install/install.sh --target claude,copilot --uninstall --execute; test -f $T/.agent-playbook/user-profile.md` | Install includes the profile in both targets; uninstall removes generated instructions but preserves the local profile |
| Installer change (PowerShell), on Windows | Works against a test folder | `mkdir C:\Temp\pbtest; .\install\install.ps1 -ProfileRoot C:\Temp\pbtest -Target copilot,claude -Mode Execute`, then the same with `-Uninstall` | Skills under `C:\Temp\pbtest\.copilot\skills` and `.claude\skills`; both generated instruction files include the profile; uninstall removes managed instructions but preserves `C:\Temp\pbtest\.agent-playbook\user-profile.md` |
| Installer change | Existing generated instruction files are backed up | Run Execute once, change or add the generated instruction file, then run Execute again | A `<file>.bak-<timestamp>` plain-text copy exists for the previous Claude core or Copilot instruction file |
| After installing on a machine | Claude Code loads the rules | New session, ask "What is the title of working rule 5 in the Agent Playbook core rules?" | Quotes it |
| After installing on a machine | Copilot loads skills | VS Code or Visual Studio Copilot chat, type `/` | `investigate`, `verify` and the others listed |
