---
name: investigate
description: Read-only investigation of an existing system, codebase, service or bug before changing anything. Use when asked how something works, why it behaves a certain way, what's wrong with it, or before planning a change to something that already exists.
argument-hint: "<what to investigate>"
---

# Investigate (read-only)

Topic: `$ARGUMENTS`

Understand first, change later. This skill makes **no changes**: no file edits, no restarts, no installs, no commands with side effects. If a check you need would change something (even a "harmless" one like creating a test file or running a script you haven't read), stop and ask.

## 1. Frame the question

Restate in one sentence what you're trying to find out, and what answer would let the user decide the next step. If the request is vague, pick the most useful reading and say which you picked.

## 2. Read what's already known

Before touching the system itself:

1. The project's instructions file, `DESIGN.md`, and the last entries of `DecisionLog.md` and `LearningLog.md`, if they exist. Search all of the project's docs for the topic (`grep -ril`). Parallel sessions may already have answered it.
2. Git history for the relevant files: `git log --oneline -15 -- <path>`, and `git log -S'<term>'` to find when something appeared. Commit messages often say why.
3. Any linked project or vendor docs the project points to.

## 3. Look at the real thing

Trace current behavior from evidence, not from what the code or docs say should happen:

- **Code:** start at the entry point the user cares about and follow the calls. Note file and line for each step.
- **Running systems:** read configuration, logs, status and listings. Prefer the system's own read-only commands (`status`, `list`, `show`, `get`, `docker inspect`, `Get-*` cmdlets).
- **Versions:** record the version of anything whose behavior you rely on.

Where the docs and the real system disagree, the real system wins, and the difference is itself a finding.

## 4. Separate fact from guess

For each finding, mark whether you **saw** it (with the file, line, command or log line) or are **inferring** it. Never present an inference as a fact. If a guess matters, say what check would confirm it.

## 5. Report

In prose, briefly:

1. **Answer:** the direct answer to the question, in two or three sentences.
2. **How it works / what's happening:** the trace, with file and line references.
3. **Evidence and confidence:** what was seen, what is inferred, what wasn't checked.
4. **Docs that are wrong or missing:** differences between the docs and reality.
5. **Options:** if a change looks needed, the options with a recommendation. Don't apply any of them; that's a separate step (see `safe-change`).
