#Requires -Version 5.1
param([ValidateSet('RustBotsNavigationProbe','RustBotsWorldRoam','RustBotsSurvival')][string]$PluginName='RustBotsNavigationProbe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$plugin = Join-Path $repo ('src\plugins\'+$PluginName+'.cs')
if (-not (Test-Path $plugin)) { throw 'Missing navigation probe source' }
$managed = Join-Path $repo 'Server\rustds\RustDedicated_Data\Managed'
$out = Join-Path $repo '.local\compile'
New-Item -ItemType Directory -Force $out | Out-Null
$sdk = (& dotnet --list-sdks | Select-Object -Last 1)
if ($sdk -notmatch '^(\S+) \[(.+)\]') { throw 'A .NET SDK is required for offline compile check' }
$compiler = Join-Path $matches[2] ($matches[1] + '\Roslyn\bincore\csc.dll')
$response = @('/nologo','/target:library','/nostdlib+','/langversion:7.3',('/out:"' + (Join-Path $out ($PluginName+'.dll')) + '"'))
# Installed Oxide.CSharp CSharpPluginLoader.AssemblyBlacklist excludes these
# standalone duplicates; their public types are merged into Oxide.References.
$response += Get-ChildItem -LiteralPath $managed -Filter '*.dll' | Where-Object {
    $_.BaseName -notin @('Newtonsoft.Json','protobuf-net','websocket-sharp')
} | ForEach-Object { '/reference:"' + $_.FullName + '"' }
$response += '"' + $plugin + '"'
$rsp = Join-Path $out 'compile.rsp'
$response | Set-Content -LiteralPath $rsp -Encoding UTF8
& dotnet $compiler ('@' + $rsp)
if ($LASTEXITCODE -ne 0) { throw 'Installed-assembly compile check failed' }
Write-Output 'PASS: C# 7.3 compile against installed Rust/Oxide DLLs; live Oxide compilation NOT_VERIFIED'
