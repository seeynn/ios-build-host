$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$HostIpa = Join-Path $Base 'LonaHost-unsigned.ipa'
$OutputIpa = Join-Path $Base 'Lona.ipa'

function Fail([string]$Message) {
    Write-Host ''
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ''
    Read-Host 'Press Enter to close'
    exit 1
}

if (-not (Test-Path $HostIpa)) {
    Fail 'Put LonaHost-unsigned.ipa in this same folder first.'
}

# Find the patched Lona game folder automatically by locating Game.ini.
$GameIni = Get-ChildItem -Path $Base -Filter 'Game.ini' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notlike '*\_lona_pack_tmp\*' } |
    Select-Object -First 1

if (-not $GameIni) {
    Fail 'Put your PATCHED Lona game folder in this same folder. It must contain Game.ini.'
}

$GameRoot = $GameIni.Directory.FullName

foreach ($required in @('Game.ini', 'Data\Scripts.rvdata2', 'Graphics', 'Audio')) {
    if (-not (Test-Path (Join-Path $GameRoot $required))) {
        Fail "Game folder is incomplete. Missing: $required"
    }
}

Write-Host ''
Write-Host 'Lona iOS packager' -ForegroundColor Cyan
Write-Host "Host: $HostIpa"
Write-Host "Game: $GameRoot"
Write-Host "Output: $OutputIpa"
Write-Host ''

if (Test-Path $OutputIpa) { Remove-Item $OutputIpa -Force }

$srcStream = [System.IO.File]::OpenRead($HostIpa)
$dstStream = [System.IO.File]::Open($OutputIpa, [System.IO.FileMode]::CreateNew)
$srcZip = New-Object System.IO.Compression.ZipArchive($srcStream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
$dstZip = New-Object System.IO.Compression.ZipArchive($dstStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)

try {
    Write-Host 'Copying iOS host...'

    foreach ($entry in $srcZip.Entries) {
        $name = $entry.FullName.Replace('\\','/')

        # Remove the placeholder Game payload from the host IPA.
        if ($name.StartsWith('Payload/Lona.app/Game/')) { continue }
        if ($name -eq 'Payload/Lona.app/Game') { continue }

        $newEntry = $dstZip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
        $newEntry.LastWriteTime = $entry.LastWriteTime
        $newEntry.ExternalAttributes = $entry.ExternalAttributes

        if ($entry.Length -gt 0) {
            $input = $entry.Open()
            $output = $newEntry.Open()
            try { $input.CopyTo($output) }
            finally { $output.Dispose(); $input.Dispose() }
        }
    }

    Write-Host 'Adding Lona game files...'
    $files = Get-ChildItem -Path $GameRoot -File -Recurse
    $total = $files.Count
    $i = 0

    foreach ($file in $files) {
        $i++
        $relative = $file.FullName.Substring($GameRoot.Length).TrimStart('\\','/')
        $zipPath = ('Payload/Lona.app/Game/' + $relative.Replace('\\','/'))

        if (($i % 250) -eq 0 -or $i -eq $total) {
            $pct = [int](($i / [Math]::Max($total,1)) * 100)
            Write-Progress -Activity 'Building Lona.ipa' -Status "$i / $total files" -PercentComplete $pct
        }

        $newEntry = $dstZip.CreateEntry($zipPath, [System.IO.Compression.CompressionLevel]::Optimal)
        # Unix regular file 0644. Game data files do not need execute permission.
        $newEntry.ExternalAttributes = [int64]0x81A40000
        $newEntry.LastWriteTime = $file.LastWriteTime

        $input = [System.IO.File]::OpenRead($file.FullName)
        $output = $newEntry.Open()
        try { $input.CopyTo($output) }
        finally { $output.Dispose(); $input.Dispose() }
    }

    Write-Progress -Activity 'Building Lona.ipa' -Completed
}
finally {
    $dstZip.Dispose()
    $srcZip.Dispose()
    $dstStream.Dispose()
    $srcStream.Dispose()
}

# Sanity-check the finished archive without extracting it.
$checkStream = [System.IO.File]::OpenRead($OutputIpa)
$checkZip = New-Object System.IO.Compression.ZipArchive($checkStream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
try {
    $names = $checkZip.Entries | ForEach-Object { $_.FullName }
    foreach ($required in @(
        'Payload/Lona.app/Lona',
        'Payload/Lona.app/Info.plist',
        'Payload/Lona.app/Game/Game.ini',
        'Payload/Lona.app/Game/Data/Scripts.rvdata2'
    )) {
        if ($names -notcontains $required) { Fail "Finished IPA failed validation: missing $required" }
    }
}
finally {
    $checkZip.Dispose()
    $checkStream.Dispose()
}

$hash = (Get-FileHash -Algorithm SHA256 $OutputIpa).Hash
$sizeMB = [Math]::Round((Get-Item $OutputIpa).Length / 1MB, 1)

Write-Host ''
Write-Host 'DONE.' -ForegroundColor Green
Write-Host "Created: $OutputIpa"
Write-Host "Size: $sizeMB MB"
Write-Host "SHA-256: $hash"
Write-Host ''
Write-Host 'Now sign/install Lona.ipa with Sideloadly or AltStore.'
Write-Host ''
Read-Host 'Press Enter to close'
