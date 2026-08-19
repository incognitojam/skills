param([switch] $GlobalInstructions)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

function Add-Junction($source, $target) {
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    $existing = Get-Item $target -Force -ErrorAction SilentlyContinue

    if ($existing) {
        if (-not $existing.LinkType) {
            throw "$target already exists and is not a link. Move it aside, then rerun this script."
        }
        if (@($existing.Target)[0] -eq $source) {
            Write-Output "ok: $target -> $source"
            return
        }
        Remove-Item $target -Force
    }

    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    Write-Output "linked: $target -> $source"
}

function Add-FileLinkIfAbsent($source, $target) {
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    if (Get-Item $target -Force -ErrorAction SilentlyContinue) {
        Write-Output "skipped: $target already exists and was left unchanged"
        return
    }

    try {
        New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
    }
    catch {
        New-Item -ItemType HardLink -Path $target -Target $source | Out-Null
    }
    Write-Output "linked: $target -> $source"
}

Get-ChildItem "$repoRoot\skills" -Directory | ForEach-Object {
    Add-Junction $_.FullName "$HOME\.claude\skills\$($_.Name)"
}

foreach ($name in 'oracle', 'designer') {
    Add-Junction "$repoRoot\skills\$name" "$HOME\.agents\skills\$name"
}

if ($GlobalInstructions) {
    $source = "$repoRoot\global\AGENTS.md"
    Add-FileLinkIfAbsent $source "$HOME\.claude\CLAUDE.md"
    Add-FileLinkIfAbsent $source "$HOME\.codex\AGENTS.md"
}
