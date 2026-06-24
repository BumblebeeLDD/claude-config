@echo off
REM ============================================================
REM  One-click "save my changes" for the guidelines repo.
REM  Double-click this AFTER you've edited and saved
REM  guidelines.md. It asks for a short description, then
REM  uploads your change to GitHub.
REM ============================================================

REM Move into the folder this .bat lives in (the repo root).
cd /d "%~dp0"

echo.
echo ============================================
echo   Save guidelines changes to GitHub
echo ============================================
echo.

REM Stage every change in the repo.
git add -A

REM If nothing changed, stop here with a friendly note.
git diff --cached --quiet
if %errorlevel%==0 (
  echo Nothing to save - the file is already up to date on GitHub.
  echo.
  echo Press any key to close.
  pause >nul
  exit /b 0
)

REM Ask for a short description of the change.
set "msg="
set /p "msg=Briefly describe your change, then press Enter: "
if "%msg%"=="" set "msg=Update guidelines"

git commit -m "%msg%"

echo.
echo Uploading to GitHub...
git push
if %errorlevel%==0 (
  echo.
  echo Done - your change is saved to GitHub.
) else (
  echo.
  echo Something went wrong during upload - see the message above.
)

echo.
echo Press any key to close.
pause >nul
