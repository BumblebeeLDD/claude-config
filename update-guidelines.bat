@echo off
REM ============================================================
REM  One-click updater for the guidelines repo.
REM  Double-click this file to pull the latest version from
REM  GitHub. Because ~/.claude/guidelines/guidelines.md is a
REM  symlink into this repo, your local Claude sees updates
REM  instantly after this runs.
REM ============================================================

REM Move into the folder this .bat lives in (the repo root),
REM no matter where it is on disk.
cd /d "%~dp0"

echo.
echo Pulling the latest guidelines from GitHub...
echo.

git pull

echo.
if %errorlevel%==0 (
  echo Done - your guidelines are up to date.
) else (
  echo Something went wrong - see the message above.
)
echo.
echo Press any key to close this window.
pause >nul
