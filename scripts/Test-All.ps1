#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
foreach ($file in @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1')) {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw ($errors | Out-String) }
}
Write-Output 'PASS: all PowerShell scripts parse'
foreach ($test in @('Test-Bootstrap.ps1','Test-OwnedProcess.ps1','Test-ProbeSafety.ps1','Test-ProbeCache.ps1','Test-ProbeFirewall.ps1','Test-WorldRoam.ps1','Test-Survival.ps1','Test-Craft.ps1','Test-Avatar.ps1','Test-AvatarSurvival.ps1','Test-PluginCompile.ps1')) {
    & (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $test)
    if ($LASTEXITCODE -ne 0) { throw ($test + ' failed') }
}
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-PluginCompile.ps1') -PluginName RustBotsWorldRoam
if ($LASTEXITCODE -ne 0) { throw 'World roam offline compile failed' }
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-PluginCompile.ps1') -PluginName RustBotsSurvival
if ($LASTEXITCODE -ne 0) { throw 'Survival offline compile failed' }
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-PluginCompile.ps1') -PluginName RustBotsAvatarProbe
if ($LASTEXITCODE -ne 0) { throw 'Avatar offline compile failed' }
Write-Output 'PASS: focused bootstrap suite (no real server/update launched)'
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-PluginCompile.ps1') -PluginName RustBotsAvatarSurvival
if ($LASTEXITCODE -ne 0) { throw 'Avatar survival offline compile failed' }
