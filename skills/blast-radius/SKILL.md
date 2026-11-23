---
name: blast-radius
description: Find everything that depends on a file, folder, account, key, setting, port, API, function or service before removing, renaming, moving or changing it. Use before any deletion, rename, permission change, key rotation, or interface change.
argument-hint: "<thing to be changed or removed>"
---

# Blast radius

Target: `$ARGUMENTS`

Answer one question before anything is removed or changed: **what breaks, and who notices?** This skill is read-only.

## 1. Name the target precisely

Write down every name the target goes by: path (Linux and Windows forms), host name and IP, account name and numeric ID, key file name and fingerprint, environment variable, function or class name, URL, port. Dependents often refer to it by a different name than the one in the request.

## 2. Search every place it could be referenced

Search for each name, case-insensitively, in all of:

- **This repo:** code, config, scripts, docs (`git grep -n -i '<name>'`).
- **Related repos and projects** listed in the project instructions, and any sibling projects on this machine.
- **Scheduled and automatic things:** cron and systemd timers, Windows Task Scheduler, CI pipelines, container compose files, startup scripts, update scripts.
- **Configuration outside the repo:** `.env` files (look at names only, never print values), service configs, reverse proxies and tunnels, firewall and router rules, DNS.
- **Access lists:** who or what has been granted this account, key or folder (authorized keys, share permissions, group membership, ACLs).
- **Backups and monitoring:** backup jobs that copy it, monitors that check it, alerts that mention it.
- **Docs and runbooks** that tell a person to use it, including recovery steps.

If a place can't be searched from here (another machine, a web console), list it as **not checked** and say who could check it.

## 3. Classify each dependent

For each hit: what it is, how it uses the target, what happens if the target changes (breaks, degrades, silently stops, or nothing), and how you'd know. Pay most attention to the ones that **fail silently**, such as a backup job that skips a missing folder, or a scheduled task nobody watches.

## 4. Report

1. **Dependents found**, as a short table: dependent, how it uses the target, effect of the change, how to detect it.
2. **Not checked**: places that couldn't be searched, and who can check them.
3. **Safe order**: the order to update dependents so nothing breaks in between (usually: add the new thing, move dependents over, verify, then remove the old one).
4. **Rollback**: how to undo if something was missed.

Don't remove or change anything here; hand the plan to `safe-change`.
