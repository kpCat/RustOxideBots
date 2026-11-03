@echo off
setlocal
chcp 65001 >nul
pushd "%~dp0rustds" >nul 2>&1
if errorlevel 1 exit /b 2
if not exist "RustDedicated.exe" (
    echo RustDedicated.exe is missing.
    popd
    exit /b 3
)
rem Replace the marker locally with your existing arguments; never commit them.
".\RustDedicated.exe" @@SERVER_ARGUMENTS@@
set "server_exit=%errorlevel%"
popd
if not "%server_exit%"=="0" echo RustDedicated exited with code %server_exit%.
exit /b %server_exit%
