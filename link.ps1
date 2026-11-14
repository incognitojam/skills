<#
.SYNOPSIS
    Links personal skills into the agent skill directories.

.PARAMETER GlobalInstructions
    Also links global/AGENTS.md for Claude Code and Codex without replacing
    existing files.

.PARAMETER ExternalSkills
    Also installs the third-party skills listed in external-skills.txt from the
    registry. Needs network access and removes skills selected by the last successful
    manifest but no longer selected.
#>
param([switch] $GlobalInstructions, [switch] $ExternalSkills)

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
    # Codex and the other agents read ~/.agents/skills.
    Add-Junction $_.FullName "$HOME\.agents\skills\$($_.Name)"
}

# Skills removed from this repository leave links behind. Only touch broken links
# into this checkout, since these directories also hold other people's skills.
"$HOME\.claude\skills", "$HOME\.agents\skills" | ForEach-Object {
    Get-ChildItem $_ -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $linkTarget = @($_.Target)[0]
        if ($_.LinkType -and $linkTarget -and
            $linkTarget.StartsWith("$repoRoot\skills\", [StringComparison]::OrdinalIgnoreCase) -and
            -not (Test-Path -LiteralPath $linkTarget)) {
            Remove-Item $_.FullName -Force
            Write-Output "removed: $($_.FullName)"
        }
    }
}

if ($GlobalInstructions) {
    $source = "$repoRoot\global\AGENTS.md"
    Add-FileLinkIfAbsent $source "$HOME\.claude\CLAUDE.md"
    Add-FileLinkIfAbsent $source "$HOME\.codex\AGENTS.md"
}

if ($ExternalSkills) {
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw 'npx is required to install external skills.'
    }

    Get-Content "$repoRoot\external-skills.txt" | ForEach-Object {
        $package = ($_ -replace '#.*$', '').Trim()
        if (-not $package) {
            return
        }

        Write-Output "installing: $package"
        $packageArgs = $package -split '\s+'
        # JSON mode fails if any requested skill is missing, even when others match.
        npx --yes skills@1.8.1 add @packageArgs --global --yes --json --agent claude-code codex
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install $package (exit code $LASTEXITCODE)."
        }
    }
    node "$repoRoot/scripts/prune-external-skills.mjs" "$repoRoot/external-skills.txt"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove deselected external skills (exit code $LASTEXITCODE)."
    }
}
