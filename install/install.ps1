<#
.SYNOPSIS
    Install or update Agent Playbook for GitHub Copilot (VS Code, Visual Studio) and/or Claude Code on Windows.

.DESCRIPTION
    DryRun (the default) shows what would change. Execute applies it. Add -Uninstall to remove
    everything it installed.

    Targets (default: copilot; use -Target claude,copilot for both):
      copilot  skills -> %USERPROFILE%\.copilot\skills\<name>\  (read by VS Code and Visual Studio)
               core rules and local profile -> %USERPROFILE%\.copilot\instructions\agent-playbook.instructions.md (VS Code)
               core rules and local profile -> a marked block in %USERPROFILE%\copilot-instructions.md (Visual Studio)
      claude   skills -> %USERPROFILE%\.claude\skills\<name>\, core rules and local profile -> %USERPROFILE%\.claude\agent-playbook.md,
               and an "@~/.claude/agent-playbook.md" import line in %USERPROFILE%\.claude\CLAUDE.md
               (only for Claude Code running natively on Windows; for Claude Code in WSL use install.sh there)
      profile  local preferences -> %USERPROFILE%\.agent-playbook\user-profile.md (created once, preserved on uninstall)

    Visual Studio also reads %USERPROFILE%\.claude\skills, so with both targets it lists each skill
    twice. The copies are identical, so this is cosmetic.

    Files are copied, not linked. Each installed skill folder holds a .agent-playbook marker; only
    marked folders are replaced or removed. Any existing file it edits is backed up first as
    <file>.bak-<timestamp>.

.EXAMPLE
    .\install\install.ps1
    .\install\install.ps1 -Mode Execute
    .\install\install.ps1 -Target copilot,claude -Mode Execute
    .\install\install.ps1 -Uninstall -Mode Execute
#>
[CmdletBinding()]
param(
    [ValidateSet('DryRun', 'Execute')]
    [string]$Mode = 'DryRun',

    [ValidateSet('copilot', 'claude')]
    [string[]]$Target = @('copilot'),

    [switch]$Uninstall,

    # Where the user profile folders live. Change only for testing.
    [string]$ProfileRoot = $env:USERPROFILE
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$repo = Split-Path -Parent $PSScriptRoot
$marker = '.agent-playbook'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$execute = $Mode -eq 'Execute'
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM, so YAML frontmatter parses
$importLine = '@~/.claude/agent-playbook.md'
$blockBegin = '<!-- agent-playbook:begin (managed by Agent Playbook install.ps1; edits inside are replaced) -->'
$blockEnd = '<!-- agent-playbook:end -->'
$profileFile = Join-Path (Join-Path $ProfileRoot '.agent-playbook') 'user-profile.md'
$profileTemplate = Join-Path $repo 'instructions\user-profile.template.md'

$version = 'unknown'
try {
    $v = & git -C $repo rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $v) { $version = $v }
    $dirty = & git -C $repo status --porcelain 2>$null
    if ($dirty) { $version = "$version+uncommitted" }
} catch { }

$action = if ($Uninstall) { 'uninstall' } else { 'install' }
Write-Host ("Agent Playbook {0}, {1}, {2}, targets: {3}" -f $version, $Mode, $action, ($Target -join ','))

function Say([string]$Text) { Write-Host "  $Text" }

