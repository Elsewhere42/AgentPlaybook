# Decision Log

Every decision, with its reasoning. Newest entries go at the bottom. Don't edit or delete an old entry to reverse it. Add a new entry that supersedes it, and set the old entry's status to `Superseded by D-XXX`.

## Entry format

```markdown
## D-001: Short title

- **Date:** YYYY-MM-DD
- **Status:** Active
- **Decision:** What was decided.
- **Reasoning:** Why, including the alternatives that were rejected.
```

## Decisions

## D-001: One portable library with local personalization

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** The portable working rules and skills live in their own repository, with no machine-specific or personal details in the distributed files. The repository is public and can be cloned from GitHub. Machine-specific preferences stay in a private local profile.
- **Reasoning:** A shared baseline avoids separate copies that drift while allowing each user to keep private preferences outside the repository.

## D-002: Skills are copied into each tool's folder, not linked

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** The installers copy each skill folder into the tool's user skills folder and write a `.agent-playbook` marker into it. Updates replace only marked folders; anything else with the same name is skipped and reported.
- **Reasoning:** Symlinks require platform-specific privileges and complicate backups. The marker stops the installer from overwriting a skill it didn't install. The cost is that an edit must be followed by rerunning the installer.

## D-003: Installers default to DryRun

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** Both installers change nothing unless given `--execute` / `-Mode Execute`, and have an uninstall that removes only what they installed.
- **Reasoning:** The playbook's own rule (`script-modes`): anything that changes files previews first and has a way back. The installers edit files the user may have written (`CLAUDE.md`, `copilot-instructions.md`).

## D-004: Agent Skills format, and one instructions source per repo

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** Skills use the Agent Skills `SKILL.md` format with only the frontmatter fields Claude Code, VS Code and Visual Studio all honor. The core rules go to each tool's own always-on location (D-002 installers). In other repos, `project-docs` makes `AGENTS.md` the source and points `CLAUDE.md` (`@AGENTS.md`) and `.github/copilot-instructions.md` at it, or keeps everything in an excluded `.agent/` folder for team repos.
- **Reasoning:** All three tools read `SKILL.md`, but none reads the others' always-on file (VS Code's Copilot harness doesn't read `~/.claude/CLAUDE.md`; Visual Studio reads only `copilot-instructions.md`). Local-only docs let a user keep project memory in team repos without changing what teammates see.

## D-005: Keep the shared rules generic and personalize with a local profile

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** The distributed core contains neutral defaults. An optional user profile lives outside the repository at `.agent-playbook/user-profile.md` in the user's home directory; installers create it from a blank template, merge it into generated instructions, and never overwrite or remove it. The `/personalize` skill collects preferences only with the user's approval.
- **Reasoning:** Personal work style, experience and environment differ between users. Keeping those preferences local avoids embedding one person's assumptions in shared rules, while generating tool-specific instructions makes the same profile available to each supported client.

## D-006: Keep a separate branch for the prior personalized core

- **Date:** 2026-11-22
- **Status:** Superseded by D-011
- **Decision:** The `personalized-preferences` branch restores the prior personal preferences in `instructions/core.md`; `main` remains generic and uses the private local profile mechanism.
- **Reasoning:** This keeps the user's existing workflow available without making its personal details part of the shared baseline. (Written on that branch and missing from `main` until 2026-11-22; added here so the numbering has no gap.)

## D-007: Offer project-doc setup once and remember declines locally

- **Date:** 2026-11-22
- **Status:** Superseded by D-008
- **Decision:** When core project instruction or memory files are missing, ask once whether the user wants `/project-docs` setup. Start setup after the user explicitly requests it, says yes or invokes the skill. If declined, record a local opt-out note at `.agent/project-docs-opt-out.md` and exclude it from Git. Explicit setup requests or approval override the note.
- **Reasoning:** This makes project memory easy to add without repeatedly interrupting users who choose not to set it up or exposing their choice in shared files.

## D-008: Check project files at the start of every task

- **Date:** 2026-11-22
- **Status:** Superseded by D-009
- **Decision:** At the start of each task, check for `CLAUDE.md`, `DESIGN.md`, `DecisionLog.md` and `LearningLog.md`. If any are missing and `.agent/project-docs-opt-out.md` does not exist, ask whether to set up the default files and wait for approval. A decline creates the local opt-out note; explicit setup requests override it. In local-only mode, the three memory files under `.agent/` count as present.
- **Reasoning:** A prompt deferred until substantive work can be missed during read-only tasks or new-project workflows. Asking first makes the setup choice predictable while preserving the explicit opt-out.

## D-009: Any instructions file counts in the start-of-task check

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** The start-of-task check (D-008) accepts any of `CLAUDE.md`, `AGENTS.md` or `.github/copilot-instructions.md` as the instructions file, and finds the memory files at the root, in `docs/` or in `.agent/`. It applies in a project folder (a Git repo root or a folder with its own instructions file). The opt-out details stay in the `project-docs` skill, leaving a short rule in the core.
- **Reasoning:** D-004 makes `AGENTS.md` the source in other repos, so naming `CLAUDE.md` would have offered setup in repos that were already set up. The rule had also become the longest paragraph in the always-loaded core, which every session pays for.

## D-010: Keep the shared main branch generic for public use

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** The shared repository and `main` branch contain no account names, machine names, host names, private paths or personal preferences.
- **Reasoning:** Machine-specific facts are deployment context, not reusable project behavior. Local profiles and local project memory keep such details out of the shared baseline and make the repository safe to publish.

## D-011: Personalized branch moves to a private repository; public history starts fresh

- **Date:** 2026-11-22
- **Status:** Active
- **Decision:** The `personalized-preferences` branch lives only in a separate private repository, not in the public one. The public repository is recreated from the generic `main` as a single new commit, with no earlier history.
- **Reasoning:** Repository visibility is per repository, so a branch in a public repository is public. Earlier commits held personal and machine-specific details; starting a new history removes them completely, which rewriting old commits can't guarantee. The cost is that the personalized branch no longer shares history with `main`, so `main` changes reach it by cherry-pick or rebase, not merge.
