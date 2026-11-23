# Learning Log

Known gotchas to carry from session to session. Add an entry whenever something breaks for a non-obvious reason or an assumption turns out wrong.

## Entry format

```markdown
## L-001: Short title

- **Date:** YYYY-MM-DD
- **What happened:** The symptom, or the assumption that was wrong.
- **Cause:** Why it happened.
- **Next time:** What to do differently.
```

## Learnings


## L-001: Slash-command-only skills are invisible to the agent

- **Date:** 2026-11-22
- **What happened:** After installing, a fresh Claude Code session listed seven of the ten skills and said `pause`, `refresh` and `project-docs` were missing.
- **Cause:** Those three have `disable-model-invocation: true`, so they're left out of the list the model sees. They still run when typed as `/pause`, `/refresh`, `/project-docs`.
- **Next time:** To check those three are installed, look in the skills folder or type `/` in the tool; don't ask the agent.

## L-002: Each tool reads skills from a shared format but rules from its own file

- **Date:** 2026-11-22
- **What happened:** The plan assumed one always-on file could serve all three tools.
- **Cause:** From the vendors' docs (2026-11-22): Claude Code reads `~/.claude/CLAUDE.md` (and `@` imports); VS Code's Copilot harness reads `~/.copilot/copilot-instructions.md` and `~/.copilot/instructions/**/*.instructions.md`; Visual Studio reads `%USERPROFILE%\copilot-instructions.md`, which Copilot memories also write to. Skills: Claude Code `~/.claude/skills`; VS Code Copilot `~/.copilot/skills`; Visual Studio `~/.copilot/skills`, `~/.claude/skills` and `~/.agents/skills`, so a machine with both targets shows each skill twice in Visual Studio.
- **Next time:** Recheck these locations when a tool updates (they changed through 2026). Install only the target each machine needs.

## L-003: Replacing the Visual Studio block added a line break, so a rerun rewrote the file

- **Date:** 2026-11-22
- **What happened:** On Windows, the second `install.ps1 -Mode Execute` against a test profile rewrote `copilot-instructions.md` and made a backup, instead of saying "already current".
- **Cause:** The pattern takes the line break before the block, if any, and the replacement always put one back. A block at the top of the file has none, so the rerun added one. Later runs would have settled, but every first rerun made a needless backup.
- **Next time:** When replacing a matched block, put back exactly what was taken. Test reruns as well as first runs (docs/Verify.md does).

## L-004: A colon in an unquoted skill description broke YAML parsing

- **Date:** 2026-11-22
- **What happened:** VS Code's Markdown preview reported "Nested mappings are not allowed in compact mappings" on `skills/safe-change/SKILL.md`, and `tools/check-skills.sh` had passed it.
- **Cause:** The description held `): investigate`. In an unquoted YAML value, `: ` starts a new key, so strict parsers reject it. The checker read the line with `sed` and never parsed it as YAML.
- **Next time:** Keep descriptions free of `: ` and ` #`, or quote them. The checker now flags both.