function Backup-File([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Say "back up $Path -> $Path.bak-$stamp"
        if ($execute) { Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" }
    }
}

function Write-TextFile([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        Say "create folder $parent"
        if ($execute) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }
    Backup-File $Path
    Say "write $Path"
    if ($execute) { [IO.File]::WriteAllText($Path, $Text, $utf8) }
}

function Test-IsLink([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Sync-Skills([string]$Dest) {
    if (Test-Path -LiteralPath $Dest) {
        foreach ($d in Get-ChildItem -LiteralPath $Dest -Directory -Force) {
            if (Test-IsLink $d.FullName) { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $d.FullName $marker))) { continue }
            $inRepo = Test-Path -LiteralPath (Join-Path $repo "skills\$($d.Name)\SKILL.md")
            if ($Uninstall -or -not $inRepo) {
                Say "remove $($d.FullName)"
                if ($execute) { Remove-Item -LiteralPath $d.FullName -Recurse -Force }
            }
        }
    }
    if ($Uninstall) { return }

    if (-not (Test-Path -LiteralPath $Dest)) {
        Say "create folder $Dest"
        if ($execute) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    }
    foreach ($src in Get-ChildItem -LiteralPath (Join-Path $repo 'skills') -Directory) {
        $d = Join-Path $Dest $src.Name
        if (Test-Path -LiteralPath $d) {
            if (Test-IsLink $d) { Say "SKIP $($src.Name): $d is a link from another setup. Remove it, then run again."; continue }
            if (-not (Test-Path -LiteralPath (Join-Path $d $marker))) { Say "SKIP $($src.Name): $d exists and wasn't installed by Agent Playbook."; continue }
            Say "replace $d"
            if ($execute) { Remove-Item -LiteralPath $d -Recurse -Force }
        }
        else { Say "copy $($src.FullName) -> $d" }
        if ($execute) {
            Copy-Item -LiteralPath $src.FullName -Destination $d -Recurse
            [IO.File]::WriteAllText((Join-Path $d $marker), "Installed by Agent Playbook $version from $repo on $stamp`n", $utf8)
        }
    }
}

$core = [IO.File]::ReadAllText((Join-Path $repo 'instructions\core.md'))

function Ensure-UserProfile {
    if (Test-Path -LiteralPath $profileFile) { return }
    Say "create local user profile from template: $profileFile"
    if ($execute) {
        $parent = Split-Path -Parent $profileFile
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $profileTemplate -Destination $profileFile
    }
}

function Get-InstalledCore {
    if (Test-Path -LiteralPath $profileFile) {
        return $core + "`n`n---`n`n" + [IO.File]::ReadAllText($profileFile)
    }
    return $core
}

function Install-Copilot {
    Write-Host 'GitHub Copilot:'
    $base = Join-Path $ProfileRoot '.copilot'
    Sync-Skills (Join-Path $base 'skills')

    # VS Code: a user-level instructions file that applies to every file.
    $instr = Join-Path $base 'instructions\agent-playbook.instructions.md'
    if ($Uninstall) {
        if (Test-Path -LiteralPath $instr) { Say "remove $instr"; if ($execute) { Remove-Item -LiteralPath $instr } }
        if (Test-Path -LiteralPath $profileFile) { Say "keep local user profile $profileFile" }
    }
    else {
        Ensure-UserProfile
        $installedCore = Get-InstalledCore
        $front = "---`nname: Agent Playbook`ndescription: Core working rules for every project`napplyTo: `"**`"`n---`n`n"
        Write-TextFile $instr ($front + $installedCore)
    }

    # Visual Studio: %USERPROFILE%\copilot-instructions.md, shared with Copilot memories, so only a marked block is managed.
    $vs = Join-Path $ProfileRoot 'copilot-instructions.md'
    $existing = if (Test-Path -LiteralPath $vs) { [IO.File]::ReadAllText($vs) } else { '' }
    $pattern = '(?s)\r?\n?' + [regex]::Escape($blockBegin) + '.*?' + [regex]::Escape($blockEnd) + '\r?\n?'
    $hasBlock = [regex]::IsMatch($existing, $pattern)
    # The pattern also takes the line break before the block, if there is one. Put back exactly
    # what was taken, so a block at the top of the file stays at the top and a rerun is a no-op.
    $lead = { param($m) if ($m.Value -match '^\r?\n') { "`n" } else { '' } }
    if ($Uninstall) {
        if ($hasBlock) {
            Backup-File $vs
            Say "remove the Agent Playbook block from $vs"
            $removed = ([regex]$pattern).Replace($existing, [Text.RegularExpressions.MatchEvaluator] { param($m) & $lead $m }, 1)
            if ($execute) { [IO.File]::WriteAllText($vs, $removed, $utf8) }
        }
        if (Test-Path -LiteralPath $profileFile) { Say "keep local user profile $profileFile" }
        return
    }
    Ensure-UserProfile
    $installedCore = Get-InstalledCore
    $block = "$blockBegin`n$installedCore`n$blockEnd`n"
    if ($hasBlock) {
        # A MatchEvaluator keeps any '$' in the rules from being read as a substitution.
        $new = ([regex]$pattern).Replace($existing, [Text.RegularExpressions.MatchEvaluator] { param($m) (& $lead $m) + $block }, 1)
        $verb = 'update the Agent Playbook block in'
    }
    elseif ($existing) {
        $new = $existing.TrimEnd() + "`n`n" + $block
        $verb = 'add the Agent Playbook block to'
    }
    else {
        $new = $block
        $verb = 'create'
    }
    if ($new -ne $existing) {
        Backup-File $vs
        Say "$verb $vs"
        if ($execute) { [IO.File]::WriteAllText($vs, $new, $utf8) }
    }
    else { Say "$vs is already current" }
}

function Install-Claude {
    Write-Host 'Claude Code:'
    $base = Join-Path $ProfileRoot '.claude'
    Sync-Skills (Join-Path $base 'skills')
    $coreFile = Join-Path $base 'agent-playbook.md'
    $md = Join-Path $base 'CLAUDE.md'
    $lines = if (Test-Path -LiteralPath $md) { @(Get-Content -LiteralPath $md) } else { @() }
    $hasImport = $lines -contains $importLine

    if ($Uninstall) {
        if (Test-Path -LiteralPath $coreFile) { Say "remove $coreFile"; if ($execute) { Remove-Item -LiteralPath $coreFile } }
        if (Test-Path -LiteralPath $profileFile) { Say "keep local user profile $profileFile" }
        if ($hasImport) {
            Backup-File $md
            Say "remove the line '$importLine' from $md"
            if ($execute) { [IO.File]::WriteAllText($md, ((@($lines | Where-Object { $_ -ne $importLine }) -join "`n") + "`n"), $utf8) }
        }
        return
    }
    Ensure-UserProfile
    $installedCore = Get-InstalledCore
    Write-TextFile $coreFile $installedCore
    if ($hasImport) { Say "$md already imports the core rules" }
    else {
        Backup-File $md
        Say "append the line '$importLine' to $md"
        if ($execute) {
            if (-not (Test-Path -LiteralPath $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }
            [IO.File]::AppendAllText($md, "`n$importLine`n", $utf8)
        }
    }
}

foreach ($t in $Target) {
    switch ($t) {
        'copilot' { Install-Copilot }
        'claude' { Install-Claude }
    }
}

Write-Host ''
if ($execute) { Write-Host 'Done. Restart VS Code / Visual Studio (or start a new chat) to pick up the changes.' }
else { Write-Host 'Nothing was changed. Run again with -Mode Execute to apply.' }
