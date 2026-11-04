#Requires -Version 5.1
# Test-only physical cache. Callers hold an exclusive lock for the complete run.
function Get-ProbeFingerprintPaths {
    @('RustDedicated.exe','UnityPlayer.dll','RustDedicated_Data\Managed\Assembly-CSharp.dll',
      'RustDedicated_Data\Managed\Rust.World.dll','RustDedicated_Data\Managed\Rust.Global.dll',
      'RustDedicated_Data\Managed\Oxide.Rust.dll','RustDedicated_Data\Managed\UnityEngine.CoreModule.dll',
      'RustDedicated_Data\Managed\UnityEngine.PhysicsModule.dll','RustDedicated_Data\Plugins\x86_64\RustNative.dll',
      'RustDedicated_Data\Managed\Oxide.Core.dll','RustDedicated_Data\Managed\Oxide.CSharp.dll','Oxide.Compiler.exe')
}
function Get-ProbeCompatibility([string]$source, [int]$seed=424242, [int]$size=2000) {
    $hashes = [ordered]@{}
    $source = [IO.Path]::GetFullPath($source).TrimEnd('\','/')
    $paths = @(Get-ProbeFingerprintPaths)
    foreach ($directory in @($source,(Join-Path $source 'RustDedicated_Data\Managed'),(Join-Path $source 'RustDedicated_Data\Plugins\x86_64'))) {
        if (Test-Path $directory) {
            $paths += @(Get-ChildItem -LiteralPath $directory -File | Where-Object { $_.Extension -in @('.dll','.exe') } | ForEach-Object { $_.FullName.Substring($source.Length+1) })
        }
    }
    $paths = [string[]]@($paths | Select-Object -Unique)
    [Array]::Sort($paths,[StringComparer]::Ordinal)
    foreach ($relative in $paths) {
        $file = Join-Path $source $relative
        Assert-ProbePlainPath $file
        $hashes[$relative] = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    }
    # Asset identity also changes when the installation's bundle inventory changes.
    $bundles = @()
    if (Test-Path (Join-Path $source 'Bundles')) {
        Assert-ProbePlainTree (Join-Path $source 'Bundles')
        $bundles = [string[]]@(Get-ChildItem (Join-Path $source 'Bundles') -File -Recurse | ForEach-Object {
            $_.FullName.Substring($source.Length) + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks
        })
        [Array]::Sort($bundles,[StringComparer]::Ordinal)
    }
    $description = [ordered]@{ Format=3; Seed=$seed; Size=$size; Level='Procedural Map'; Backend='RustNav'; Fingerprints=$hashes; BundleInventory=$bundles }
    # Ordinal, newline-delimited primitives avoid host culture / JSON serializer drift.
    $canonical = @('format=3',('seed='+$seed),('size='+$size),'level=Procedural Map','backend=RustNav')
    $canonical += @($hashes.Keys | ForEach-Object { $_+'='+$hashes[$_] })
    $canonical += $bundles
    $bytes = [Text.Encoding]::UTF8.GetBytes(($canonical -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
    [pscustomobject]@{ Key=$key; Seed=$seed; Size=$size; Description=$description; Fingerprints=$hashes }
}
function Save-ProbeInstallManifest([string]$install, [string]$manifestPath) {
    Assert-ProbePlainTree $install
    $entries = @(Get-ChildItem -LiteralPath $install -Recurse -File | ForEach-Object {
        [pscustomobject]@{ Path=$_.FullName.Substring($install.Length+1); Length=$_.Length; SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    @{ Count=$entries.Count; Files=$entries } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}
function Assert-ProbeInstallManifest([string]$install, [string]$manifestPath) {
    Assert-ProbePlainTree $install
    Assert-ProbePlainPath $manifestPath
    $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.Count -le 0 -or $manifest.Count -ne @($manifest.Files).Count) { throw 'Incomplete runtime manifest' }
    foreach ($entry in $manifest.Files) {
        $path = [IO.Path]::GetFullPath((Join-Path $install $entry.Path))
        if (-not $path.StartsWith($install+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe runtime manifest path' }
        $file = Get-Item -LiteralPath $path
        if ($file.Length -ne $entry.Length -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.SHA256) { throw 'Cached runtime integrity mismatch' }
    }
}
function Test-ProbeCompletedSave($report, [string]$log) {
    # Installed ConVar.Global.quit calls ServerMgr.Shutdown then Process.Kill:
    # -1 is the observed Windows exit after a complete, acknowledged native quit.
    return $report.Shutdown -eq 'GRACEFUL' -and $report.OwnedProcessAbsent -and
        $report.ServerExitCode -in @(0,-1) -and $log.Contains('RUSTBOTS_SHUTDOWN_ACK') -and
        $log.Contains('Successfully saved navmesh') -and $log.Contains('Saving complete')
}
function Get-ProbeWorldFiles([string]$world, $compatibility) {
    $pattern = '^proceduralmap\.' + $compatibility.Size + '\.' + $compatibility.Seed + '\.[0-9]+(?:\.(?:map|sav|navmesh)|_occlusion_[0-9]+\.dat)$'
    @(Get-ChildItem -LiteralPath $world -File | Where-Object { $_.Name -match $pattern })
}
function Save-ProbeWorldCache($context, [string]$world) {
    if($context.DiagnosticOnly){throw 'TEST_FIXTURE cache promotion is forbidden'}
    Assert-ProbePlainTree $world
    $files = @(Get-ProbeWorldFiles $world $context.Compatibility)
    foreach ($extension in @('.map','.sav','.navmesh')) {
        if (@($files | Where-Object { $_.Extension -eq $extension -and $_.Length -gt 12 }).Count -ne 1) {
            throw "Incomplete test world cache: $extension"
        }
    }
    $generation = 'world-' + [Guid]::NewGuid().ToString('N')
    $destination = Join-Path $context.Root $generation
    New-Item -ItemType Directory $destination | Out-Null
    $entries = @()
    foreach ($file in $files) {
        Copy-Item -LiteralPath $file.FullName -Destination $destination
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        if ((Get-FileHash -LiteralPath (Join-Path $destination $file.Name) -Algorithm SHA256).Hash -ne $hash) { throw 'Test cache copy mismatch' }
        $entries += [pscustomobject]@{ Name=$file.Name; Length=$file.Length; SHA256=$hash }
    }
    $manifest = @{ Key=$context.Compatibility.Key; Generation=$generation; Files=$entries; SavedUtc=[DateTime]::UtcNow.ToString('o') }
    $temp = Join-Path $context.Root ('manifest-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination (Join-Path $context.Root 'world-manifest.json') -Force
}
function Restore-ProbeWorldCache($context, [string]$destination) {
    $manifestPath = Join-Path $context.Root 'world-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { $context.WorldStatus='COLD'; return $false }
    try {
        Assert-ProbePlainPath $manifestPath
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.Key -ne $context.Compatibility.Key -or $manifest.Generation -notmatch '^world-[0-9a-f]{32}$') { throw 'Incompatible cache manifest' }
        $generation = Join-Path $context.Root $manifest.Generation
        Assert-ProbePlainTree $generation
        $actual = @(Get-ProbeWorldFiles $generation $context.Compatibility)
        if ($actual.Count -ne @($manifest.Files).Count) { throw 'Unexpected cache file inventory' }
        foreach ($extension in @('.map','.sav','.navmesh')) {
            if (@($actual | Where-Object { $_.Extension -eq $extension -and $_.Length -gt 12 }).Count -ne 1) { throw 'Incomplete cache' }
        }
        foreach ($entry in $manifest.Files) {
            if ([IO.Path]::GetFileName($entry.Name) -ne $entry.Name -or $entry.Name -notin $actual.Name) { throw 'Unsafe cache path' }
            $file = Get-Item -LiteralPath (Join-Path $generation $entry.Name)
            if ($file.Length -ne $entry.Length -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne $entry.SHA256) { throw 'Corrupted cache checksum' }
        }
    } catch {
        $context.WorldStatus='INVALIDATED'; $context.InvalidReason=$_.Exception.Message
        Move-Item -LiteralPath $manifestPath -Destination (Join-Path $context.Root ('invalid-manifest-'+[Guid]::NewGuid().ToString('N')+'.json'))
        Write-Warning ('Test cache rejected before copy: '+$context.InvalidReason)
        return $false
    }
    foreach ($entry in $manifest.Files) { Copy-Item -LiteralPath (Join-Path $generation $entry.Name) -Destination $destination }
    $context.WorldStatus='WARM'
    return $true
}
function Initialize-ProbeCache([string]$repo, [string]$source, [string]$runtime, [switch]$DiagnosticOnly, [switch]$PhysicalRun) {
    $compat = Get-ProbeCompatibility $source
    $cacheBase = Join-Path $repo '.local\probe-cache'
    if (Test-Path $cacheBase) { Assert-ProbePlainPath $cacheBase }
    New-Item -ItemType Directory -Path (Join-Path $cacheBase 'locks') -Force | Out-Null
    Assert-ProbePlainPath (Join-Path $cacheBase 'locks')
    $lock = [IO.File]::Open((Join-Path $cacheBase ('locks\'+$compat.Key+'.lock')), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $root = Join-Path $cacheBase $compat.Key
        if($DiagnosticOnly -or $PhysicalRun) {
            # Read the trusted template under its lock. All writable files are new physical copies.
            Assert-ProbePlainTree $root
            $template=Join-Path $root 'install'
            Assert-ProbeInstallManifest $template (Join-Path $root 'install-manifest.json')
            $manifest=Get-Content (Join-Path $root 'world-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            if($manifest.Key -ne $compat.Key -or $manifest.Generation -notmatch '^world-[0-9a-f]{32}$'){throw 'Unknown trusted smoke generation'}
            $private=Join-Path $runtime 'smoke-cache'
            $install=Join-Path $runtime 'install'
            New-Item -ItemType Directory -Path $private,$install | Out-Null
            foreach($dir in @('RustDedicated_Data','Bundles','MonoBleedingEdge')) {
                Copy-Item -LiteralPath (Join-Path $template $dir) -Destination $install -Recurse
            }
            foreach($file in @(Get-ChildItem -LiteralPath $template -File | Where-Object {$_.Extension -in @('.exe','.dll')})) {
                Copy-Item -LiteralPath $file.FullName -Destination $install
            }
            Assert-ProbeInstallManifest $install (Join-Path $root 'install-manifest.json')
            Copy-Item -LiteralPath (Join-Path $root 'world-manifest.json') -Destination $private
            Copy-Item -LiteralPath (Join-Path $root $manifest.Generation) -Destination $private -Recurse
            foreach($dir in @('oxide/plugins','oxide/config','oxide/data','oxide/logs','cfg','config','logs')) {
                New-Item -ItemType Directory -Force -Path (Join-Path $install $dir) | Out-Null
            }
            $identity='rustbots_probe_'+$(if($DiagnosticOnly){'smoke_'}else{'home_'})+[Guid]::NewGuid().ToString('N')
            $world=Join-Path $install ('server/'+$identity)
            New-Item -ItemType Directory -Path $world -Force | Out-Null
            $context=[pscustomobject]@{Root=$private;Install=$install;Identity=$identity;World=$world;Compatibility=$compat;Lock=$lock;WorldStatus='COLD';InvalidReason='';DiagnosticOnly=[bool]$DiagnosticOnly}
            if(-not (Restore-ProbeWorldCache $context $world)){throw 'Smoke requires verified private warm world copy'}
            if(-not $DiagnosticOnly){$context.Root=$root}
            return $context
        }
        New-Item -ItemType Directory $root -Force | Out-Null
        Assert-ProbePlainPath $root
        $install = Join-Path $root 'install'
        $installManifest = Join-Path $root 'install-manifest.json'
        if (Test-Path $install) {
            try { Assert-ProbeInstallManifest $install $installManifest }
            catch {
                Write-Warning ('Incomplete/corrupt test runtime quarantined: '+$_.Exception.Message)
                Move-Item -LiteralPath $install -Destination (Join-Path $root ('invalid-install-'+[Guid]::NewGuid().ToString('N')))
            }
        }
        if (-not (Test-Path $install)) {
            $staging = Join-Path $root ('install-staging-'+[Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory $staging | Out-Null
            foreach ($dir in @('RustDedicated_Data','Bundles','MonoBleedingEdge')) {
                Assert-ProbePlainTree (Join-Path $source $dir)
                Copy-Item -LiteralPath (Join-Path $source $dir) -Destination $staging -Recurse
            }
            foreach ($file in @(Get-ChildItem -LiteralPath $source -File | Where-Object { $_.Extension -in @('.exe','.dll') })) {
                Assert-ProbePlainPath $file.FullName
                Copy-Item -LiteralPath $file.FullName -Destination $staging
            }
            $tempManifest = Join-Path $root ('install-manifest-'+[Guid]::NewGuid().ToString('N')+'.tmp')
            Save-ProbeInstallManifest $staging $tempManifest
            Assert-ProbeInstallManifest $staging $tempManifest
            Move-Item -LiteralPath $staging -Destination $install
            Move-Item -LiteralPath $tempManifest -Destination $installManifest -Force
        }
        $archive = Join-Path $runtime 'previous-test-state'
        New-Item -ItemType Directory $archive | Out-Null
        # All these paths are under the verified test cache, never under owner Server/.
        foreach ($name in @('oxide','server','cfg','config','logs','userdata','appcache')) {
            $path = Join-Path $install $name
            if (Test-Path $path) { Assert-ProbePlainTree $path; Move-Item -LiteralPath $path -Destination (Join-Path $archive $name) }
        }
        foreach ($dir in @('oxide\plugins','oxide\config','oxide\data','oxide\logs','server','cfg','config','logs')) {
            New-Item -ItemType Directory -Path (Join-Path $install $dir) -Force | Out-Null
        }
        $identity = 'rustbots_probe_' + $compat.Key.Substring(0,24)
        $world = Join-Path $install ('server\'+$identity)
        New-Item -ItemType Directory $world | Out-Null
        $context = [pscustomobject]@{ Root=$root; Install=$install; Identity=$identity; World=$world; Compatibility=$compat; Lock=$lock; WorldStatus='COLD'; InvalidReason='' }
        # Import only a completed, isolated earlier test run with the same runtime.
        if (-not (Test-Path (Join-Path $root 'world-manifest.json')) -and -not (Test-Path (Join-Path $root 'initialized.marker'))) {
            foreach ($candidate in @(Get-ChildItem (Join-Path $repo '.local\runtime') -Directory | Sort-Object LastWriteTime -Descending)) {
                $resultPath = Join-Path $candidate.FullName 'result.json'
                $oldInstall = Join-Path $candidate.FullName 'install'
                if (-not (Test-Path $resultPath)) { continue }
                $result = Get-Content $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($result.Shutdown -ne 'GRACEFUL' -or -not $result.OwnedProcessAbsent -or $result.Navigation.Backend -ne 'RustNavMeshAgent/RustNav') { continue }
                $oldIdentity = 'rustbots_probe_'+$result.RunId
                if ($result.Cache -and $result.Cache.Key -match '^[0-9a-f]{64}$') {
                    $oldInstall = Join-Path $cacheBase ($result.Cache.Key+'\install')
                    $oldIdentity = 'rustbots_probe_'+$result.Cache.Key.Substring(0,24)
                }
                if (-not (Test-Path $oldInstall)) { continue }
                Assert-ProbePlainTree $oldInstall
                $oldCompat = Get-ProbeCompatibility $oldInstall
                if ($oldCompat.Key -ne $compat.Key) { continue }
                $oldWorld = Join-Path $oldInstall ('server\'+$oldIdentity)
                if (Test-Path $oldWorld) { Save-ProbeWorldCache $context $oldWorld; break }
            }
        }
        [IO.File]::WriteAllText((Join-Path $root 'initialized.marker'), $compat.Key)
        $null = Restore-ProbeWorldCache $context $world
        return $context
    } catch { $lock.Dispose(); throw }
}
