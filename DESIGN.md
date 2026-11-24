# Design: Agent Playbook

The current design. Update this when the design changes. The reasoning behind each choice goes in [DecisionLog.md](DecisionLog.md), and non-obvious problems go in [LearningLog.md](LearningLog.md).

This file never holds secret values, only where they live.

Last updated: 2026-11-24.

## Overview

One set of generic always-on rules plus twelve skills and two Claude Code hooks, written once and installed into each coding agent's user profile on every machine. Each user may add an optional private preferences file, which the installers merge into each tool's generated instructions.

| Path | What it is |
|---|---|
| `instructions/core.md` | The always-on rules. Tool-neutral and machine-neutral |
| `instructions/user-profile.template.md` | Empty starter template for a private per-user preferences file |
| `skills/<name>/SKILL.md` | One skill each, in the Agent Skills format all three tools read |
| `skills/personalize/SKILL.md` | Opt-in interview to create or update a local user profile |
| `skills/script-modes/templates/Invoke-Change.ps1` | DryRun/Execute/Rollback PowerShell template |
| `skills/project-docs/templates/` | AGENTS.md, DESIGN.md and log templates for other repos |
| `hooks/guard-bash.sh` | Claude Code PreToolUse hook for Bash: asks before risky commands, refuses commits with likely secrets (D-012) |
| `hooks/run-check.sh` | Claude Code Stop hook a project enables with its own fast check (D-013) |
| `hooks/check-syntax.sh` | Read-only syntax check of every tracked or new file by type (shell, Python, JS, JSON, YAML, PowerShell); the fast check for script-and-config projects |
| `install/install.sh` | Installer for Linux, WSL, macOS |
| `install/install.ps1` | Installer for Windows |
| `tools/check-skills.sh` | Read-only frontmatter check |
| `tools/test-hooks.sh` | Tests the hooks and `check-syntax.sh` against temporary repos |
| `docs/Verify.md` | Checks to run after a change |

### Skills

| Skill | Agent may start it | Purpose |
|---|---|---|
| `investigate` | Yes | Read-only discovery before changing anything |
| `blast-radius` | Yes | Find dependents before removing or changing something |
| `safe-change` | Yes | Back up, preview, change, verify, document, with rollback |
| `script-modes` | Yes | DryRun/Execute/Rollback scripts, with a PowerShell template |
| `verify` | Yes | Prove it works where it lands; per-project `docs/Verify.md` |
| `self-review` | Yes | Review own diff before commit |
| `log-entry` | Yes | Numbered D-/L- entries, superseding |
| `personalize` | No, slash command only | Create or update optional local user preferences |
| `pause` | No, slash command only | Safe stop and handoff |
| `refresh` | No, slash command only | Re-read docs and report |
| `parallel-work` | Yes | Own worktree and branch per task when sessions run in parallel; merge back when verified (D-014) |
| `project-docs` | Yes, after user approval | Add project memory to a repo, shared or local-only; check for missing defaults at the start of each task and offer setup unless declined |

## Where each tool reads it

Checked against the vendors' docs on 2026-11-22 (L-002).

| Tool | Skills | Always-on rules | Installed by |
|---|---|---|---|
| Claude Code (WSL or Windows) | `~/.claude/skills/` | `~/.claude/CLAUDE.md` imports generated `agent-playbook.md`, including the local user profile | `install.sh` or `install.ps1 -Target claude` |
| Copilot in VS Code | `~/.copilot/skills/` | `~/.copilot/instructions/agent-playbook.instructions.md`, `applyTo: "**"`, including the local user profile | `install.ps1` (Windows) or `install.sh --target copilot` |
| Copilot in Visual Studio 2026 (18.5+) | `~/.copilot/skills/` (also reads `~/.claude/skills/` and `~/.agents/skills/`) | A marked block in `%USERPROFILE%\copilot-instructions.md`, including the local user profile | `install.ps1` |

The installers create `%USERPROFILE%\.agent-playbook\user-profile.md` or `~/.agent-playbook/user-profile.md` from the template if missing. The file is never overwritten or removed by the installer. Updates merge its current text into generated tool instructions; uninstall leaves the profile in place. `install.sh` (Claude target) also copies `hooks/*.sh` to `~/.claude/hooks/agent-playbook/`, registers the Bash guard as a `PreToolUse` entry in `~/.claude/settings.json` (it finds and replaces its own entries by that folder in the command, leaving others alone), sets `worktree.baseRef` to `head` if unset, and adds `.claude/worktrees/` to the global git ignore file. It needs `jq` and skips this with a message if it's missing. `install.ps1` doesn't install hooks yet. Installers copy files rather than linking them (D-002), default to DryRun (D-003), mark each installed skill folder with `.agent-playbook` and touch only marked folders, and back up any existing file they edit as `<file>.bak-<timestamp>`.

## Supported targets

| Environment | Targets |
|---|---|
| WSL or Linux | Claude Code, Copilot CLI |
| macOS | Claude Code, Copilot CLI |
| Windows | Claude Code, VS Code Copilot, Visual Studio Copilot |

## Deploy and rollback

Update: `git pull` in the clone, then the installer with `--execute` / `-Mode Execute`. Rerun the installer after editing the local profile to merge the changes into each tool's instructions. Rollback: check out the previous commit and install again, or uninstall (`--uninstall --execute`, `-Uninstall -Mode Execute`), which removes only marked skills, generated core files, the import line and the Visual Studio block. The private profile remains.

## Accounts and secrets

None. The distributed repository holds no secrets. Machine-specific accounts and credentials belong outside the repository.

## Backups

The repository itself is the source; installed copies are rebuilt from it.

## Open items

| Item | Status |
|---|---|
| Publish the repository publicly | Done 2026-11-22: public repository recreated from a fresh single-commit `main` (D-011) |
| `install.ps1` on Windows | Tested with a temporary test profile; verify on supported Windows installations |
| Hooks on Windows (`install.ps1`) | Not started: hooks are bash; native Windows Claude Code would need PowerShell versions |
| Guard in real use | New 2026-11-24; once installed, watch for false prompts (commit messages that mention `git push`, for example) and tune |
| VS Code Copilot reading `~/.copilot/instructions/` | Documented for the Copilot harness; verify with an installation |

## Future ideas

- An `interrogate`-style second-opinion review that sends a diff to a different local model.
- A `verify` checklist for each supported project type.
