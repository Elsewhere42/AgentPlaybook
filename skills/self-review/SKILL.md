---
name: self-review
description: Review your own uncommitted changes before committing or handing work back. Checks correctness, scope, secrets and personal data, docs, and whether it was really verified. Use before every commit, and whenever the user asks if work is ready.
argument-hint: "[path or commit range]"
---

# Self-review

Scope: `$ARGUMENTS` (default: everything uncommitted, `git diff HEAD` plus untracked files from `git status --short`).

Read the whole diff as a reviewer who didn't write it. Fix what you find before committing, and report anything you chose not to fix.

## Checklist

1. **Does it do what was asked, and only that?** Unrelated edits, reformatting, or "while I was here" changes go in a separate commit or get reverted.
2. **Correctness.** Walk each changed path with a real input, including the empty, missing and error cases. Look for wrong paths, off-by-one, quoting problems in shell, wrong account or permissions, time zones, and anything that works on this machine only.
3. **Secrets and personal data.** No passwords, tokens, keys, connection strings, `.env` contents, private IPs or names that shouldn't be in this repo, and no personal data. Check untracked files about to be added too. If a secret is found, stop and tell the user; don't just delete it from the diff if it was ever committed.
4. **Safety of what it runs.** Scripts default to a dry run. Nothing deletes without a way back. Nothing runs automatically that wasn't asked for.
5. **Docs match.** `DESIGN.md` describes the new state; a decision or learning entry exists if one was earned; the README or instructions file still tells the truth about how to run, deploy and roll back.
6. **Verified?** State which checks ran and what they showed. If nothing was verified on the real system, say so, and don't describe the work as done.
7. **Leftovers.** Debug output, commented-out code, temp files, scratch scripts, TODOs without an owner.

## Report

One short paragraph: what the change does, what you fixed during review, what's left and why, and whether it's ready to commit. Then commit (if the project's rules allow it) with a message that says what and why, and give the hash.
