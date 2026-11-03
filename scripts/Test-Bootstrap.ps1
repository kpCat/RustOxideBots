#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $repo ('.local\tests\' + [Guid]::NewGuid().ToString('N'))
$server = Join-Path $fixture 'server with spaces'
$other = Join-Path $fixture 'other cwd'
New-Item -ItemType Directory -Force -Path $server,$other,(Join-Path $server 'rustds'),(Join-Path $server 'steam') | Out-Null
$oldLog = $env:RUSTBOTS_STUB_LOG
$oldExit = $env:RUSTBOTS_STUB_EXIT
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Invoke-FixtureBat($name) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $env:ComSpec
    $info.Arguments = '/d /c ""' + (Join-Path $server $name) + '""'
    $info.WorkingDirectory = $other
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $proc = [Diagnostics.Process]::Start($info)
    try {
        Assert ($proc.WaitForExit(5000)) 'BAT hung or restarted unexpectedly'
        return $proc.ExitCode
    } finally { if (-not $proc.HasExited) { $proc.Kill(); $proc.WaitForExit() }; $proc.Dispose() }
}
try {
    # Failure protected: cwd regression, restart loop, or swallowed exit code.
    $runTemplate = Join-Path $PSScriptRoot 'templates\Run_DS.bat'
    Assert (Test-Path $runTemplate) 'Missing hardened Run_DS template'
    $stub = @'
using System;
using System.IO;
class Stub {
    static int Main(string[] args) {
        File.AppendAllText(Environment.GetEnvironmentVariable("RUSTBOTS_STUB_LOG"),
            Environment.CurrentDirectory + "|" + string.Join(" ", args) + "\n");
        return int.Parse(Environment.GetEnvironmentVariable("RUSTBOTS_STUB_EXIT"));
    }
}
'@
    Add-Type -TypeDefinition $stub -OutputType ConsoleApplication -OutputAssembly (Join-Path $server 'rustds\RustDedicated.exe')
    Copy-Item (Join-Path $server 'rustds\RustDedicated.exe') (Join-Path $server 'steam\steamcmd.exe')
    $env:RUSTBOTS_STUB_LOG = Join-Path $fixture 'calls.txt'
    $text = [IO.File]::ReadAllText($runTemplate).Replace('@@SERVER_ARGUMENTS@@', '-batchmode +server.identity "fixture-only"')
    [IO.File]::WriteAllText((Join-Path $server 'Run_DS.bat'), $text, [Text.Encoding]::ASCII)
    foreach ($code in @(0,17)) {
        $env:RUSTBOTS_STUB_EXIT = [string]$code
        Assert ((Invoke-FixtureBat 'Run_DS.bat') -eq $code) "Run exit not preserved: $code"
    }
    $calls = @(Get-Content $env:RUSTBOTS_STUB_LOG)
    Assert ($calls.Count -eq 2) 'Run_DS must execute once per invocation'
    Assert ($calls[0] -eq ((Join-Path $server 'rustds') + '|-batchmode +server.identity fixture-only')) 'Wrong cwd or arguments'
    Write-Output 'PASS: Run_DS foreign cwd, spaces, clean exit once, failure exit preserved'

    # Failure protected: prerequisites missing or present must never reach SteamCMD.
    Copy-Item (Join-Path $PSScriptRoot 'templates\update.bat') (Join-Path $server 'update.bat')
    Move-Item (Join-Path $server 'steam\steamcmd.exe') (Join-Path $server 'steam\stub.saved')
    Assert ((Invoke-FixtureBat 'update.bat') -eq 2) 'Missing SteamCMD must fail closed'
    Move-Item (Join-Path $server 'steam\stub.saved') (Join-Path $server 'steam\steamcmd.exe')
    Assert ((Invoke-FixtureBat 'update.bat') -eq 3) 'Missing runscript must fail closed'
    Set-Content (Join-Path $server 'update_script.txt') '# fixture only' -Encoding ASCII
    Assert ((Invoke-FixtureBat 'update.bat') -eq 4) 'Missing Oxide package must fail closed'
    New-Item -ItemType Directory (Join-Path $server 'update-prerequisites') | Out-Null
    Set-Content (Join-Path $server 'update-prerequisites\oxide-compatible.zip') 'not a compatible package' -Encoding ASCII
    Assert ((Invoke-FixtureBat 'update.bat') -eq 78) 'Unverified restore workflow must be refused'
    Assert (@(Get-Content $env:RUSTBOTS_STUB_LOG).Count -eq 2) 'Updater executed SteamCMD stub'
    Write-Output 'PASS: updater missing SteamCMD/script/Oxide and unverified package; zero SteamCMD calls'

    # Regression: a pre-existing predictable temporary file must never be truncated.
    $hardenerScripts = Join-Path $fixture 'scripts'
    New-Item -ItemType Directory -Path (Join-Path $hardenerScripts 'templates'),(Join-Path $fixture 'Server') -Force | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'Protect-LocalLaunchers.ps1') $hardenerScripts
    if (Test-Path (Join-Path $PSScriptRoot 'ProbeSafety.ps1')) { Copy-Item (Join-Path $PSScriptRoot 'ProbeSafety.ps1') $hardenerScripts }
    Copy-Item (Join-Path $PSScriptRoot 'templates\*.bat') (Join-Path $hardenerScripts 'templates')
    $ownerRun = Join-Path $fixture 'Server\Run_DS.bat'
    $ownerUpdate = Join-Path $fixture 'Server\update.bat'
    Set-Content $ownerRun 'RustDedicated.exe -batchmode +server.identity "fixture-only"' -Encoding ASCII
    Set-Content $ownerUpdate 'rem fixture updater' -Encoding ASCII
    Set-Content ($ownerRun + '.new') 'unrelated-sentinel' -Encoding ASCII
    & (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $hardenerScripts 'Protect-LocalLaunchers.ps1') | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'Fixture BAT hardener failed'
    Assert ((Get-Content ($ownerRun + '.new') -Raw).Trim() -eq 'unrelated-sentinel') 'Hardener overwrote/deleted unrelated predictable temp'
    Assert ([IO.File]::ReadAllText($ownerRun).Contains('".\RustDedicated.exe" -batchmode +server.identity "fixture-only"')) 'Hardener changed game arguments'
    Assert (@(Get-ChildItem (Join-Path $fixture 'Server\backups') -Filter hashes.json -Recurse).Count -eq 1) 'Missing hash manifest'
    Write-Output 'PASS: hardener preserves arguments/backups and existing unrelated temporary file'
} finally {
    $env:RUSTBOTS_STUB_LOG = $oldLog
    $env:RUSTBOTS_STUB_EXIT = $oldExit
}
