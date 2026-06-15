# Install the flow skill into every AI-harness skills dir on this machine (Windows PowerShell 7+).
#   pwsh install.ps1 global                     -> ~/.claude/skills/flow (always)
#                                                  + ~/.codex/skills/flow  (if ~/.codex/skills exists)
#                                                  + ~/.agents/skills/flow (if ~/.agents/skills exists)
#   pwsh install.ps1 global claude|codex|agents -> only that one harness
#   pwsh install.ps1 project [dir]              -> <dir|cwd>/.claude/skills/flow
# Re-run after any update to re-sync every harness (the repo is the single source of truth).
param(
  [ValidateSet('global','project')] [string]$Mode = 'global',
  [string]$Arg2 = ''
)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src  = Join-Path $Here 'skills/flow'
if (-not (Test-Path (Join-Path $Src 'SKILL.md'))) { Write-Error "skill source not found at $Src"; exit 1 }

function Install-To([string]$dest) {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  foreach ($d in 'runner','_templates','law','references','harness','playbooks') {
    $p = Join-Path $dest $d
    if (Test-Path $p) { Remove-Item -Recurse -Force $p }
  }
  # -Force on Get-ChildItem includes dotfiles, matching bash `cp -r "$SRC/."` parity
  Get-ChildItem -Force $Src | Copy-Item -Destination $dest -Recurse -Force
  Write-Host "installed flow -> $dest"
  return $dest
}

$last = $null
if ($Mode -eq 'global') {
  $target = if ($Arg2 -ne '') { $Arg2 } else { 'all' }
  if ($target -eq 'all' -or $target -eq 'claude') {
    $last = Install-To (Join-Path $HOME '.claude/skills/flow')
  }
  if ($target -eq 'codex'  -or ($target -eq 'all' -and (Test-Path (Join-Path $HOME '.codex/skills')))) {
    $last = Install-To (Join-Path $HOME '.codex/skills/flow')
  }
  if ($target -eq 'agents' -or ($target -eq 'all' -and (Test-Path (Join-Path $HOME '.agents/skills')))) {
    $last = Install-To (Join-Path $HOME '.agents/skills/flow')
  }
  if (-not $last) { Write-Error "unknown target '$target' (use claude|codex|agents|all)"; exit 1 }
} else {
  $dir = if ($Arg2 -ne '') { $Arg2 } else { (Get-Location).Path }
  $last = Install-To (Join-Path $dir '.claude/skills/flow')
}

Write-Host ""
# flow's runner needs Git Bash; prefer it over WSL's System32\bash.exe (WSL can't see C:/ paths)
$bashExe = $null
foreach ($c in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe")) {
  if (Test-Path $c) { $bashExe = $c; break }
}
if (-not $bashExe) {
  $g = Get-Command bash -ErrorAction SilentlyContinue
  if ($g -and $g.Source -notmatch 'System32[\\/]bash\.exe') { $bashExe = $g.Source }
}
if ($bashExe) {
  # forward-slash path so Git Bash doesn't strip Windows backslashes; doctor stays non-fatal (parity with bash `|| true`)
  $runner = (Join-Path $last 'runner/flow.sh') -replace '\\','/'
  try { & $bashExe $runner doctor } catch { Write-Warning "doctor reported issues (non-fatal): $_" }
} else {
  Write-Host "  bash: Git Bash not found - install Git for Windows so the gate runner can execute."
}
Write-Host ""
Write-Host "Done. Claude Code: type /flow . Codex CLI: type `$flow (restart Codex once to load a new skill)."
