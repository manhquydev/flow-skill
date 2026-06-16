@echo off
rem flow gate-engine launcher for Windows shells (PowerShell / cmd / Codex).
rem Codex and PowerShell resolve a bare `bash` to WSL (C:\WINDOWS\system32\bash.exe),
rem which cannot read C:/ paths and fails with "No such file or directory".
rem This finds Git Bash and runs the runner with a forward-slash path it accepts.
setlocal
set "SELF=%~dp0flow.sh"
set "SELF=%SELF:\=/%"
set "GB=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%GB%" set "GB=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not exist "%GB%" set "GB=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not exist "%GB%" (
  echo flow: Git Bash not found - install Git for Windows ^(https://git-scm.com^) so the gate engine can run.
  exit /b 1
)
"%GB%" "%SELF%" %*
rem propagate the gate engine's exit code (0/1) - it is flow's ground truth
exit /b %ERRORLEVEL%
