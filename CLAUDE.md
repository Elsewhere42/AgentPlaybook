# Agent Playbook

A portable set of working rules and skills for coding agents: one source, installable with Claude Code (WSL or Windows) and GitHub Copilot (VS Code and Visual Studio).

[DESIGN.md](DESIGN.md) is the source of truth for the project's current state. Read it before changing anything.

## Project basics

- **Status:** Maintained public source for portable installs
- **Stack:** Markdown (Agent Skills `SKILL.md` format), bash and PowerShell installers
- **Runs on:** Each machine's user profile folders; nothing runs as a service
- **Repo:** Public GitHub repository
- **Depends on:** Nothing

## How to work on it

- **Check:** `bash tools/check-skills.sh && bash tools/test-hooks.sh && bash hooks/check-syntax.sh` (skill frontmatter, the hooks against temporary repos, and syntax of every script)
- **Install or update here:** `bash install/install.sh` (DryRun), then `bash install/install.sh --execute`
- **Install on Windows:** see [README.md](README.md)
- **Verify:** [docs/Verify.md](docs/Verify.md)
- **Rollback:** `bash install/install.sh --uninstall --execute` removes only what it installed; or check out the previous commit and install again

## Project rules

- **Keep distributed files generic** (`instructions/`, `skills/`, `install/`): no host names, IPs, account names, private project names or machine-specific paths. `tools/check-skills.sh` doesn't check this; grep before committing.
- Skills must work in Claude Code, VS Code Copilot and Visual Studio Copilot. Use only the frontmatter fields all three honor (`name`, `description`, `argument-hint`, `disable-model-invocation`), refer to the instructions file generically (`CLAUDE.md`, `AGENTS.md` or `.github/copilot-instructions.md`), and say how to do shell steps in PowerShell where it matters.
- After changing a skill or the core rules: run the checks, commit, rerun the installer on this machine, and note it for the other machines (they update with `git pull` and the installer).
- Keep the docs current: [DESIGN.md](DESIGN.md) for what exists, [DecisionLog.md](DecisionLog.md) for why, [LearningLog.md](LearningLog.md) for gotchas.
- Decision (D-) and learning (L-) numbers belong to this project alone. Always name the project when referring to another project's entries.

## Plan

1. Keep the main branch generic and publishable.
2. Install and verify on supported WSL, Linux, macOS and Windows environments.
3. Tighten skills based on real-world use.
