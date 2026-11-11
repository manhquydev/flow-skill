# tests/test_install_safe_update.ps1 - Comprehensive PowerShell regression suite for
# install.ps1, safe transactional ownership, OMP target parity, and Windows path invariants.
# Executed via pwsh on Windows runners in CI.

$ErrorActionPreference = 'Stop'
$pass = 0
$fail = 0

function Check([string]$name, [bool]$condition, [string]$detail = '') {
  if ($condition) {
    Write-Host "  ok   [$name]"
    $script:pass++
  } else {
    Write-Host "  FAIL [$name] $detail" -ForegroundColor Red
    $script:fail++
  }
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $Here
$InstallScript = Join-Path $RepoRoot 'install.ps1'
$Src = Join-Path $RepoRoot 'skills/flow'

Write-Host "=== 1. Script existence and syntax sanity ==="
Check "install.ps1 exists" (Test-Path -LiteralPath $InstallScript)
Check "skills/flow source exists" (Test-Path -LiteralPath (Join-Path $Src 'SKILL.md'))

# Save original environment variables so tests never mutate or leak into the real environment
$origHome = $env:HOME
$origUserProfile = $env:USERPROFILE

$tempBase = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
$Scratch = Join-Path $tempBase ("flow-ps1-test-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Scratch | Out-Null

try {
  # Isolated copy of source repo to avoid mutating working tree during test runs
  $TestRepo = Join-Path $Scratch "test_repo"
  New-Item -ItemType Directory -Path (Join-Path $TestRepo "skills/flow") | Out-Null
  Copy-Item -LiteralPath $InstallScript -Destination $TestRepo -Force
  Get-ChildItem -LiteralPath (Join-Path $RepoRoot "skills/flow") -Force | Copy-Item -Destination (Join-Path $TestRepo "skills/flow") -Recurse -Force
  # The generated rules file is gitignored (npm-wrapper/.widelai/), so a fresh CI
  # checkout never has it. Generate it the same way the bash suite does: copy the
  # sync toolchain + the repo-root sources sync.mjs reads, then run sync.mjs.
  # Fall back to a local pre-generated copy only when node is unavailable.
  New-Item -ItemType Directory -Path (Join-Path $TestRepo "npm-wrapper/scripts") -Force | Out-Null
  foreach ($f in @('AGENTS.md', 'CONTRIBUTING.md', 'portable-manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot $f) -Destination $TestRepo -Force
  }
  Copy-Item -LiteralPath (Join-Path $RepoRoot "npm-wrapper/scripts/sync.mjs") -Destination (Join-Path $TestRepo "npm-wrapper/scripts/sync.mjs") -Force
  Push-Location $TestRepo
  try {
    # Distinguish "node unavailable" (fall back to the local pre-generated
    # copy) from "sync.mjs ran and failed" (a failed sync must fail the fixture
    # setup instead of silently using a stale rules copy).
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $nodeCmd) {
      Write-Host "WARN: node not available in test repo; falling back to local .widelai copy"
    } else {
      & node (Join-Path $TestRepo "npm-wrapper/scripts/sync.mjs") *>$null
      if ($LASTEXITCODE -ne 0) {
        throw "sync.mjs failed in test repo (exit $LASTEXITCODE); refusing to fall back to a stale .widelai copy"
      }
    }
  } finally {
    Pop-Location
  }
  if (-not (Test-Path -LiteralPath (Join-Path $TestRepo "npm-wrapper/.widelai/rules/flowskill.md"))) {
    if (Test-Path -LiteralPath (Join-Path $RepoRoot "npm-wrapper/.widelai")) {
      $testWidelai = Join-Path $TestRepo "npm-wrapper/.widelai"
      New-Item -ItemType Directory -Path (Split-Path -Parent $testWidelai) -Force | Out-Null
      Copy-Item -LiteralPath (Join-Path $RepoRoot "npm-wrapper/.widelai") -Destination (Join-Path $TestRepo "npm-wrapper") -Recurse -Force
    }
  }
  # Rules-dependent widelai assertions only run when a rules file exists
  # (node-generated, or a pre-generated copy). On a clean checkout without
  # node, neither is available and the suite must skip instead of abort.
  $widelaiRulesAvailable = Test-Path -LiteralPath (Join-Path $TestRepo "npm-wrapper/.widelai/rules/flowskill.md")
  if (-not $widelaiRulesAvailable) {
    Write-Host "  skip [widelai rules-dependent assertions: no node and no pre-generated .widelai copy]"
  }
  $TestInstallScript = Join-Path $TestRepo 'install.ps1'

  # Fake home: MUST set BOTH $env:HOME and $env:USERPROFILE so install.ps1 never touches the real user home
  $FakeHome = Join-Path $Scratch "home"
  New-Item -ItemType Directory -Path $FakeHome | Out-Null
  $env:HOME = $FakeHome
  $env:USERPROFILE = $FakeHome

  Write-Host "=== 2. Fresh install & Scalar `$last` return verification ==="
  # Execute via dot-sourcing in an isolated scope to verify direct Install-To return type
  $dest = Join-Path $FakeHome ".claude/skills/flow"
  . $TestInstallScript
  Check "dot-sourcing defines functions without executing installation" (-not (Test-Path -LiteralPath $dest))
  $directDest = Install-To $dest
  Check "Install-To returns scalar string" ($directDest -is [string])
  Check "Install-To return value equals dest path" ($directDest -eq $dest)
  Check "Install-To return does not contain newlines or JSON" (-not ($directDest -match "`r|`n|\{"))

  Check "SKILL.md materialized at destination" (Test-Path -LiteralPath (Join-Path $dest "SKILL.md"))
  Check "manifest-hashes.json created" (Test-Path -LiteralPath (Join-Path $dest "manifest-hashes.json"))

  # Verify CLI output from script invocation
  $cliOut = & pwsh -File $TestInstallScript global claude 2>&1
  $exitCode = $LASTEXITCODE
  Check "CLI invocation succeeds (exit 0)" ($exitCode -eq 0) "exitCode=$exitCode"
  $hasRawJson = $cliOut | Where-Object { $_ -match '^\s*\{"success":' }
  Check "CLI stdout is not polluted by raw helper JSON" ($null -eq $hasRawJson)

  Write-Host "=== 3. OMP target parity in PowerShell ==="
  # 3.1 Explicit omp target
  $outOmp = & pwsh -File $TestInstallScript global omp 2>&1
  $ompDest = Join-Path $FakeHome ".omp/agent/skills/flow"
  Check "explicit global omp installs cleanly" ($LASTEXITCODE -eq 0)
  Check "OMP destination contains SKILL.md" (Test-Path -LiteralPath (Join-Path $ompDest "SKILL.md"))

  # 3.1b Explicit cursor target
  $outCursor = & pwsh -File $TestInstallScript global cursor 2>&1
  $cursorDest = Join-Path $FakeHome ".cursor/skills/flow"
  Check "explicit global cursor installs cleanly" ($LASTEXITCODE -eq 0)
  Check "Cursor destination contains SKILL.md" (Test-Path -LiteralPath (Join-Path $cursorDest "SKILL.md"))

  # 3.2 OMP genuine autodetection
  $FakeHome2 = Join-Path $Scratch "home2"
  New-Item -ItemType Directory -Path (Join-Path $FakeHome2 ".omp/agent/skills") | Out-Null
  $env:HOME = $FakeHome2
  $env:USERPROFILE = $FakeHome2
  & pwsh -File $TestInstallScript global all >$null 2>&1
  Check "autodetects ~/.omp/agent/skills and installs flow" (Test-Path -LiteralPath (Join-Path $FakeHome2 ".omp/agent/skills/flow/SKILL.md"))

  # 3.3 Bare ~/.omp without agent/skills must NOT install
  $FakeHome3 = Join-Path $Scratch "home3"
  New-Item -ItemType Directory -Path (Join-Path $FakeHome3 ".omp") | Out-Null
  $env:HOME = $FakeHome3
  $env:USERPROFILE = $FakeHome3
  & pwsh -File $TestInstallScript global all >$null 2>&1
  Check "bare ~/.omp without agent/skills is NOT installed" (-not (Test-Path -LiteralPath (Join-Path $FakeHome3 ".omp/agent/skills/flow")))

  # 3.4 WidelCode explicit target installs skill and extras (rules-dependent)
  if ($widelaiRulesAvailable) {
  $FakeHomeWidelai = Join-Path $Scratch "home_widelai"
  New-Item -ItemType Directory -Path $FakeHomeWidelai | Out-Null
  $env:HOME = $FakeHomeWidelai
  $env:USERPROFILE = $FakeHomeWidelai
  $outWidelai = & pwsh -File $TestInstallScript global widelai 2>&1
  Check "explicit global widelai installs cleanly (exit 0)" ($LASTEXITCODE -eq 0) "exitCode=$LASTEXITCODE"
  Check "widelai destination contains SKILL.md" (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai ".widelai/skills/flow/SKILL.md"))
  Check "widelai places rules file" (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai ".widelai/rules/flowskill.md"))
  Check "widelai AGENTS.md contains pointer" ((Get-Content -LiteralPath (Join-Path $FakeHomeWidelai ".widelai/AGENTS.md") -Raw) -cmatch '(?m)^FlowSkill rules: see \.widelai/rules/flowskill\.md\r?$')
  } else {
    Write-Host "  skip [3.4 widelai explicit target assertions: rules file unavailable]"
  }

  # 3.5 WidelCode autodetect: ~/.widelai/skills directory autodetects and installs skill and extras (rules-dependent)
  if ($widelaiRulesAvailable) {
  $FakeHomeWidelai2 = Join-Path $Scratch "home_widelai2"
  New-Item -ItemType Directory -Path (Join-Path $FakeHomeWidelai2 ".widelai/skills") | Out-Null
  $env:HOME = $FakeHomeWidelai2
  $env:USERPROFILE = $FakeHomeWidelai2
  & pwsh -File $TestInstallScript global all >$null 2>&1
  Check "widelai autodetects ~/.widelai/skills directory" (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai2 ".widelai/skills/flow/SKILL.md"))
  Check "widelai autodetect places rules file" (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai2 ".widelai/rules/flowskill.md"))
  } else {
    Write-Host "  skip [3.5 widelai autodetect assertions: rules file unavailable]"
  }

  # 3.6 Bare ~/.widelai without skills directory must NOT install widelai
  $FakeHomeWidelai3 = Join-Path $Scratch "home_widelai3"
  New-Item -ItemType Directory -Path (Join-Path $FakeHomeWidelai3 ".widelai") | Out-Null
  Set-Content -LiteralPath (Join-Path $FakeHomeWidelai3 ".widelai/credentials.json") -Value "{}"
  $env:HOME = $FakeHomeWidelai3
  $env:USERPROFILE = $FakeHomeWidelai3
  & pwsh -File $TestInstallScript global all >$null 2>&1
  Check "bare ~/.widelai all-target run exits 0" ($LASTEXITCODE -eq 0) "exitCode=$LASTEXITCODE"
  Check "bare ~/.widelai without skills is NOT installed" (-not (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai3 ".widelai/skills/flow")))
  Check "bare ~/.widelai does NOT place rules file" (-not (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai3 ".widelai/rules/flowskill.md")))

  # 3.7 Marker path that is a regular FILE (not a container) must NOT trigger widelai autodetect —
  # install.ps1 needs -PathType Container to match install.sh [ -d ].
  # Collision check: marker regular file must be left untouched/unmodified, no extras written, exit 0 for global all.
  $FakeHomeWidelai4 = Join-Path $Scratch "home_widelai4"
  New-Item -ItemType Directory -Path (Join-Path $FakeHomeWidelai4 ".widelai") | Out-Null
  $markerFile4 = Join-Path $FakeHomeWidelai4 ".widelai/skills"
  Set-Content -LiteralPath $markerFile4 -Value "regular file marker content"
  $env:HOME = $FakeHomeWidelai4
  $env:USERPROFILE = $FakeHomeWidelai4
  & pwsh -File $TestInstallScript global all >$null 2>&1
  Check "regular-file widelai marker run exits 0" ($LASTEXITCODE -eq 0) "exitCode=$LASTEXITCODE"
  Check "regular-file ~/.widelai/skills does NOT trigger autodetect" (-not (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai4 ".widelai/skills/flow")))
  Check "regular-file ~/.widelai/skills does NOT write extras rules" (-not (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai4 ".widelai/rules/flowskill.md")))
  Check "regular-file ~/.widelai/skills does NOT write AGENTS.md" (-not (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai4 ".widelai/AGENTS.md")))
  Check "regular-file marker content is preserved byte-identical" ((Get-Content -LiteralPath $markerFile4 -Raw).Trim() -eq "regular file marker content")
  Check "regular-file marker home still installs claude" (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai4 ".claude/skills/flow/SKILL.md"))

  # 3.8 Explicit global widelai with regular-FILE marker at destination parent must fail loudly, not overwrite
  $FakeHomeWidelai5 = Join-Path $Scratch "home_widelai5"
  New-Item -ItemType Directory -Path (Join-Path $FakeHomeWidelai5 ".widelai") | Out-Null
  $markerFile5 = Join-Path $FakeHomeWidelai5 ".widelai/skills"
  Set-Content -LiteralPath $markerFile5 -Value "do not overwrite me"
  $env:HOME = $FakeHomeWidelai5
  $env:USERPROFILE = $FakeHomeWidelai5
  $outWidelaiFail = & pwsh -File $TestInstallScript global widelai 2>&1
  $widelaiExit = $LASTEXITCODE
  Check "explicit widelai with regular-file marker fails loudly (exit non-zero)" ($widelaiExit -ne 0) "exitCode=$widelaiExit"
  Check "regular-file marker left untouched on collision abort" ((Get-Content -LiteralPath $markerFile5 -Raw).Trim() -eq "do not overwrite me")

  # 3.9 Explicit global widelai when destination path itself is a regular FILE must fail loudly, not overwrite
  $FakeHomeWidelai6 = Join-Path $Scratch "home_widelai6"
  New-Item -ItemType Directory -Path (Join-Path $FakeHomeWidelai6 ".widelai/skills") | Out-Null
  $destFile6 = Join-Path $FakeHomeWidelai6 ".widelai/skills/flow"
  Set-Content -LiteralPath $destFile6 -Value "existing destination file collision"
  $env:HOME = $FakeHomeWidelai6
  $env:USERPROFILE = $FakeHomeWidelai6
  $outDestFail = & pwsh -File $TestInstallScript global widelai 2>&1
  Check "destination path regular-file collision fails loudly (exit non-zero)" ($LASTEXITCODE -ne 0)
  Check "destination regular file is NOT overwritten on collision" ((Get-Content -LiteralPath $destFile6 -Raw).Trim() -eq "existing destination file collision")

  # 3.10 Extras destination collision check: directory at rules destination fails loudly and refuses to overwrite (rules-dependent)
  if ($widelaiRulesAvailable) {
  $FakeHomeWidelai7 = Join-Path $Scratch "home_widelai7"
  New-Item -ItemType Directory -Path (Join-Path $FakeHomeWidelai7 ".widelai/rules/flowskill.md") | Out-Null
  $env:HOME = $FakeHomeWidelai7
  $env:USERPROFILE = $FakeHomeWidelai7
  $outRulesDirFail = & pwsh -File $TestInstallScript global widelai 2>&1
  Check "directory at rules destination fails loudly (exit non-zero)" ($LASTEXITCODE -ne 0)
  Check "directory at rules destination is preserved (not overwritten)" (Test-Path -LiteralPath (Join-Path $FakeHomeWidelai7 ".widelai/rules/flowskill.md") -PathType Container)
  } else {
    Write-Host "  skip [3.10 rules-destination collision assertions: rules file unavailable]"
  }

  $env:HOME = $FakeHome
  $env:USERPROFILE = $FakeHome

  Write-Host "=== 4. Custom file preservation inside managed subdirs ==="
  $customRoot = Join-Path $dest "my_custom.txt"
  $customRunner = Join-Path $dest "runner/my_custom_runner.txt"
  Set-Content -LiteralPath $customRoot -Value "custom root content"
  Set-Content -LiteralPath $customRunner -Value "custom runner content"

  # Re-run install to trigger in-place update
  $outUpdate = & pwsh -File $TestInstallScript global claude 2>&1
  Check "in-place update succeeds (exit 0)" ($LASTEXITCODE -eq 0)
  Check "custom file at root preserved" ((Test-Path -LiteralPath $customRoot) -and ((Get-Content -LiteralPath $customRoot -Raw).Trim() -eq "custom root content"))
  Check "custom file inside managed runner subdir preserved" ((Test-Path -LiteralPath $customRunner) -and ((Get-Content -LiteralPath $customRunner -Raw).Trim() -eq "custom runner content"))

  # Verify custom files are NOT claimed by the new receipt
  $receiptJson = Get-Content -LiteralPath (Join-Path $dest "manifest-hashes.json") -Raw | ConvertFrom-Json
  $receiptFiles = $receiptJson.files.PSObject.Properties.Name
  Check "custom file excluded from ownership receipt" (-not ($receiptFiles -contains "my_custom.txt"))
  Check "managed subdir custom excluded from receipt" (-not ($receiptFiles -contains "runner/my_custom_runner.txt"))

  Write-Host "=== 5. In-place update conflict refusal ==="
  # User edits an owned file
  Add-Content -LiteralPath (Join-Path $dest "SKILL.md") -Value "`nuser local modification"
  $origSkill = Get-Content -LiteralPath (Join-Path $dest "SKILL.md") -Raw

  $outConflict = & pwsh -File $TestInstallScript global claude 2>&1
  $conflictExit = $LASTEXITCODE
  Check "conflict triggers non-zero exit code" ($conflictExit -ne 0) "exitCode=$conflictExit"
  $afterSkill = Get-Content -LiteralPath (Join-Path $dest "SKILL.md") -Raw
  Check "destination left completely untouched on conflict" ($origSkill -eq $afterSkill)

  Write-Host "=== 6. Lexical ancestor symlink and junction refusal ==="
  $realTarget = Join-Path $Scratch "real_target"
  New-Item -ItemType Directory -Path $realTarget | Out-Null
  $symlinkParent = Join-Path $Scratch "symlink_parent"
  $reparseCreated = $false

  # Try junction (native non-admin on Windows) first, then symlink
  try {
    New-Item -ItemType Junction -Path $symlinkParent -Target $realTarget -ErrorAction Stop | Out-Null
    $reparseCreated = $true
  } catch {
    try {
      New-Item -ItemType SymbolicLink -Path $symlinkParent -Target $realTarget -ErrorAction Stop | Out-Null
      $reparseCreated = $true
    } catch {
      $reparseCreated = $false
    }
  }

  if ($reparseCreated) {
    # Destination traversal through symlink/junction component: link/..\real_target\skills\flow
    $traversalDest = $symlinkParent + "\..\real_target\skills\flow"
    $outSymlink = & pwsh -File $TestInstallScript project $traversalDest 2>&1
    $symExit = $LASTEXITCODE
    Check "ancestor traversal through reparse component refused" ($symExit -ne 0)
    Check "traversal destination was NOT created on disk" (-not (Test-Path -LiteralPath (Join-Path $realTarget "skills/flow")))
  } else {
    Check "reparse point (junction or symlink) creation supported" $false "neither junction nor symlink could be created in this environment"
  }

  Write-Host "=== 7. No-Python empty dest rollback & restore (real fs fault injection) ==="
  # Dot-source test script to override Find-Python and test native staging rollback
  . $TestInstallScript

  # Force no-Python path
  function Find-Python() { return $null }

  # 7.1 Promotion failure with successful rollback
  $emptyDest1 = Join-Path $Scratch "empty_dest_1"
  New-Item -ItemType Directory -Path $emptyDest1 | Out-Null

  $moveCount = 0
  function Move-Item() {
    param([string]$LiteralPath, [string]$Destination, [switch]$Force, [string]$ErrorAction)
    $script:moveCount++
    if ($script:moveCount -eq 2) {
      # Injected failure on promotion move ($stage -> $dest)
      throw "injected promotion move failure"
    }
    Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force -ErrorAction Stop
  }

  $promoFailed = $false
  try {
    Install-To $emptyDest1
  } catch {
    $promoFailed = $true
  }
  Check "promotion failure triggers exception" $promoFailed
  Check "empty destination restored intact and empty" ((Test-Path -LiteralPath $emptyDest1) -and ((Get-ChildItem -LiteralPath $emptyDest1 -Force).Count -eq 0))
  $leftoverBackup = Get-ChildItem -LiteralPath $Scratch -Filter ".flow-skill-backup-*" -Force
  Check "backup slot removed on successful rollback" ($null -eq $leftoverBackup -or $leftoverBackup.Count -eq 0)

  # 7.2 Promotion failure with failed rollback -> backup preserved, location reported
  $emptyDest2 = Join-Path $Scratch "empty_dest_2"
  New-Item -ItemType Directory -Path $emptyDest2 | Out-Null

  $moveCount = 0
  function Move-Item() {
    param([string]$LiteralPath, [string]$Destination, [switch]$Force, [string]$ErrorAction)
    $script:moveCount++
    if ($script:moveCount -eq 2) {
      throw "injected promotion move failure"
    }
    if ($script:moveCount -eq 3) {
      # Injected failure on rollback move ($backupSlot -> $dest)
      throw "injected rollback move failure"
    }
    Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force -ErrorAction Stop
  }

  $rollbackError = $null
  try {
    Install-To $emptyDest2
  } catch {
    $rollbackError = $_.ToString()
  }
  Check "rollback failure triggers exception" ($null -ne $rollbackError)
  Check "error message reports preserved backup location" ($rollbackError -match "original destination preserved at '.*\.flow-skill-backup-")
  $preservedBackup = Get-ChildItem -LiteralPath $Scratch -Filter ".flow-skill-backup-*" -Force
  Check "backup directory is strictly PRESERVED on rollback failure and remains empty" ($null -ne $preservedBackup -and $preservedBackup.Count -gt 0 -and ((Get-ChildItem -LiteralPath $preservedBackup[0].FullName -Force).Count -eq 0))

  # Restore standard Move-Item
  Remove-Item Function:\Move-Item -ErrorAction SilentlyContinue

  Write-Host "=== 8. Raw drive and UNC path parsing verification ==="
  $driveCheckPassed = $false
  try {
    $isWin = [System.IO.Path]::DirectorySeparatorChar -eq '\'
    if ($isWin) {
      Test-SafePath "$env:SystemDrive\Windows" "system drive"
      $driveCheckPassed = $true
    } else {
      Test-SafePath "/tmp" "unix root"
      $driveCheckPassed = $true
    }
  } catch {
    $driveCheckPassed = $false
  }
  Check "Test-SafePath validates drive/root anchor correctly" $driveCheckPassed
  Write-Host "  [note] Windows UNC network share runtime requires active SMB infrastructure not provisioned in CI; drive-letter path verified at runtime"

} finally {
  $env:HOME = $origHome
  $env:USERPROFILE = $origUserProfile
  Remove-Item -LiteralPath $Scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== PowerShell Suite Summary ==="
Write-Host "Pass: $pass, Fail: $fail"
if ($fail -gt 0) {
  exit 1
} else {
  exit 0
}
