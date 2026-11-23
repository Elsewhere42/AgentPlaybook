---
name: project-docs
description: Add the project memory files (instructions file, DESIGN.md, DecisionLog.md, LearningLog.md) to an existing repo, shared or local. Start only after the user explicitly requests setup, approves the setup offer, or invokes this skill.
argument-hint: "[shared | local]"
---

# Project docs

Mode: `$ARGUMENTS` (ask if not given).

Templates are in [templates/](templates/). Never overwrite a file that already exists; report it as skipped and offer to merge by hand.

## 1. Look first

Start only after the user explicitly requests setup, approves the setup offer, or invokes this skill. Check whether `.agent/project-docs-opt-out.md` exists; the user's explicit request or approval overrides it. Then, read-only, list which of `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `DESIGN.md`, `DecisionLog.md`, `LearningLog.md`, `docs/` exist, and read any that do. Check `git remote -v` and the recent authors (`git shortlog -sn --since=6.months | head`) to tell whether it's a team repo.

## 2. Choose the mode

Ask which, with this recommendation: **shared** for repos the user owns, **local** for team repos unless the team has agreed to these files.

If the user declines setup at any point, stop without creating project templates. Record the choice in `.agent/project-docs-opt-out.md` and, in a Git repo, add that exact path to `.git/info/exclude` so it remains local. Back up an existing exclude file before editing it. If setup is later completed through this explicit skill invocation, remove the opt-out note.

- **shared:** files are committed. Put the logs and `DESIGN.md` at the root, or in `docs/` if the repo already keeps docs there.
- **local:** files stay on this machine only. Put them in `.agent/` at the repo root and add `.agent/` to `.git/info/exclude`. That file works like `.gitignore` but is never committed, so teammates never see it. Warn the user plainly: **local files aren't in git, so they aren't backed up by the repo and are lost if the folder is deleted or re-cloned.** Suggest including the folder in their own backup.

## 3. Instructions files

The agents read different files, so use one source and point the others at it:

| File | Read by | Content |
|---|---|---|
| `AGENTS.md` | Copilot in VS Code, Codex, most other agents | The real project instructions, from [templates/AGENTS.md](templates/AGENTS.md) |
| `CLAUDE.md` | Claude Code | The single line `@AGENTS.md`, which imports it |
| `.github/copilot-instructions.md` | Copilot in Visual Studio (and VS Code) | A short pointer: "Project instructions are in AGENTS.md at the repo root. Read it before starting." |

If the repo already has one of these with content, keep it as the source instead, and point the other two at it.

In **local** mode the real instructions live at `.agent/AGENTS.md`. The agents read files from disk whether or not git tracks them, so for each of the three files above that the repo **doesn't** already track, create it as a pointer to `.agent/AGENTS.md` (`CLAUDE.md` gets `@.agent/AGENTS.md`) and add it to `.git/info/exclude` too. A file the repo already tracks can't be excluded and mustn't be edited for this; for that tool, tell the user to attach `.agent/AGENTS.md` by hand (in Copilot chat, `#file:.agent/AGENTS.md`).

## 4. Fill them in

Copy the templates, replacing `{{PROJECT_NAME}}` and `{{DATE}}`. Then ask the user, in one message, the questions needed for the instructions file's project basics: what it is, status, stack, where it runs, how to run, test and deploy, and related projects. Don't invent answers; anything unknown stays as a `[bracketed placeholder]`. Fill `DESIGN.md` from what you can see in the repo, marking guesses. Delete template sections that clearly don't apply.

## 5. Finish

In **shared** mode, run `self-review` and commit (if the repo's rules allow; in a team repo ask first, since it changes what teammates see). In **local** mode, confirm with `git status` that none of the files show up as untracked. Report what was created, skipped and committed.
