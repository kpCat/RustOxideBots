#Requires -Version 5.1
# Shared safety checks used before any runtime copy or GREEN claim.
function Initialize-ProbeUtf8 {
    $utf8 = New-Object Text.UTF8Encoding($false)
    $global:OutputEncoding = $utf8
    [Console]::OutputEncoding = $utf8
    [Console]::InputEncoding = $utf8
}
function Assert-ProbePlainPath([string]$path) {
    $item = Get-Item -LiteralPath $path -Force
    while ($null -ne $item) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'BLOCKED: linked runtime path' }
        if ($item.PSIsContainer) { $item = $item.Parent } else { $item = $item.Directory }
    }
}

function Assert-ProbePlainTree([string]$path) {
    Assert-ProbePlainPath $path
    $pending = New-Object 'Collections.Generic.Stack[string]'
    if ((Get-Item -LiteralPath $path).PSIsContainer) { $pending.Push($path) }
    while ($pending.Count) {
        foreach ($entry in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'BLOCKED: linked runtime content' }
            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
        }
    }
}

function Read-ProbeLog([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    $stream = $null; $reader = $null
    try {
        $stream = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false,$true)), $true)
        return $reader.ReadToEnd()
    } catch [IO.IOException] {
        Write-Warning ('Transient log read failed; retry within deadline: ' + $_.Exception.Message)
        return ''
    } finally {
        if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
    }
}

function Assert-ProbeNavigationResult($nav) {
    if ($nav.Status -notin @('GREEN','PARTIAL','BLOCKED','FAILED')) { throw 'Invalid navigation status' }
    if ($nav.Status -ne 'GREEN') { return }
    if ($nav.CompletedLegs -ne 3 -or @($nav.Legs).Count -ne 3) { throw 'GREEN requires three completed legs' }
    $sum = 0.0; $maxNet = 0.0
    foreach ($leg in $nav.Legs) {
        if ($leg.Status -ne 'ARRIVED') { throw 'GREEN leg did not arrive' }
        foreach ($field in @('Start','End','Target')) {
            if (@($leg.$field).Count -ne 3) { throw 'Invalid coordinate vector' }
            foreach ($value in $leg.$field) {
                if ($null -eq $value -or [double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value)) { throw 'Invalid coordinate' }
            }
        }
        $netSquared = 0.0; $remainingSquared = 0.0
        for ($i = 0; $i -lt 3; $i++) {
            $netSquared += [Math]::Pow(($leg.End[$i] - $leg.Start[$i]), 2)
            $remainingSquared += [Math]::Pow(($leg.End[$i] - $leg.Target[$i]), 2)
        }
        $net = [Math]::Sqrt($netSquared)
        if ([Math]::Abs($net - $leg.Net) -gt 0.1 -or $remainingSquared -gt 3.25) { throw 'Inconsistent arrival/displacement' }
        if ($null -eq $leg.Traveled -or [double]::IsNaN([double]$leg.Traveled) -or [double]::IsInfinity([double]$leg.Traveled) -or $leg.Traveled -lt $net - 0.1) { throw 'Invalid physical travel distance' }
        $sum += $leg.Traveled; $maxNet = [Math]::Max($maxNet, $net)
    }
    if ($sum -lt 60 -or $maxNet -lt 20 -or [Math]::Abs($sum - $nav.TotalTraveled) -gt 0.1) { throw 'GREEN distance thresholds not met' }
}
