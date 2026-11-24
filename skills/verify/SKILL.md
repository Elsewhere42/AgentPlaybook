---
name: verify
description: Prove a change actually works on the real system, not just that the command succeeded. Runs the project's verification checklist if it has one, and offers to write one if it doesn't. Use after any deploy, config change, fix or migration, and before saying something is done.
argument-hint: "[what changed] | init"
---

# Verify

Argument: `$ARGUMENTS`. Use `init` to create or update the project's checklist and fast check without running them.

A successful command, a green build or a passing unit test is not proof that the thing works for the person who uses it. Verification checks the result **where it lands**: the live page, the file on the other machine, the service's real response, the backup's restored copy.

## 1. Find the checklist

Look for `docs/Verify.md`, then a "Verify" or "Verification" section in `DESIGN.md` or the project instructions. If there's none, build checks from step 2 and, at the end, offer to save them as `docs/Verify.md` (format below).

## 2. Choose checks that match the change

Prefer, in order:

1. **End-to-end, as the user sees it:** load the page through its public address, run the app's main path, open the file from the other machine, trigger the automation and see its effect.
2. **The system's own view:** service status and logs after the change, the backup tool's log, the database row, the API response.
3. **Comparison:** the deployed files against the repo (hash or diff), the config on the server against the committed one.
4. **Negative checks:** the thing that should now be refused is refused (old key, closed port, removed account).
5. **Unit and integration tests**, which support the checks above but don't replace them.

Pick checks that would actually fail if the change were wrong. A check that passes whether or not the change worked proves nothing.

## 3. Run them without side effects

Use read-only checks. If a check needs to send a notification, write data, or run a script, say so and ask first. Never run a script with a guessed flag to test it.

## 4. Report honestly

For each check: what you ran, what you expected, what you saw. Then one line each:

- **Verified:** what is now proven to work.
- **Not verified:** what you couldn't check, and why (no access, needs the user's device, needs time to pass, such as tonight's scheduled run).
- **Follow-up:** any check that has to wait, with when to run it. Add it to `DESIGN.md` open items if it might be forgotten.

Never round "probably works" up to "works".

## Checklist format (`docs/Verify.md`)

```markdown
# Verify: <project>

Run after any change of the matching kind. Each check says how to run it and what a pass looks like.

| When | Check | Command or steps | Pass looks like |
|---|---|---|---|
| Any deploy | Live site matches repo | `<command>` | No differences |
| Any deploy | Home page loads through the public address | `curl -sI https://...` | `200`, expected title |
| Config change | Service healthy after restart | `<status command>` | `healthy`, no new errors in last 50 log lines |
| Backup change | Last run succeeded and a file restores | `<steps>` | Restored file opens and matches |
```

Keep checks runnable by a person, not only by an agent. When a check turns out to be wrong or missing after an incident, fix the checklist in the same change.

## Fast check (`init` sets this up too)

The checklist is for proving a change where it lands. The fast check is different: a command that runs in seconds to a minute with no side effects (type check, lint, syntax check, unit tests), so it can run after every piece of work.

1. Find what the project already has: a `check` or `test` script in `package.json`, `dotnet build`/`dotnet test`, `pytest`, `bash -n` and `shellcheck` for shell scripts, an HTML or link checker for static sites. For a repo of scripts and config with no tests, Agent Playbook installs `~/.claude/hooks/agent-playbook/check-syntax.sh`, which parses every shell, Python, JavaScript, JSON, YAML and PowerShell file without running them. Run it once and confirm it passes before adopting it. If nothing fits, propose the smallest useful check rather than none.
2. Record it in the project instructions under "How to work on it" as `- **Check:** \`<command>\``, next to the Verify line pointing at `docs/Verify.md`.
3. In Claude Code, with Agent Playbook's hooks installed, it can run automatically before each turn ends. Add this to the project's `.claude/settings.json` (create or merge; it's committed with the project):

   ```json
   {"hooks": {"Stop": [{"hooks": [{"type": "command", "timeout": 600,
     "command": "\"$HOME/.claude/hooks/agent-playbook/run-check.sh\" '<command>'"}]}]}}
   ```

   The hook runs only when there are uncommitted non-Markdown changes, skips if nothing changed since the last pass, and hands failures back to the agent to fix. Never put a command with side effects (deploys, notifications, writes outside the repo) in it.
