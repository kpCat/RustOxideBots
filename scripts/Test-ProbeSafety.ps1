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

[IO.File]::WriteAllText($logPath, 'Сделана попытка доступа к сокету. Перевірка UTF-8.', (New-Object Text.UTF8Encoding($false)))
if ((Read-ProbeLog $logPath) -ne 'Сделана попытка доступа к сокету. Перевірка UTF-8.') { throw 'UTF-8 log was decoded incorrectly' }
Write-Output 'PASS: UTF-8 Cyrillic log decoded without OEM mojibake'

$consoleScript = Join-Path $fixture 'console-utf8.ps1'
$consoleSource = @'
param([string]$Module)
. $Module
Initialize-ProbeUtf8
Write-Output 'Сделана попытка доступа к сокету. Перевірка UTF-8.'
'@
[IO.File]::WriteAllText($consoleScript,$consoleSource,(New-Object Text.UTF8Encoding($true)))
$consoleInfo = New-Object Diagnostics.ProcessStartInfo
$consoleInfo.FileName = Join-Path $PSHOME 'powershell.exe'
$consoleInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "'+$consoleScript+'" "'+(Join-Path $PSScriptRoot 'ProbeSafety.ps1')+'"'
$consoleInfo.UseShellExecute = $false
$consoleInfo.CreateNoWindow = $true
$consoleInfo.RedirectStandardOutput = $true
$consoleInfo.StandardOutputEncoding = New-Object Text.UTF8Encoding($false,$true)
$consoleProcess = [Diagnostics.Process]::Start($consoleInfo)
try {
    $output = $consoleProcess.StandardOutput.ReadToEnd().Trim()
    $consoleProcess.WaitForExit()
    if ($consoleProcess.ExitCode -ne 0 -or $output -ne 'Сделана попытка доступа к сокету. Перевірка UTF-8.') { throw 'PowerShell native UTF-8 output corrupted' }
} finally { $consoleProcess.Dispose() }
Write-Output 'PASS: Windows PowerShell console emits UTF-8 Cyrillic bytes'

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
