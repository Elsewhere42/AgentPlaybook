---
name: refresh
description: Re-read the current project's docs, memory and related projects from disk, then report what changed, where work stands, and any contradictions. Read-only.
argument-hint: "[all | <topic>]"
disable-model-invocation: true
---

# Refresh

Re-read the project's documentation from disk, because what was loaded at session start, or survived a compaction, may be stale or incomplete, and parallel sessions may have changed it. This is **read-only**: no file edits, no remote sessions, no commands that change anything. Offer fixes at the end; never apply them in this skill.

Argument: `$ARGUMENTS`
- empty → **core** level
- `all` → core plus linked docs
- anything else → core plus docs matching that topic

## 1. Find the projects

- **Current project:** the git root of the working directory (`git rev-parse --show-toplevel`), or the working directory if it isn't a repo.
- **Project docs** may be at the root or in `docs/`. The instructions file is whichever of `CLAUDE.md`, `AGENTS.md` and `.github/copilot-instructions.md` exist.
- **Related projects:** in the instructions file, find the line starting `Related projects (read by /refresh):` and take the paths listed on it. Projects without that line have none. Go only one hop: related projects' own related projects aren't included.
- **Memory:** if the tool keeps a memory folder for the project, read it too. In Claude Code, for a project at path P it is `~/.claude/projects/<P with every / replaced by ->/memory/`, with `MEMORY.md` as its index. Other tools: skip this unless they keep memory in a file you can read.

## 2. Read the core set (every level)

Read whole files unless noted.

For the **current project**:
1. The user-level instructions the tool loads (for Claude Code `~/.claude/CLAUDE.md`, following any `@` imports; for Copilot `~/.copilot/copilot-instructions.md` or `%USERPROFILE%\copilot-instructions.md`), if readable.
2. The instructions file and `DESIGN.md`.
3. The memory index and every memory file it lists, if there is one.
4. `DecisionLog.md` and `LearningLog.md`: only the **last 5 entries** of each (find entry headings with `grep -n '^## '`, then read from the fifth-last heading to the end).
5. `docs/handoff.md`, if it exists.

For each **related project**:
1. Its instructions file and `DESIGN.md`.
2. Its memory index only; open individual memory files only when the topic needs them.
3. The last 3 entries of each log.

Then gather, with the shell:
- **Entry numbers, per project.** Each project numbers its own D-/L- entries; the same number in two projects is normal. For each project separately, list its numbers, skipping the example inside each log's fenced "Entry format" block:
  `awk '/^```/{f=!f} !f && /^## [DL]-[0-9]+/{match($0,/[DL]-[0-9]+/); print substr($0,RSTART,RLENGTH)}' <logs> | sort -t- -k1,1 -k2,2n`
  Pipe that into `uniq -d` for numbers used twice within the project, and separately into `awk -F- '{m[$1]=$2} END{for(k in m) print k"-"m[k]}'` for its highest D and L. Also flag any reference to another project's entry that doesn't name the project.
- **Recent changes** in each repo: `git log --since="7 days ago" --date=short --format='%h %ad %s' -- '*.md' | head -20` and `git status --short`.

On Windows without a bash shell, do the same with PowerShell (`Select-String -Pattern '^## [DL]-\d+'`, `git log` works the same).

## 3. Extra reading by level

- **`all`:** follow markdown links and backticked paths ending in `.md` found in the core files, one level deep, staying inside the project folders. Skip `reviews/`, template folders, and files whose names end in a date (one-off snapshots), unless the core files say they're current. If this would be more than about 15 extra files, read the ones linked from `DESIGN.md` first and list the rest without reading them.
- **`<topic>`:** list the `.md` files in the current and related projects (`docs/` and the root), and search them for the topic (`grep -ril`). Read the files whose name or headings clearly match, plus the log entries mentioning the topic. If nothing matches, say so and stop after the core set.

## 4. Report

Keep it short and in prose, with a few bullets where they help:

1. **Read:** one line listing what was read (counts are fine for memory files).
2. **Recently changed:** the notable changes from git and uncommitted files, by project.
3. **Where things stand:** the current phase, open items and anything waiting on the user, from `DESIGN.md`, the handoff file and the latest log entries.
4. **Contradictions and stale notes:** places where the docs disagree with each other or with memory, D-/L- numbers used twice within one project, cross-project references that don't name the project, and memory entries the docs no longer support. Give file and line for each.
5. **Next entry numbers:** the next free D- and L- number for each project.

End by offering to fix the contradictions, one commit per project, and wait for the answer.

From here on, treat what you just read as current, replacing anything older from this session that disagrees with it.
