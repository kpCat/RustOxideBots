#Requires -Version 5.1
. (Join-Path $PSScriptRoot 'AvatarSurvivalValidation.ps1')
function Get-EconomyWorldKeys($w) {
    if($w.Kind -notin @('PROCEDURAL','CUSTOM') -or [string]::IsNullOrWhiteSpace($w.Level) -or $w.MapVersion -notmatch '^[0-9]+$' -or $w.MapSHA256 -notmatch '^[A-Fa-f0-9]{64}$'){throw 'Unknown map identity'}
    foreach($field in @('Seed','Size')){$v=Get-AvatarNumber $w.$field 'map parameter';if($v -lt 0 -or $v -gt [uint32]::MaxValue -or $v -ne [Math]::Floor($v)){throw 'Invalid map parameter'}}
    $wipe=[guid]::Empty
    if($w.Size -eq 0 -or -not [guid]::TryParse($w.WipeId,[ref]$wipe) -or $wipe -eq [guid]::Empty){throw 'Unknown wipe identity'}
    $memory=New-Object IO.MemoryStream;$writer=New-Object IO.BinaryWriter($memory,[Text.Encoding]::UTF8,$true)
    try {
        $writer.Write('economy-map-v2');$writer.Write([string]$w.Kind);$writer.Write([string]$w.Level);$writer.Write([uint32]$w.Seed);$writer.Write([uint32]$w.Size)
        $writer.Write([string]$w.MapVersion);$writer.Write($w.MapSHA256.ToUpperInvariant());$writer.Flush();$bytes=$memory.ToArray()
    }finally{$writer.Dispose();$memory.Dispose()}
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        $map=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','')
        $world=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('economy-world-v2/'+$map+'/'+$wipe.ToString('D')))).Replace('-','')
    }finally{$sha.Dispose()}
    return @{MapKey=$map;WorldKey=$world}
}
function Get-EconomyDataDirectory([string]$install,[string]$key) {
    if($key -cnotmatch '^[A-F0-9]{64}$'){throw 'Invalid economy namespace'}
    Join-Path $install ('oxide\data\RustBotsAvatarSurvival.worlds\'+$key)
}
function Assert-EconomyMapMatch($expected,$actual) {
    foreach($field in @('Kind','Level','Seed','Size','MapVersion','MapSHA256')) {
        if($null -eq $expected.$field -or $expected.$field -ine $actual.$field){throw ('CROSS_MAP_REPLAY_DENIED: '+$field)}
    }
}
function Assert-EconomyResult($n) {
    if($n.Status -ne 'GREEN'){return}
    $e=$n.Economy;$s=$e.State
    $keys=Get-EconomyWorldKeys $e.World;$stateKeys=Get-EconomyWorldKeys $s.World
    if($s.Schema -ne 2 -or $e.WorldKey -cne $keys.WorldKey -or $e.MapKey -cne $keys.MapKey -or $s.WorldKey -cne $keys.WorldKey -or $stateKeys.WorldKey -cne $keys.WorldKey){throw 'Cross-world economy identity'}
    if(-not $e.WorldKey -or $e.CrashAtomic -ne 'NOT_PROVEN' -or $e.CrashRecovery -ne 'OFFLINE_ONLY' -or
        $s.ActorId -ne $n.State.ActorId -or $s.CraftIntent -ne $n.State.CraftIntent -or $s.ProductUid -ne $n.State.ProductUid){throw 'Economy actor/intent/crash classification mismatch'}
    $sources=@($s.Sources)
    if($sources.Count -ne 2 -or @($sources.Incarnation|Select-Object -Unique).Count -ne 2 -or @($sources.SavedUid|Select-Object -Unique).Count -ne 2 -or
        (@($sources.Resource|Sort-Object) -join ',') -ne 'stones,wood'){throw 'Incomplete one-to-one natural source ledger'}
    foreach($source in $sources) {
        foreach($v in @($source.InitialPool,$source.ExpectedPool,$source.InitialFraction,$source.ExpectedFraction)){$null=Get-AvatarNumber $v 'source pool'}
        if(-not $source.Prefab -or $source.Type -notin @('TreeEntity','OreResourceEntity') -or $source.InitialPool -le $source.ExpectedPool -or $source.ExpectedPool -le 0 -or
            $source.InitialFraction -le $source.ExpectedFraction -or $source.ExpectedFraction -le 0){throw 'Source depletion absent'}
        if($n.Mode -eq 'JOURNEY') {
            $hits=@($n.Harvests|Where-Object SourceId -eq $source.SavedUid)
            if(-not $hits.Count -or @($hits|Where-Object {$_.Mechanism -ne 'NATIVE_PLAYER_GATHER' -or $_.AdapterCredit -ne 0}).Count -or
                [Math]::Abs($hits[0].PoolBefore-$source.InitialPool) -gt 0.001 -or [Math]::Abs($hits[-1].PoolAfter-$source.ExpectedPool) -gt 0.001 -or
                [Math]::Abs($hits[-1].FractionAfter-$source.ExpectedFraction) -gt 0.00001){throw 'Source snapshot differs from native gather'}
        } elseif($n.Mode -eq 'RESTORE') {
            foreach($pass in @(1,2)) {
                $rows=@($e.Replays|Where-Object {$_.Pass -eq $pass -and $_.Incarnation -eq $source.Incarnation})
                if($rows.Count -ne 1){throw 'Missing source replay pass'};$r=$rows[0]
                foreach($v in @($r.Before,$r.After,$r.FractionBefore,$r.FractionAfter,$r.Candidates,$r.Neighbors,$r.ItemCredits)){$null=Get-AvatarNumber $v 'source replay'}
                $actual=$r.Actual
                foreach($field in @('SavedUid','Prefab','Type','Resource','Population','StartAmount')){if($actual.$field -cne $source.$field){throw 'Restored source identity differs'}}
                foreach($shape in @(@('Position',3),@('Rotation',4),@('Scale',3),@('Bounds',6))) {
                    $field=$shape[0];$length=$shape[1]
                    if(@($actual.$field).Count -ne $length -or @($source.$field).Count -ne $length){throw 'Missing source geometry'}
                    for($j=0;$j -lt $length;$j++) {
                        $x=Get-AvatarNumber $actual.$field[$j] 'actual geometry';$y=Get-AvatarNumber $source.$field[$j] 'saved geometry'
                        if([Math]::Abs($x-$y) -gt 0.001){throw 'Restored source geometry differs'}
                    }
                }
                $checkpoint=$e.InputSnapshotHealth.($source.Incarnation);$outputCheckpoint=$s.SnapshotHealth.($source.Incarnation)
                foreach($v in @($r.SavedHealth,$r.CheckpointHealth,$r.CurrentHealth,$r.StartHealth,$checkpoint,$outputCheckpoint)){$null=Get-AvatarNumber $v 'source health'}
                $staged=$source.Type -eq 'OreResourceEntity';$health=if($staged){$r.StartHealth}else{$checkpoint}
                if($r.Staged -ne $staged -or [Math]::Abs($r.CheckpointHealth-$checkpoint) -gt 0.001 -or [Math]::Abs($r.SavedHealth-$checkpoint) -gt 0.001 -or [Math]::Abs($r.CurrentHealth-$health) -gt 0.001 -or
                    [Math]::Abs($outputCheckpoint-$r.CurrentHealth) -gt 0.001 -or [Math]::Abs($actual.ExpectedPool-$r.After) -gt 0.001 -or [Math]::Abs($actual.ExpectedFraction-$r.FractionAfter) -gt 0.00001){throw 'Restored native health/pool differs'}
                if($r.SavedUid -ne $source.SavedUid -or $r.Candidates -ne 1 -or $r.DiskWitness -ne $true -or $r.NeighborsUnchanged -ne $true -or $r.Neighbors -lt 1 -or $r.ItemCredits -ne 0 -or
                    $r.Decision -notin @('APPLY','NOOP') -or ($pass -eq 2 -and $r.Decision -ne 'NOOP') -or
                    [Math]::Abs($r.After-$source.ExpectedPool) -gt 0.001 -or [Math]::Abs($r.FractionAfter-$source.ExpectedFraction) -gt 0.00001){throw 'Unproven source replay/neighbor conservation'}
                $expectedBefore=if($r.Decision -eq 'APPLY'){$source.InitialPool}else{$source.ExpectedPool}
                $expectedFraction=if($r.Decision -eq 'APPLY'){$source.InitialFraction}else{$source.ExpectedFraction}
                if([Math]::Abs($r.Before-$expectedBefore) -gt 0.001 -or [Math]::Abs($r.FractionBefore-$expectedFraction) -gt 0.00001){throw 'Replay debit is not exact reset/NOOP'}
            }
        }else{throw 'Unknown economy mode'}
    }
    if($n.Mode -eq 'RESTORE') {
        if(@($e.Replays).Count -ne 4 -or $e.CraftReplay.CraftState -ne 'COMMITTED' -or $e.CraftReplay.DuplicateDenied -ne $true -or
            $e.CraftReplay.InventoryUnchanged -ne $true -or $e.CraftReplay.OutputUid -ne $n.State.ProductUid){throw 'Unproven idempotent craft replay'}
    }
}
function Read-EconomyJournal([string]$path,[string]$world,[string]$actor,[string]$recipe) {
    # Independent parser, not the production helper; never executes native game code.
    $bytes=[IO.File]::ReadAllBytes($path)
    if(-not $bytes.Length -or $bytes.Length -gt 16000000 -or $bytes[-1] -ne 10){throw 'Empty/oversize/torn journal'}
    $utf8=New-Object Text.UTF8Encoding($false,$true);$text=$utf8.GetString($bytes)
    $previous='0'*64;$sequence=0;$actions=@{};$records=@()
    foreach($line in $text.Split([char]10)) {
        if(-not $line){continue}
        if($line.Length -gt 1000000 -or $line -notmatch '^([A-F0-9]{64})\|(.+)$'){throw 'Invalid journal frame'}
        $checksum=$matches[1];$body=[Convert]::FromBase64String($matches[2]);$sha=[Security.Cryptography.SHA256]::Create()
        try{$actual=[BitConverter]::ToString($sha.ComputeHash($body)).Replace('-','')}finally{$sha.Dispose()}
        if($actual -cne $checksum){throw 'Journal checksum mismatch'}
        $memory=New-Object IO.MemoryStream(,$body);$reader=New-Object IO.BinaryReader($memory,$utf8)
        try {
            if($reader.ReadInt32() -ne 1 -or $reader.ReadInt32() -ne $sequence -or $reader.ReadString() -cne $previous){throw 'Broken journal version/chain'}
            $r=[pscustomobject]@{Kind=$reader.ReadString();Intent=$reader.ReadString();Stage=$reader.ReadString();Payload=$reader.ReadString()}
            if($memory.Position -ne $memory.Length){throw 'Trailing journal bytes'}
        }finally{$reader.Dispose();$memory.Dispose()}
        if($sequence -eq 0) {
            if($r.Kind -cne 'HEADER' -or $r.Intent -cne $world -or $r.Stage -cne $actor -or $r.Payload -cne $recipe){throw 'Wrong journal world/actor/recipe'}
        }else {
            $stages=if($r.Kind -eq 'GATHER'){@('PREPARED','APPLIED','COMMITTED')}elseif($r.Kind -eq 'CRAFT'){@('PREPARED','DEBITTING','DEBITED','OUTPUT_CREATED','COMMITTED')}else{throw 'Unknown journal action'}
            $next=0
            if($actions.ContainsKey($r.Intent)){$old=$actions[$r.Intent];if($old.Kind -cne $r.Kind){throw 'Intent kind changed'};$next=[Array]::IndexOf($stages,$old.Stage)+1}
            if($next -ge $stages.Count -or $stages[$next] -cne $r.Stage){throw 'Duplicate intent or invalid transition'}
            $r.Payload=$r.Payload|ConvertFrom-Json;$actions[$r.Intent]=$r
        }
        $records+=,$r;$previous=$checksum;$sequence++
    }
    if(-not $sequence -or -not $actions.Count -or @($actions.Values|Where-Object Stage -ne 'COMMITTED').Count){throw 'IN_DOUBT: no automatic reward or retry'}
    return $records
}
function Assert-EconomyBinding($prior,$proof,[string]$root) {
    Assert-EconomyResult $prior.Navigation
    if($prior.Status -ne 'GREEN' -or -not $prior.WorldEconomy -or $proof.EconomyWorldKey -cne $prior.Navigation.Economy.WorldKey -or $proof.EconomyMapKey -cne $prior.Navigation.Economy.MapKey){throw 'Unbound economy provenance'}
    foreach($entry in @(@('economy.journal','EconomyJournalSHA256'),@('economy.json','EconomyStateSHA256'))) {
        $hash=(Get-FileHash -LiteralPath (Join-Path $root $entry[0]) -Algorithm SHA256).Hash
        if($hash -cne $prior.($entry[1]) -or $hash -cne $proof.($entry[1])){throw 'Economy proof hash mismatch'}
    }
    $n=$prior.Navigation
    if($proof.EconomyJournalSHA256 -cne $n.Economy.JournalSHA256){throw 'Journal receipt hash mismatch'}
    $state=Get-Content (Join-Path $root 'economy.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if(($state|ConvertTo-Json -Depth 20 -Compress) -cne ($n.Economy.State|ConvertTo-Json -Depth 20 -Compress)){throw 'Economy state receipt differs'}
    $records=@(Read-EconomyJournal (Join-Path $root 'economy.journal') $n.Economy.WorldKey $n.State.ActorId $state.RecipeHash)
    $craft=@($records|Where-Object {$_.Kind -eq 'CRAFT' -and $_.Stage -eq 'COMMITTED'})
    if($craft.Count -ne 1 -or $craft[0].Intent -ne $n.State.CraftIntent -or $craft[0].Payload.Output.Uid -ne $n.State.ProductUid){throw 'Journal craft receipt differs'}
    $product=@($n.Inventory|Where-Object Uid -eq $n.State.ProductUid)
    if($product.Count -ne 1){throw 'Journal product missing'}
    foreach($field in @('Uid','Shortname','Amount','Condition','MaxCondition')){if($product[0].$field -ne $craft[0].Payload.Output.$field){throw 'Journal product attributes differ'}}
    $nonProduct=@($n.Inventory|Where-Object Uid -ne $n.State.ProductUid)
    if((Get-AvatarSurvivalKey $nonProduct) -cne (Get-AvatarSurvivalKey @($craft[0].Payload.After|Where-Object Uid -ne $n.State.ProductUid))){throw 'Journal remaining inventory differs'}
    $hits=@($records|Where-Object {$_.Kind -eq 'GATHER' -and $_.Stage -eq 'APPLIED'})
    if($n.Mode -eq 'JOURNEY' -and $hits.Count -ne @($n.Harvests).Count){throw 'Journal harvest count differs'}
    for($i=0;$n.Mode -eq 'JOURNEY' -and $i -lt $hits.Count;$i++) {
        $a=$hits[$i].Payload;$b=$n.Harvests[$i]
        foreach($field in @('SourceId','Resource','Amount','PoolBefore','PoolAfter','FractionBefore','FractionAfter','ToolUid','ToolConditionBefore','ToolConditionAfter')){if($a.$field -ne $b.$field){throw 'Journal native harvest differs'}}
        if((Get-AvatarSurvivalKey $a.Before) -cne (Get-AvatarSurvivalKey $b.Before) -or (Get-AvatarSurvivalKey $a.After) -cne (Get-AvatarSurvivalKey $b.After)){throw 'Journal harvest UID receipt differs'}
    }
    foreach($source in $state.Sources) {
        $last=@($records|Where-Object {$_.Kind -eq 'GATHER' -and $_.Stage -eq 'COMMITTED' -and $_.Payload.Source.Incarnation -eq $source.Incarnation})|Select-Object -Last 1
        if(-not $last -or ($last.Payload.Source|ConvertTo-Json -Depth 10 -Compress) -cne ($source|ConvertTo-Json -Depth 10 -Compress)){throw 'Journal source incarnation/depletion differs'}
    }
}
function Write-EconomySaveProof([string]$runtime) {
    $p=Get-Content (Join-Path $runtime 'result.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $path=Join-Path $runtime 'world-proof.json';$proof=Get-Content $path -Raw -Encoding UTF8|ConvertFrom-Json
    foreach($field in @('EconomyJournalSHA256','EconomyStateSHA256')){$proof|Add-Member -NotePropertyName $field -NotePropertyValue $p.$field}
    $proof|Add-Member -NotePropertyName EconomyWorldKey -NotePropertyValue $p.Navigation.Economy.WorldKey
    $proof|Add-Member -NotePropertyName EconomyMapKey -NotePropertyValue $p.Navigation.Economy.MapKey
    Assert-EconomyBinding $p $proof $runtime
    [IO.File]::WriteAllText($path,($proof|ConvertTo-Json -Depth 8),[Text.Encoding]::UTF8)
}
