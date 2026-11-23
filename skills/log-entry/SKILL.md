---
name: log-entry
description: Add a numbered entry to the project's DecisionLog.md (D-) or LearningLog.md (L-), using the next free number and the standard format, or supersede an old decision. Use when a design choice is made, when something broke for a non-obvious reason, or when an assumption turned out wrong.
argument-hint: "decision|learning <short title>"
---

# Log entry

Arguments: `$ARGUMENTS`

## Which log

- **Decision** (`DecisionLog.md`, `D-`): a choice between options that someone later might question. Record what was decided and why, including the options rejected.
- **Learning** (`LearningLog.md`, `L-`): something that broke for a non-obvious reason, an assumption that was wrong, or a tool's surprising behavior. Mistakes made in this session, by the user or by you, belong here too, written plainly and without blame.

If neither log exists, offer `project-docs`. Look for the logs at the repo root, then in `docs/`.

## Find the next number

Numbers belong to this project alone. Skip the example inside the log's fenced "Entry format" block:

```bash
awk '/^```/{f=!f} !f && /^## [DL]-[0-9]+/{match($0,/[DL]-[0-9]+/); print substr($0,RSTART,RLENGTH)}' DecisionLog.md LearningLog.md | sort -t- -k1,1 -k2,2n
```

The next number is one more than the highest of that letter, zero-padded to three digits. If the list shows a number used twice, mention it to the user and don't renumber old entries yourself; other docs refer to them.

## Formats

Add new entries at the bottom, under the `## Decisions` or `## Learnings` heading.

```markdown
## D-012: Short title

- **Date:** YYYY-MM-DD
- **Status:** Active
- **Decision:** What was decided.
- **Reasoning:** Why, including the alternatives that were rejected.
```

```markdown
## L-007: Short title that states the gotcha

- **Date:** YYYY-MM-DD
- **What happened:** The symptom, or the assumption that was wrong.
- **Cause:** Why it happened.
- **Next time:** What to do differently. Make this specific enough to act on.
```

## Superseding a decision

Never edit or delete an old entry to reverse it. Add a new entry that says what it replaces, then change only the old entry's status line to `Superseded by D-0NN`. If the decision changed what exists, update `DESIGN.md` in the same commit.

## Titles

Write the title as the fact itself, so a list of headings is useful on its own: "Robocopy silently skips files its account can't read", not "Robocopy issue".
