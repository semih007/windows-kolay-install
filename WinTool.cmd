@echo off
setlocal
cd /d "%~dp0"
set "logPath=%~dp0WinTool.txt"
set "WINTOOL_LOG_PATH=%logPath%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\WinTool.ps1"
set "exitCode=%errorlevel%"
>> "%logPath%" echo %date% %time% - WinTool penceresi kapandi veya betik sonlandi.
if not "%exitCode%"=="0" pause
endlocal
