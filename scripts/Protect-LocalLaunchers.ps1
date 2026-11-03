#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ProbeSafety.ps1')
$repo = Split-Path $PSScriptRoot -Parent
$server = Join-Path $repo 'Server'
Assert-ProbePlainPath $server
if (@(Get-Process -Name RustDedicated,RustClient,Rust,steamcmd -ErrorAction SilentlyContinue).Count) {
    throw 'BLOCKED: a Rust or SteamCMD process is running; no BAT changes made.'
}
$run = Join-Path $server 'Run_DS.bat'
$update = Join-Path $server 'update.bat'
Assert-ProbePlainPath $run
Assert-ProbePlainPath $update
$original = [IO.File]::ReadAllText($run)
if ($original.Contains('@@SERVER_ARGUMENTS@@')) { throw 'Unresolved template in local launcher' }
if ($original.Contains('set "server_exit=%errorlevel%"')) { throw 'Already hardened; inspect backups before reapplying' }
$match = [regex]::Matches($original, '(?m)^RustDedicated\.exe[ \t]+([^\r\n]+)\r?$')
if ($match.Count -ne 1) { throw 'Expected exactly one existing game invocation; original retained' }
$arguments = $match[0].Groups[1].Value
$template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'templates\Run_DS.bat'))
$replacement = $template.Replace('@@SERVER_ARGUMENTS@@', $arguments)
if (-not $replacement.Contains('".\RustDedicated.exe" ' + $arguments)) { throw 'Argument preservation failed' }
$backup = Join-Path $server ('backups\RUST-BOTS-001\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
foreach ($parent in @((Join-Path $server 'backups'),(Join-Path $server 'backups\RUST-BOTS-001'))) {
    if (Test-Path -LiteralPath $parent) { Assert-ProbePlainPath $parent }
}
New-Item -ItemType Directory -Path $backup | Out-Null
$manifest = @()
foreach ($path in @($run,$update)) {
    $dest = Join-Path $backup ([IO.Path]::GetFileName($path))
    Copy-Item -LiteralPath $path -Destination $dest
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $hash) { throw 'Backup hash mismatch' }
    $manifest += [pscustomobject]@{ File = [IO.Path]::GetFileName($path); SHA256 = $hash }
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'hashes.json') -Encoding UTF8
# Prepare both complete files first. Only these two explicitly permitted paths change.
$utf8 = New-Object Text.UTF8Encoding($false)
$suffix = '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
$runTemp = $run + $suffix
$updateTemp = $update + $suffix
$created = New-Object 'Collections.Generic.List[string]'
$replacing = $false
function Write-NewFile([string]$path, [string]$content) {
    $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $created.Add($path)
    try { $bytes = $utf8.GetBytes($content); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
try {
    Write-NewFile $runTemp ($replacement -replace '\r?\n', "`r`n")
    Write-NewFile $updateTemp ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'templates\update.bat')) -replace '\r?\n', "`r`n")
    $replacing = $true
    Move-Item -LiteralPath $runTemp -Destination $run -Force
    Move-Item -LiteralPath $updateTemp -Destination $update -Force
} catch {
    if ($replacing) {
        Copy-Item -LiteralPath (Join-Path $backup 'Run_DS.bat') -Destination $run -Force
        Copy-Item -LiteralPath (Join-Path $backup 'update.bat') -Destination $update -Force
    }
    throw
} finally {
    foreach ($path in $created) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
}
Write-Output ('Backup: Server/' + $backup.Substring($server.Length + 1).Replace('\','/'))
$manifest | Format-Table -AutoSize
Write-Output 'Preserved original game argument string exactly. Neither BAT was executed.'
