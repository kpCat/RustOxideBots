#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
foreach ($file in @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1')) {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw ($errors | Out-String) }
}
Write-Output 'PASS: all PowerShell scripts parse'
foreach ($test in @('Test-Bootstrap.ps1','Test-OwnedProcess.ps1','Test-ProbeSafety.ps1','Test-ProbeCache.ps1','Test-ProbeFirewall.ps1','Test-PluginCompile.ps1')) {
    & (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $test)
    if ($LASTEXITCODE -ne 0) { throw ($test + ' failed') }
}
Write-Output 'PASS: focused bootstrap suite (no real server/update launched)'
