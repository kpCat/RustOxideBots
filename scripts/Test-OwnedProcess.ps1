#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
# Failure protected: a timeout/exception or controller exit leaves its child alive,
# or cleanup kills an unrelated process. The executable is a sleeping PowerShell.
$source = Join-Path $PSScriptRoot 'OwnedServerProcess.cs'
if (-not (Test-Path $source)) { throw 'Missing owned-process lifecycle implementation' }
Add-Type -Path $source
$exe = Join-Path $PSHOME 'powershell.exe'
$foreignInfo = New-Object Diagnostics.ProcessStartInfo
$foreignInfo.FileName = $exe
$foreignInfo.Arguments = '-NoProfile -Command Start-Sleep -Seconds 60'
$foreignInfo.UseShellExecute = $false
$foreignInfo.CreateNoWindow = $true
$foreign = [Diagnostics.Process]::Start($foreignInfo)
$owned = $null
try {
    $owned = [RustBots.OwnedServerProcess]::Start($exe, '-NoProfile -Command Start-Sleep -Seconds 60', $PSScriptRoot)
    $child = $owned.Process
    if ($child.HasExited) { throw 'Owned fixture failed to start' }
    try { throw 'fixture exception' } catch { } finally { $owned.Dispose() }
    if (-not $child.WaitForExit(5000)) { throw 'Owned fixture survived job close' }
    if ($foreign.HasExited) { throw 'Cleanup touched unrelated process' }
    Write-Output 'PASS: owned job cleanup after exception; unrelated process survives'

    $fixture = Join-Path (Split-Path $PSScriptRoot -Parent) ('.local\tests\' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $fixture | Out-Null
    $pidPath = Join-Path $fixture 'child.pid'
    $controllerScript = Join-Path $fixture 'controller.ps1'
    @'
param($Source, $Exe, $PidPath)
Add-Type -Path $Source
$owned = [RustBots.OwnedServerProcess]::Start($Exe, '-NoProfile -Command Start-Sleep -Seconds 60', $PSScriptRoot)
$owned.Process.Id | Set-Content -LiteralPath $PidPath
Start-Sleep -Seconds 60
'@ | Set-Content -LiteralPath $controllerScript -Encoding ASCII
    $controllerInfo = New-Object Diagnostics.ProcessStartInfo
    $controllerInfo.FileName = $exe
    $controllerInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $controllerScript + '" "' + $source + '" "' + $exe + '" "' + $pidPath + '"'
    $controllerInfo.UseShellExecute = $false
    $controllerInfo.CreateNoWindow = $true
    $controller = [Diagnostics.Process]::Start($controllerInfo)
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while (-not (Test-Path $pidPath) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path $pidPath)) { throw 'Controller failed to create owned child' }
        $child = [Diagnostics.Process]::GetProcessById([int](Get-Content $pidPath))
        $retainedHandle = $child.Handle
        $controller.Kill(); $controller.WaitForExit()
        if (-not $child.WaitForExit(5000)) { throw 'Child survived abrupt controller termination' }
        if ($foreign.HasExited) { throw 'Abrupt cleanup touched unrelated process' }
        Write-Output 'PASS: owned child exits on abrupt controller termination'
    } finally {
        if (-not $controller.HasExited) { $controller.Kill(); $controller.WaitForExit() }
        $controller.Dispose()
    }
} finally {
    if ($owned) { $owned.Dispose() }
    if (-not $foreign.HasExited) { $foreign.Kill(); $foreign.WaitForExit() }
    $foreign.Dispose()
}
