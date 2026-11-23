---
name: safe-change
description: The procedure for changing anything that already exists and matters (a server, service, config, database, shared folder, deployed site, user account or data): investigate, check dependents, back up, preview, change, verify, document, with a rollback ready. Use before modifying any live or existing system.
argument-hint: "<the change>"
---

# Safe change

Change: `$ARGUMENTS`

Follow the steps in order. Stop and ask the user at each **checkpoint**. For a brand-new project's own files, steps 2 to 4 can be skipped.

## 1. Understand the current state

Use `investigate` if the area isn't already understood this session. Re-read the relevant part of `DESIGN.md` and the latest log entries from disk, since another session may have changed things.

## 2. Check what depends on it

Use `blast-radius` for anything being removed, renamed, moved, or having its permissions or interface changed.

## 3. Write the plan

A short plan covering:

- **What changes:** exact files, settings or commands, on which machine, as which account.
- **Backup:** what gets copied, to where, and how to restore it. The backup is plain files (a copy of the folder or file, an export) that a person can browse. A git commit of the current state also counts for files in a repo. If the backup holds secrets, say how it will be encrypted or removed afterwards.
- **Preview:** how you'll see exactly what will happen before it happens (dry run, `--check`, `-WhatIf`, `robocopy /L`, `git diff`, `terraform plan`, a diff of the new config against the old).
- **Verification:** the checks from `verify` that prove it worked.
- **Rollback:** the exact steps to undo it, and how long they take.
- **Impact:** downtime, who notices, anything public-facing.

**Checkpoint:** show the plan. Wait for approval. If the change needs the user to do something (run a command as an admin, click in a web console, enter a password), say exactly where and how.

## 4. Back up

Take the backup and confirm it exists and is complete (file count or size, opens correctly). Record its location in your notes for the summary.

## 5. Preview

Run the dry run and show the result. If it differs from the plan (more files, a different path, an unexpected deletion), stop and report.

**Checkpoint** if the preview revealed anything unexpected, or if the change is hard to reverse.

## 6. Make the change

Exactly as previewed. Change one thing at a time where possible, so a failure points at one cause. For a file-changing script, use the modes from `script-modes` and let the user run Execute when they asked to.

## 7. Verify

Run the checks from the plan with `verify`. If verification fails, say so plainly, then either fix forward (if the cause is clear and small) or roll back. Ask before rolling back a change the user is relying on.

## 8. Record it

- Update `DESIGN.md` to describe what exists now.
- Add a `DecisionLog.md` entry if a choice was made, and a `LearningLog.md` entry if something surprised you (`log-entry`).
- Update any audit or access record the project keeps, if access changed.
- Remove or encrypt temporary backups that hold secrets.
- If the repository policy authorizes committing and the work is complete and verified, run `self-review`, commit, and give the hash. In a team repo, ask before committing if the repository policy is unclear or the change affects teammates. Never push unless the user asks.

## 9. Summarize

What changed, what was verified, what wasn't, where the backup is, how to roll back, and anything waiting on the user.
