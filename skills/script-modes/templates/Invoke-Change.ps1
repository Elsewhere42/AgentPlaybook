<#
.SYNOPSIS
    Template for a file-changing script with DryRun, Execute and Rollback modes.

.DESCRIPTION
    DryRun (the default) lists every planned action and changes nothing.
    Execute performs the actions, logs each one, and writes an undo file.
    Rollback reads an undo file and reverses its actions, newest first.

    Removals never delete: items are moved to a holding folder under -HoldingRoot,
    keeping their path relative to -Root, so Rollback can restore them. Empty the
    holding folder yourself once you've checked the result.

    To adapt it, replace the body of Get-PlannedActions. Each planned action is an
    object with Action ('Move' or 'Remove'), Source and Destination. Leave the mode
    handling, logging and rollback alone.

    The example plan below holds every *.tmp file under -Root for removal.

    Works in Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    .\Invoke-Change.ps1 -Root 'D:\Data'
    .\Invoke-Change.ps1 -Root 'D:\Data' -Mode Execute
    .\Invoke-Change.ps1 -Mode Rollback -UndoFile .\logs\undo-20260101-120000.csv
#>
[CmdletBinding()]
param(
    [ValidateSet('DryRun', 'Execute', 'Rollback')]
    [string]$Mode = 'DryRun',

    # Folder the script works on. Required for DryRun and Execute.
    [string]$Root,

    # Where removed items go. Default: a _ToDelete folder next to -Root.
    [string]$HoldingRoot,

    # Undo file written by an earlier Execute run. Required for Rollback.
    [string]$UndoFile,

    # Folder for logs and undo files.
    [string]$LogDir = (Join-Path $PSScriptRoot 'logs')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$logFile = Join-Path $LogDir ("{0}-{1}.log" -f $Mode.ToLower(), $stamp)

function Write-Log {
    param([string]$Action, [string]$Source, [string]$Destination, [string]$Result)
    $line = (Get-Date -Format 's'), $Action, $Source, $Destination, $Result -join "`t"
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host ('{0,-8} {1} -> {2}  [{3}]' -f $Action, $Source, $Destination, $Result)
}

function Get-RelativePath {
    param([string]$Base, [string]$Path)
    $baseFull = [IO.Path]::GetFullPath($Base).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($baseFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$full' is outside '$baseFull'."
    }
    return $full.Substring($baseFull.Length)
}

# ---------------------------------------------------------------------------
# Replace this function with the real plan. Return one object per action.
# It must not change anything: it only decides what Execute would do.
# ---------------------------------------------------------------------------
function Get-PlannedActions {
    param([string]$Root, [string]$HoldingRoot)

    Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.tmp' -ErrorAction SilentlyContinue -ErrorVariable readErrors |
        ForEach-Object {
            [pscustomobject]@{
                Action      = 'Remove'
                Source      = $_.FullName
                Destination = Join-Path $HoldingRoot (Get-RelativePath -Base $Root -Path $_.FullName)
            }
        }

    # Items the scan couldn't read are reported, not silently skipped.
    foreach ($e in $readErrors) {
        Write-Log -Action 'Skip' -Source ([string]$e.TargetObject) -Destination '' -Result ("Unreadable: " + $e.Exception.Message)
    }
}

function Invoke-Move {
    param([string]$Source, [string]$Destination)
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $Destination) { throw "Destination already exists: $Destination" }
    Move-Item -LiteralPath $Source -Destination $Destination
}

switch ($Mode) {
    { $_ -in 'DryRun', 'Execute' } {
        if (-not $Root) { throw '-Root is required for DryRun and Execute.' }
        $Root = (Resolve-Path -LiteralPath $Root).ProviderPath
        if (-not $HoldingRoot) {
            $HoldingRoot = Join-Path (Split-Path -Parent $Root) ("_ToDelete\{0}\{1}" -f $stamp, (Split-Path -Leaf $Root))
        }

        $plan = @(Get-PlannedActions -Root $Root -HoldingRoot $HoldingRoot)
        Write-Host ("{0}: {1} planned action(s). Log: {2}" -f $Mode, $plan.Count, $logFile)

        $undoPath = Join-Path $LogDir ("undo-{0}.csv" -f $stamp)
        $done = 0; $failed = 0

        foreach ($a in $plan) {
            if ($Mode -eq 'DryRun') {
                Write-Log -Action $a.Action -Source $a.Source -Destination $a.Destination -Result 'Planned'
                continue
            }
            try {
                Invoke-Move -Source $a.Source -Destination $a.Destination
                # Undo record is written after each action, so a failure part-way still leaves an exact record.
                [pscustomobject]@{ Action = $a.Action; Source = $a.Source; Destination = $a.Destination } |
                    Export-Csv -LiteralPath $undoPath -Append -NoTypeInformation -Encoding UTF8
                Write-Log -Action $a.Action -Source $a.Source -Destination $a.Destination -Result 'Done'
                $done++
            }
            catch {
                Write-Log -Action $a.Action -Source $a.Source -Destination $a.Destination -Result ("FAILED: " + $_.Exception.Message)
                $failed++
                Write-Host 'Stopping at the first failure. Completed actions are in the undo file.'
                break
            }
        }

        if ($Mode -eq 'DryRun') {
            Write-Host ''
            Write-Host 'Nothing was changed. To run it for real:'
            Write-Host ("  .\{0} -Root '{1}' -Mode Execute" -f (Split-Path -Leaf $PSCommandPath), $Root)
        }
        else {
            Write-Host ''
            Write-Host ("Done: {0}  Failed: {1}" -f $done, $failed)
            if ($done -gt 0) {
                Write-Host ("Undo file: {0}" -f $undoPath)
                Write-Host ("Removed items are in: {0}" -f $HoldingRoot)
            }
        }
    }

    'Rollback' {
        if (-not $UndoFile) { throw '-UndoFile is required for Rollback.' }
        $records = @(Import-Csv -LiteralPath $UndoFile)
        [array]::Reverse($records)
        Write-Host ("Rollback: {0} action(s) from {1}. Log: {2}" -f $records.Count, $UndoFile, $logFile)
        $restored = 0; $failed = 0
        foreach ($r in $records) {
            try {
                Invoke-Move -Source $r.Destination -Destination $r.Source
                Write-Log -Action 'Restore' -Source $r.Destination -Destination $r.Source -Result 'Done'
                $restored++
            }
            catch {
                Write-Log -Action 'Restore' -Source $r.Destination -Destination $r.Source -Result ("FAILED: " + $_.Exception.Message)
                $failed++
            }
        }
        Write-Host ("Restored: {0}  Failed: {1}" -f $restored, $failed)
    }
}
