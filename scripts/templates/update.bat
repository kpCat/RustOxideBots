@echo off
setlocal
pushd "%~dp0" >nul 2>&1
if errorlevel 1 exit /b 2
if not exist "steam\steamcmd.exe" (
    echo Update refused: SteamCMD is missing.
    popd
    exit /b 2
)
if not exist "update_script.txt" (
    echo Update refused: update_script.txt is missing.
    popd
    exit /b 3
)
if not exist "update-prerequisites\oxide-compatible.zip" (
    echo Update refused: no verified compatible Oxide package is available.
    popd
    exit /b 4
)
rem Fail closed even when a file exists: existence does not prove compatibility.
rem A later task must implement and verify backup, compatibility and Oxide restore.
echo Update refused: Rust/Oxide backup and restore workflow is not verified.
echo No SteamCMD was started. Follow the documented owner update procedure.
popd
exit /b 78
