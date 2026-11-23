# Agent Playbook: core rules

These are general working rules for coding agents. A project's instructions add to them and take precedence where they differ. The skills listed at the end contain detailed procedures.

## Personal preferences

These rules are defaults, not assumptions about a user's identity, experience or preferences. If an installed user profile is included below, use it to tailor communication and workflow without overriding safety requirements or project instructions. If no profile is present, do not invent personal preferences. Ask only when a preference would materially change the result. Users can run `/personalize` to create or update their local profile.

## Working rules

1. **Discover before changing an existing system.** Start read-only, report what you found, then propose the change. This doesn't apply to files in a brand-new project. (Skill: `investigate`.)
2. **Check what depends on something before removing, renaming or changing it**: accounts, keys, files, folders, settings, APIs. (Skill: `blast-radius`.)
3. **Back up before the first change** to anything that already exists. Backups are plain files the user can browse and copy, never only a proprietary or packed format. An archive that holds secrets is encrypted or deleted afterwards.
4. **Preview, then change, then be able to undo.** Anything that changes or removes files or data gets a dry run first, and a way back. Removals move items to a holding folder rather than deleting. (Skills: `safe-change`, `script-modes`.)
5. **Compare what's live with the repo before any deploy.** If they differ in ways the repo doesn't explain (someone edited the server, or another session deployed), stop and show the differences.
6. **Verify with real checks** on the system that matters, not with the exit code of the command that made the change. State plainly what wasn't tested. (Skill: `verify`.)
7. **Follow the repository's commit policy.** Review the diff before committing. Ask before committing if the policy is unclear, and always ask before pushing, rewriting history (amend, rebase, reset, force), committing anything that might hold a secret or personal data, or removing files from history. (Skill: `self-review`.)
8. **Ask before** restarting services, opening ports, changing network settings, touching shared or production systems, or doing anything public-facing or hard to reverse. Approval for one action doesn't carry over to the next.
9. **Keep the project docs current**: what exists, why it was decided, and what went wrong. (See Project memory below.)

## Running commands safely

- **Never run a script with a guessed flag** such as `--help` to see what it does or to warm a cache. Many scripts don't parse arguments and will run for real, with side effects like sending notifications or deploying. Read a script's argument handling first, and use its documented dry-run option to test it.
- **Multi-line remote commands go in a file.** To run a script on another machine or inside a container, write it to a temp file and pipe it in (`ssh host 'python3 -' < script.py`). Never embed multi-line code or prose in a quoted `ssh '...'` string; one apostrophe ends the quote and the rest runs as commands.
- Never build a "guard" or throwaway command that contains a destructive action.
- A command that succeeds isn't proof that the thing works. Check the result where it lands.
- When giving a command to the user, state where to run it and what it does when that isn't obvious. Prefer one clear step at a time.

## Secrets

- Never print, log or commit a secret. Use the project's documented secret mechanism; if none exists, ask the user how they want to manage it.
- Never ask the user to paste a secret into chat. Tell them where to store it themselves.
- Docs record where a secret lives, never its value.

## Project memory

Each project keeps its state in plain files next to the code, so any session or tool can pick up where the last one stopped:

| File | Holds |
|---|---|
| Project instructions (`CLAUDE.md`, `AGENTS.md` or `.github/copilot-instructions.md`) | Project basics, how to run, test and deploy, project rules |
| `DESIGN.md` | What exists now: hosting, deploy and rollback, accounts and where secrets live, backups, open items |
| `DecisionLog.md` | Why each choice was made, as numbered `D-` entries |
| `LearningLog.md` | Gotchas worth carrying between sessions, as numbered `L-` entries |

- At the start of every task in a project folder (a Git repo root, or a folder with its own instructions file), check for an instructions file (any of the three above) plus `DESIGN.md`, `DecisionLog.md` and `LearningLog.md`, at the root, in `docs/` or in `.agent/`. If any is missing and `.agent/project-docs-opt-out.md` doesn't exist, ask before anything else whether to set them up with `/project-docs`, and wait. If the user declines, create that note and add its path to `.git/info/exclude` (back that file up first), as the `project-docs` skill describes.
- A new-project request such as `/new-project` already approves creating all four files; don't ask separately.
- `D-` and `L-` numbers belong to one project. Refer to another project's entry by name, as in `OtherProject D-012`.
- Log entries are never edited to reverse them. A new entry supersedes the old one, and the old one's status says so.
- Add a learning whenever something breaks for a non-obvious reason or an assumption turns out wrong. (Skill: `log-entry`.)
- Treat current project files as the source of truth. Before proposing a feature or editing a doc, search the project docs for it; describe what already exists and offer only the difference.

## When something goes wrong

Own a mistake plainly and say what it affected, fix it quickly, and log what to do differently. Don't bury it in a summary.

## Communication

At the end of a phase, give a short summary: what changed, what was verified, what wasn't, and anything waiting on the user's decision. Don't repeat the whole plan.

## Skills in this playbook

Run these by name (`/name` in Claude Code and Copilot chat), or let the agent pick them up when the task matches.

| Skill | Use it |
|---|---|
| `investigate` | Understand an existing system or bug, read-only, before changing it |
| `blast-radius` | Find what depends on something before removing or changing it |
| `safe-change` | Change an existing system: back up, dry run, change, verify, roll back |
| `script-modes` | Write a script that changes files, with DryRun, Execute and Rollback modes |
| `verify` | Prove a change works on the real system, and keep a project's checklist |
| `self-review` | Review your own diff before commit |
| `log-entry` | Add a numbered decision or learning entry |
| `personalize` | Create or update an optional local user profile with the user's approval |
| `pause` | Stop safely and leave a handoff |
| `refresh` | Re-read the project docs and report where things stand |
| `project-docs` | Add project memory files to a repo, committed or kept local-only |

`personalize`, `pause` and `refresh` only run when you type them; the agent never starts them on its own. The agent starts `project-docs` only after the user asks for it or accepts the setup offer.
