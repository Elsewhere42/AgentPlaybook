# Agent Playbook

A portable set of working rules and skills for coding agents. Write them once here, install them on any machine, and Claude Code and GitHub Copilot (VS Code and Visual Studio) follow the same workflow: investigate before changing, check what depends on it, back up, preview, verify on the real system, and keep project memory in plain files.

## What's in it

**Core rules**, in [instructions/core.md](instructions/core.md), are loaded into every session. They provide a generic baseline for safe changes, commands, secrets, project memory and communication. An optional private user profile adds preferences chosen by each person.

**Skills** are procedures the agent follows when the task matches, or when you type `/name`:

| Skill | Use it to |
|---|---|
| [investigate](skills/investigate/SKILL.md) | Understand a system or bug, read-only, before changing it |
| [blast-radius](skills/blast-radius/SKILL.md) | Find what depends on something before removing or changing it |
| [safe-change](skills/safe-change/SKILL.md) | Change an existing system: back up, dry run, change, verify, roll back |
| [script-modes](skills/script-modes/SKILL.md) | Write a file-changing script with DryRun, Execute and Rollback modes ([PowerShell template](skills/script-modes/templates/Invoke-Change.ps1)) |
| [verify](skills/verify/SKILL.md) | Prove a change works where it lands, and keep a project's `docs/Verify.md` |
| [self-review](skills/self-review/SKILL.md) | Review your own diff before committing |
| [log-entry](skills/log-entry/SKILL.md) | Add a numbered decision or learning entry |
| [personalize](skills/personalize/SKILL.md) | Create or update a private profile of cross-project working preferences |
| [pause](skills/pause/SKILL.md) | `/pause`: stop safely and leave a handoff |
| [refresh](skills/refresh/SKILL.md) | `/refresh`: re-read the project docs from disk and report where things stand |
| [parallel-work](skills/parallel-work/SKILL.md) | Run a task in its own git worktree and branch, then merge it back when verified |
| [project-docs](skills/project-docs/SKILL.md) | `/project-docs`: add the project files, committed or kept local-only; at the start of every task, missing defaults trigger a setup offer unless declined |

The agent never starts `personalize`, `pause` or `refresh` on its own. `project-docs` starts only after the user explicitly requests setup, approves the offer or invokes it.

## Install

The installers copy files into each tool's user folders. They show what they'd do first and only change anything with `--execute` (bash) or `-Mode Execute` (PowerShell). Run them again any time to update; they replace only what they installed.

### Windows, for Claude Code and Copilot (VS Code and Visual Studio)

`install.ps1` installs for Claude Code running natively on Windows, for GitHub Copilot, or for both. Pick the target with `-Target`:

| You use on this Windows machine | Run |
|---|---|
| Claude Code and Copilot | `-Target claude,copilot` |
| Claude Code only | `-Target claude` |
| Copilot only (the default) | `-Target copilot`, or leave it out |

In PowerShell:

```powershell
cd $HOME\source
git clone https://github.com/OWNER/AgentPlaybook.git
cd AgentPlaybook
.\install\install.ps1 -Target claude,copilot                 # DryRun: shows what would change
.\install\install.ps1 -Target claude,copilot -Mode Execute
```

