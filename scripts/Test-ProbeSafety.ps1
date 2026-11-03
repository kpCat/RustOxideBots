#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'Invoke-NavigationProbe.ps1'
if (-not (Test-Path $runner)) { throw 'Missing fail-closed probe runner' }
$repo = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $repo ('.local\tests\' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $fixture | Out-Null
Add-Type -TypeDefinition 'class Sleeper { static void Main() { System.Threading.Thread.Sleep(60000); } }' -OutputType ConsoleApplication -OutputAssembly (Join-Path $fixture 'RustDedicated.exe')
$info = New-Object Diagnostics.ProcessStartInfo
$info.FileName = Join-Path $fixture 'RustDedicated.exe'
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$foreign = [Diagnostics.Process]::Start($info)
try {
    & (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $runner -PreflightOnly
    if ($LASTEXITCODE -ne 2) { throw 'Expected blocked runner exit code 2' }
    $latest = Get-ChildItem (Join-Path $repo '.local\runtime') -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $report = Get-Content (Join-Path $latest.FullName 'result.json') -Raw | ConvertFrom-Json
    if ($report.Status -ne 'BLOCKED' -or $report.Reason -notlike '*foreign Rust*') { throw 'Expected foreign-process blocker' }
    if ($report.ServerPid -or (Test-Path (Join-Path $latest.FullName 'install'))) { throw 'Runner proceeded after failed gate' }
    if ($foreign.HasExited) { throw 'Runner stopped foreign process' }
    Write-Output 'PASS: foreign Rust process blocks before install/start and survives runner'
} finally {
    if (-not $foreign.HasExited) { $foreign.Kill(); $foreign.WaitForExit() }
    $foreign.Dispose()
}

# Regression: Unity keeps its log open for writing; the reader must allow writers.
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
$logPath = Join-Path $fixture 'shared.log'
$writer = [IO.File]::Open($logPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
try {
    $bytes = [Text.Encoding]::UTF8.GetBytes('Server startup complete')
    $writer.Write($bytes, 0, $bytes.Length); $writer.Flush()
    if ((Read-ProbeLog $logPath) -ne 'Server startup complete') { throw 'Cannot read live writable log' }
} finally { $writer.Dispose() }
Write-Output 'PASS: reads log while server holds writable handle'

# Regression: a selected runtime directory itself may be a junction.
$targetDir = Join-Path $fixture 'owner-like-data'
$linkedDir = Join-Path $fixture 'linked-runtime'
New-Item -ItemType Directory $targetDir | Out-Null
New-Item -ItemType Junction -Path $linkedDir -Target $targetDir | Out-Null
$rejected = $false
try { Assert-ProbePlainPath $linkedDir } catch { $rejected = $true }
if (-not $rejected) { throw 'Runtime-root junction accepted' }
Write-Output 'PASS: runtime-root junction rejected without traversal/copy'

# Contract fixtures below are unit-test inputs, never live E2E evidence.
$nav = [pscustomobject]@{ Status='GREEN'; CompletedLegs=3; TotalTraveled=90; Legs=@(
    [pscustomobject]@{ Status='ARRIVED'; Traveled=30; Net=30; Start=@(0,5,0); End=@(30,5,0); Target=@(30,5,0) },
    [pscustomobject]@{ Status='ARRIVED'; Traveled=30; Net=30; Start=@(30,5,0); End=@(60,5,0); Target=@(60,5,0) },
    [pscustomobject]@{ Status='ARRIVED'; Traveled=30; Net=30; Start=@(60,5,0); End=@(90,5,0); Target=@(90,5,0) }
) }
Assert-ProbeNavigationResult $nav
$nav.Legs[1].Net = 0
$rejected = $false
try { Assert-ProbeNavigationResult $nav } catch { $rejected = $true }
if (-not $rejected) { throw 'Inconsistent GREEN coordinates accepted' }
Write-Output 'PASS: GREEN metrics independently validated; inconsistent displacement rejected'
