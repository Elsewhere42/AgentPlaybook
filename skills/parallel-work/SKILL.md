---
name: parallel-work
description: Run a task in its own git worktree and branch so several agent sessions can work on one repository without editing the same files, then merge it back when verified. Use when starting a task while another session may be working in the same repo, when asked to work on a branch or worktree, or when finishing work done in a worktree.
argument-hint: "start <name> | finish | status"
---

# Parallel work in worktrees

Argument: `$ARGUMENTS`

Two sessions in one checkout edit the same files, see each other's half-finished changes, and commit each other's work. A git worktree is a second checkout of the same repository in its own folder, on its own branch, so each session has a clean working copy and a diff of only its own changes.

## Start

1. Check the repo: `git status` and `git worktree list`. If you are already in a worktree for this task (the path contains `.claude/worktrees/` or the branch isn't the main branch), carry on there.
2. Create the worktree:
   - **Claude Code:** the user starts the session with `claude --worktree <name>` (or `-w <name>`). It creates `.claude/worktrees/<name>/` on branch `worktree-<name>`. Mid-session, use the built-in worktree tool if it's available.
   - **Any tool, or by hand:** `git worktree add .claude/worktrees/<name> -b worktree-<name>`, then work in that folder. PowerShell is the same command.
3. A new worktree starts from the last commit. It doesn't have gitignored files such as `.env` or local settings. In Claude Code, list them in a `.worktreeinclude` file at the repo root (same syntax as `.gitignore`) and they're copied in. Otherwise copy them by hand, and never commit them.
4. Dependencies (`node_modules`, virtual environments, build output) aren't shared. Install them in the worktree before running the check or tests.

## While working

- Commit on the worktree branch as you go. Small commits make the merge easy to review.
- Don't deploy from a worktree branch. Deploys go from the main branch after the merge, so what's live is always on main.
- Ports, local databases and data files under the repo are still separate copies or shared resources. If the project's local server uses a fixed port, two worktrees can't run it at once.

## Finish

1. Run the project's check and verification (the `verify` skill) in the worktree. Commit.
2. Bring the branch up to date with main if main moved: `git merge main` in the worktree, fix conflicts, check again. Don't rebase without asking.
3. Merge into main from the main checkout, only if no other session is working there (uncommitted changes in it are a sign one is):
   `git -C <main checkout> merge --ff-only worktree-<name>`, or `git -C <main checkout> merge --no-ff worktree-<name>` if it can't fast-forward.
   If another session is working in the main checkout, stop and tell the user the branch is ready to merge.
4. Report the merge commit hash. Ask before pushing, as always.
5. Remove the worktree once merged: `git worktree remove .claude/worktrees/<name>` and `git branch -d worktree-<name>`. In Claude Code, exiting the session offers this. Never force-remove a worktree that has uncommitted changes; ask first.

## Status

`git worktree list` shows every worktree and its branch. `git branch --no-merged main` shows branches whose work isn't on main yet. Report both, and flag any worktree whose branch is merged but still present.