If PowerShell refuses to run the script, use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install\install.ps1 -Target claude,copilot -Mode Execute`. That bypasses the policy for this one run only.

What each target sets up:

- **Claude Code:** the skills go in `%USERPROFILE%\.claude\skills`, the core rules in `%USERPROFILE%\.claude\agent-playbook.md`, and one import line, `@~/.claude/agent-playbook.md`, is appended to `%USERPROFILE%\.claude\CLAUDE.md`. Start a new Claude Code session to pick them up.
- **Copilot:** the skills go in `%USERPROFILE%\.copilot\skills`, the core rules in VS Code's user instructions folder and in a marked block in Visual Studio's `%USERPROFILE%\copilot-instructions.md`. Restart VS Code and Visual Studio. In Visual Studio, also turn on **Tools > Options > GitHub > Copilot > Copilot Chat > Enable custom instructions to be loaded from .github/copilot-instructions.md files** if it's off. Skills need Visual Studio 2026 version 18.5 or later.

With both targets, Visual Studio lists each skill twice, because it reads the Claude skills folder as well as its own. The two copies are identical, so this is cosmetic.

If Claude Code on this machine runs inside WSL rather than on Windows, use `-Target copilot` here and install for Claude Code from the WSL terminal (next section).

### Optional user profile

The installer creates a starter profile if one does not already exist:

- Windows: `%USERPROFILE%\.agent-playbook\user-profile.md`
- Linux, macOS or WSL: `~/.agent-playbook/user-profile.md`

The profile is local to that user account and machine. Installers include it in each selected tool's generated instructions, preserve it during updates, and leave it in place when uninstalling. Run `/personalize` to build or revise it through an opt-in interview. After editing the profile, rerun the installer to apply it. Do not put secrets or project-specific rules in it.

### WSL, Linux or macOS, for Claude Code

In the WSL terminal:

```bash
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/OWNER/AgentPlaybook.git
bash AgentPlaybook/install/install.sh             # DryRun
bash AgentPlaybook/install/install.sh --execute
```

This appends one line, `@~/.claude/agent-playbook.md`, to `~/.claude/CLAUDE.md` so Claude Code loads the core rules and local profile. Add `--target claude,copilot` if Copilot CLI is used there too.

It also installs two Claude Code hooks into `~/.claude/hooks/agent-playbook/` (this needs `jq`; without it the installer skips this step and says so):

- **Bash guard** ([hooks/guard-bash.sh](hooks/guard-bash.sh)), registered in `~/.claude/settings.json` for every project. Whatever the permission mode, it asks before `git push`, history rewrites (amend, rebase, reset --hard, filter-repo), commands that discard uncommitted work, broad recursive deletes and commands on another machine (ssh, sftp, scp, rsync). It refuses a commit whose changes contain a likely secret or a key or `.env` file. It's a safety net for mistakes, not a security boundary: a determined command can get past a pattern match.
- **Fast check** ([hooks/run-check.sh](hooks/run-check.sh)), which each project turns on in its own `.claude/settings.json` with its own command. It runs that check before Claude finishes a turn and hands failures back to fix. See the [verify](skills/verify/SKILL.md) skill. For projects that are mostly scripts and config with no tests, [hooks/check-syntax.sh](hooks/check-syntax.sh) (installed alongside) parses every shell, Python, JavaScript, JSON, YAML and PowerShell file without running any of them.

The installer also sets `worktree.baseRef` to `"head"` (if unset) so `claude --worktree` branches from your local commits rather than the remote's, and adds `.claude/worktrees/` to your global git ignore file. The hooks are bash, so the Windows installer doesn't install them yet.

### Check it worked

In a new Claude Code session, ask "What is the title of working rule 5 in the Agent Playbook core rules?" In Copilot chat, type `/` and look for `investigate` and `verify`. More checks are in [docs/Verify.md](docs/Verify.md).

## Update

```bash
git pull
bash install/install.sh --execute        # or .\install\install.ps1 -Mode Execute on Windows
```

## Uninstall

`--uninstall --execute` (bash) or `-Uninstall -Mode Execute` (PowerShell). This removes the skills it installed, the generated core rules, the import line and the Visual Studio block. It leaves the private user profile in place. Anything else in those folders and files is left alone. Every existing file it edits is backed up first as `<file>.bak-<timestamp>`.

## Using it in a repo

At the start of every task, the core rules check for an instructions file (`CLAUDE.md`, `AGENTS.md` or `.github/copilot-instructions.md`), `DESIGN.md`, `DecisionLog.md` and `LearningLog.md`. If any are missing and there is no `.agent/project-docs-opt-out.md`, the agent offers to set them up with `/project-docs`. In local-only mode, the three memory files can live under `.agent/`. Run `/project-docs` in a repo to add them:

- **Shared:** committed, for repos you own or where the team agrees.
- **Local:** kept in `.agent/` and hidden from git with `.git/info/exclude`, for team repos. These files aren't in git, so include the folder in your own backups.

## Changing it

Edit the files here, run `bash tools/check-skills.sh`, commit, and rerun the installer. Keep user-specific details out of `instructions/`, `skills/` and `install/`; users add those to their private profile or their tool's own instructions.
