# Install the /flow skill into Claude Code (Windows PowerShell).
#   pwsh install.ps1 global            -> ~/.claude/skills/flow
#   pwsh install.ps1 project [dir]     -> <dir|cwd>/.claude/skills/flow
param(
  [ValidateSet('global','project')] [string]$Mode = 'global',
  [string]$ProjectDir = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src  = Join-Path $Here 'skill/flow'
if (-not (Test-Path (Join-Path $Src 'SKILL.md'))) { Write-Error "skill source not found at $Src"; exit 1 }

if ($Mode -eq 'global') {
  $Dest = Join-Path $HOME '.claude/skills/flow'
} else {
  $Dest = Join-Path $ProjectDir '.claude/skills/flow'
}
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
foreach ($d in 'runner','_templates','law','references','harness','playbooks') {
  $p = Join-Path $Dest $d
  if (Test-Path $p) { Remove-Item -Recurse -Force $p }
}
Copy-Item -Recurse -Force (Join-Path $Src '*') $Dest

Write-Host "installed /flow -> $Dest"
Write-Host "doctor:"
$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash) { Write-Host "  bash:   ok (required - the gate runner is bash)" } else { Write-Host "  bash:   MISSING - install Git for Windows (Git Bash)" }
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if ($py) { Write-Host "  python: ok (durable harness layer enabled)" } else { Write-Host "  python: none (engine still works; durable layer auto-disabled)" }
Write-Host ""
Write-Host "Done. In a project, type '/flow' in Claude Code."
