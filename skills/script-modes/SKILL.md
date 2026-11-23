---
name: script-modes
description: How to write a script that changes, moves or removes files or data (cleanup, migration, bulk rename, backup, permission fix) so that it has DryRun, Execute and Rollback modes and a plain-text log. Use whenever writing such a script in PowerShell or bash, especially one the user will run themselves.
---

# Scripts with DryRun, Execute and Rollback

Any script that changes, moves or removes files or data has three modes. The user reviews the DryRun output, and usually runs Execute themselves.

| Mode | Does |
|---|---|
| `DryRun` (default) | Changes nothing. Lists every action it would take, exactly, one per line, and writes the same list to the log. |
| `Execute` | Performs the actions, writing each one to the log as it happens, plus an undo record. |
| `Rollback` | Reads the undo record from an Execute run and reverses it, newest action first. |

## Rules

1. **DryRun is the default.** Running the script with no arguments must never change anything.
2. **Removals move, they don't delete.** Items go to a holding folder (for example `_ToDelete\<timestamp>\`, keeping their relative path) so Rollback can put them back. The user empties the holding folder after checking.
3. **Log everything to a plain-text file** next to the script or in a `logs` folder, named with the mode and a timestamp. One line per action: time, action, source, destination, result.
4. **Record enough to undo exactly.** The undo record (CSV or JSON) has every action in order with its original and new location, so Rollback doesn't have to guess.
5. **Same logic in every mode.** DryRun and Execute go through the same code path and differ only at the moment of acting, so the preview can't drift from what really happens.
6. **Fail safe.** Stop on the first unexpected error (`$ErrorActionPreference = 'Stop'`, or `set -euo pipefail`), and never continue in a half-finished state without saying so. Skip and log items that can't be read rather than silently missing them.
7. **Show a summary at the end:** counts of each action, errors, the log path, and for DryRun the exact command to run Execute.
8. **No hidden side effects.** No network calls, notifications or deletes outside the documented actions. Parameters are explicit; no guessed defaults for paths.
9. **Copy tools have their own dry run.** For robocopy, DryRun means `/L`. For rsync, `--dry-run`. Pass the tool's own preview flag rather than reimplementing it.

## PowerShell

Start from [templates/Invoke-Change.ps1](templates/Invoke-Change.ps1). It works in Windows PowerShell 5.1 and PowerShell 7. Replace the `Get-PlannedActions` function with the real work; leave the mode handling, logging and rollback as they are.

Tell the user how to run it, from a PowerShell window in the script's folder:

```powershell
.\Invoke-Change.ps1 -Root 'D:\Data'                  # DryRun: review the list
.\Invoke-Change.ps1 -Root 'D:\Data' -Mode Execute
.\Invoke-Change.ps1 -Mode Rollback -UndoFile .\logs\undo-20260101-120000.csv
```

If execution policy blocks it, `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-Change.ps1 ...` runs it once without changing the machine's policy.

## Bash

Use the same shape: a `MODE` variable defaulting to `dryrun`, a single `act` function that either prints or runs the action and appends to the log and undo file, and a `rollback` that reads the undo file in reverse (`tac`). Start with `set -euo pipefail`.
