---
name: pause
description: Stop work safely and leave a handoff that a later session, another tool or another person can resume from. Records state, open items and the exact next step in the project docs. Use when the user wants to stop, switch tasks or machines, or when a session is getting long.
argument-hint: "[note about why or what's next]"
disable-model-invocation: true
---

# Pause safely

Note: `$ARGUMENTS`

The goal is that the next session can start with `refresh` and continue without asking what happened.

## 1. Bring the system to a safe state

- Don't leave anything half-applied. If a change is mid-way, either finish the current small step and verify it, or roll it back. Say which.
- Stop anything you started in the background (dev servers, watchers, long-running commands) unless the user wants it left running; if so, record how to stop it.
- Remove or encrypt temporary files that hold secrets.

## 2. Record where things stand

In `DESIGN.md` under **Open items** (create the section if needed), add or update one row per unfinished thread:

| Item | Status |
|---|---|
| What it is | Where it stands, what's verified and what isn't, the exact next step, and anything waiting on the user. Date it. |

Also:
- Make sure `DESIGN.md` describes what exists **now**, including anything changed this session.
- Add any decision or learning earned this session (`log-entry`).
- If there's useful in-progress thinking that doesn't belong in the docs (a hypothesis being tested, a half-written plan), put it in `docs/handoff.md`, dated, and link it from the open item. Delete it when the thread is done.

## 3. Commit

Run `self-review`. If the repository policy authorizes it, commit the docs and any finished work; in a team repo, ask before committing if policy is unclear or the change affects teammates. List anything left uncommitted on purpose, and why. Don't push unless the user asks.

## 4. Report

Three short parts: what's done and verified, what's open (with the next step for each), and the commit hash. End with the one command or sentence to resume, such as "Run `/refresh`, then continue with <item>."
