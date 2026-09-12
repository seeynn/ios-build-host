$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Windows.Forms

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputIpa = Join-Path $Base 'Lona.ipa'
$Temp = Join-Path $env:TEMP ('lona-ios-' + [guid]::NewGuid().ToString('N'))
$HostZip = Join-Path $Temp 'ios-host.zip'
$HostDir = Join-Path $Temp 'host'
$HostIpa = Join-Path $HostDir 'LonaHost-unsigned.ipa'
$Marker = 'LONARPG_IOS_EMPO_PATCH_V1'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Stop-WithMessage([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show($Message, 'Lona iOS Builder', 'OK', 'Error') | Out-Null
    throw $Message
}

function Read-LF([string]$Path) {
    return ([System.IO.File]::ReadAllText($Path)).Replace("`r`n", "`n")
}

function Write-LF([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"), $Utf8NoBom)
}

function Replace-Once([string]$Text, [string]$Old, [string]$New, [string]$Label) {
    $first = $Text.IndexOf($Old, [System.StringComparison]::Ordinal)
    if ($first -lt 0) { Stop-WithMessage "Could not patch $Label. This does not look like the expected Lona B.0.10.5 files." }
    if ($Text.IndexOf($Old, $first + $Old.Length, [System.StringComparison]::Ordinal) -ge 0) { Stop-WithMessage "Could not patch $Label safely because the patch anchor appears more than once." }
    return $Text.Substring(0, $first) + $New + $Text.Substring($first + $Old.Length)
}

function Require-File([string]$Root, [string]$Relative) {
    $p = Join-Path $Root $Relative
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { Stop-WithMessage "Wrong Lona folder. Missing: $Relative" }
    return $p
}

function Patch-Lona([string]$Root) {
    $full = Require-File $Root 'Data\Scripts\60_FullScreenPlus.rb'
    $f1 = Require-File $Root 'Data\Scripts\0_removeF1F12.rb'
    $mouse = Require-File $Root 'Data\Scripts\Frames\RVscript\4000_Mouse_Support.rb'
    $pad = Require-File $Root 'Data\Scripts\Frames\RVscript\2000_GamePad.rb'
    $kgl = Require-File $Root 'Data\Scripts\Frames\RVscript\450_KHAS_LightGraphicLib.rb'
    $keys = Require-File $Root 'Data\Scripts\Frames\RVscript\1000_Hime_AllKey.rb'

    $t = Read-LF $full
    if (-not $t.Contains($Marker)) {
$prefix = @'
# LONARPG_IOS_EMPO_PATCH_V1: mobile replacement for Windows-only Fullscreen++
if defined?($empo) && $empo
  class << Graphics
    def load_fullscreen_settings
      @fullscreen = true
      @fullscreen_ratio = 1
      @windowed_ratio = 1
      checkScreenScale
    end
    def save_fullscreen_settings; end
    def fullscreen?; true; end
    def fullscreen_mode; @fullscreen = true; true; end
    def windowed_mode; @fullscreen = true; true; end
    def ratio; 1; end
    def ratio=(r); 1; end
    def toggle_ratio(val=1); 1; end
    def stableRatio; true; end
    def set_ratio(val=1); 1; end
    def getCurrentRatio; 1; end
    def check_screen_fullhd; end
    def toggle_fullscreen; true; end
    def get_fullscreenRect; [Graphics.width, Graphics.height]; end
    def get_workareaRect; [Graphics.width, Graphics.height]; end
    def getScaleTextFull; "#{Graphics.width} x #{Graphics.height}"; end
    def getScaleTextHalf; Graphics.height; end
    def checkScreenScale
      scale = nil
      begin
        scale = $LonaINI["Screen"]["ScreenScale"] if $LonaINI
      rescue
        scale = nil
      end
      if scale == "4:3"
        Graphics.resize_screen(544, 416)
      elsif scale == "16:10"
        Graphics.resize_screen(640, 400)
      else
        Graphics.resize_screen(640, 360)
      end
    end
  end
  Graphics.checkScreenScale
  Graphics.load_fullscreen_settings
else
'@
        Write-LF $full ($prefix + $t + "`nend`n")
    }

    $t = Read-LF $f1
    if (-not $t.Contains($Marker)) { Write-LF $f1 ("# $Marker`: the iOS runtime has no F1/Alt+Enter/F12 Windows hook`nunless defined?(`$empo) && `$empo`n" + $t + "`nend`n") }

    $t = Read-LF $mouse
    if (-not $t.Contains($Marker)) {
$old = @'
CPOS = Win32API.new 'user32', 'GetCursorPos', ['p'], 'v'
WINX = Win32API.new 'user32', 'FindWindowEx', ['l','l','p','p'], 'i'
SMET = Win32API.new 'user32', 'GetSystemMetrics', ['i'], 'i'
WREC = Win32API.new 'user32', 'GetWindowRect', ['l','p'], 'v'
SHOWMOUS = Win32API.new 'user32', 'ShowCursor', 'i', 'i'
'@
$new = @'
# LONARPG_IOS_EMPO_PATCH_V1: desktop cursor/window APIs are disabled on Empo/iOS.
if defined?($empo) && $empo
  class EmpoNullWin32Call
    def call(*args); 0; end
  end
  CPOS = EmpoNullWin32Call.new
  WINX = EmpoNullWin32Call.new
  SMET = EmpoNullWin32Call.new
  WREC = EmpoNullWin32Call.new
  SHOWMOUS = EmpoNullWin32Call.new
else
  CPOS = Win32API.new 'user32', 'GetCursorPos', ['p'], 'v'
  WINX = Win32API.new 'user32', 'FindWindowEx', ['l','l','p','p'], 'i'
  SMET = Win32API.new 'user32', 'GetSystemMetrics', ['i'], 'i'
  WREC = Win32API.new 'user32', 'GetWindowRect', ['l','p'], 'v'
  SHOWMOUS = Win32API.new 'user32', 'ShowCursor', 'i', 'i'
end
'@
        $t = Replace-Once $t $old $new 'mouse support'
$oldEnable = "`tdef self.enable`n`t`t@enabled = true`n`t`tSHOWMOUS.call(0)`n`t`tInputUtils.mouse_on`n`t`tInputUtils.load_input_settings`n`tend`n"
$newEnable = "`tdef self.enable`n`t`tif defined?(`$empo) && `$empo`n`t`t`t@enabled = false`n`t`t`tInputUtils.mouse_off`n`t`t`tInputUtils.load_input_settings`n`t`t`treturn false`n`t`tend`n`t`t@enabled = true`n`t`tSHOWMOUS.call(0)`n`t`tInputUtils.mouse_on`n`t`tInputUtils.load_input_settings`n`tend`n"
        $t = Replace-Once $t $oldEnable $newEnable 'mouse enable'
        Write-LF $mouse $t
    }

    $t = Read-LF $pad
    if (-not $t.Contains($Marker)) {
$old = @'
  #Win32API calls. Leave these alone.
  # Calls to XInput9_1_0.dll now only occur if DirectX is missing
  @set_state = Win32API.new("XINPUT1_3", "XInputSetState", "IP", "V") rescue
                Win32API.new("XINPUT9_1_0", "XInputSetState", "IP", "V")
  @get_state = Win32API.new("XINPUT1_3", "XInputGetState", "IP", "L") rescue
                Win32API.new("XINPUT9_1_0", "XInputGetState", "IP", "L")
'@
$new = @'
  # LONARPG_IOS_EMPO_PATCH_V1: native iOS controls replace Windows XInput DLLs.
  if defined?($empo) && $empo
    class EmpoNullXInput
      def call(*args); 0; end
    end
    @set_state = EmpoNullXInput.new
    @get_state = EmpoNullXInput.new
  else
    @set_state = Win32API.new("XINPUT1_3", "XInputSetState", "IP", "V") rescue
                  Win32API.new("XINPUT9_1_0", "XInputSetState", "IP", "V")
    @get_state = Win32API.new("XINPUT1_3", "XInputGetState", "IP", "L") rescue
                  Win32API.new("XINPUT9_1_0", "XInputGetState", "IP", "L")
  end
'@
        Write-LF $pad (Replace-Once $t $old $new 'gamepad support')
    }

    $t = Read-LF $keys
    if (-not $t.Contains($Marker)) {
$old = "`tSetKeyboardState = Win32API.new(`"user32.dll`", `"SetKeyboardState`",  `"I`", `"I`")`n`tdef self.clear_keyboard_state`n`t`t0.upto(255) do |key|`n`t`t`t@state[key]=0`n`t`tend`n`t`tSetKeyboardState.call(@state.to_i)`n`tend`n"
$new = "`t# $Marker`: SetKeyboardState is not required on iOS.`n`tSetKeyboardState = Win32API.new(`"user32.dll`", `"SetKeyboardState`",  `"I`", `"I`") unless defined?(`$empo) && `$empo`n`tdef self.clear_keyboard_state`n`t`t0.upto(255) do |key|`n`t`t`t@state[key]=0`n`t`tend`n`t`tSetKeyboardState.call(@state.to_i) unless defined?(`$empo) && `$empo`n`tend`n"
        Write-LF $keys (Replace-Once $t $old $new 'keyboard state')
    }

    $t = Read-LF $kgl
    if (-not $t.Contains($Marker)) {
        $start = $t.IndexOf("module KGL`n", [System.StringComparison]::Ordinal)
        $run = $t.IndexOf("`nKGL.run", $start, [System.StringComparison]::Ordinal)
        if ($start -lt 0 -or $run -lt 0) { Stop-WithMessage 'Could not patch KGL graphics support.' }
        $block = $t.Substring($start, $run - $start)
        $inner = $block.Substring("module KGL`n".Length).TrimEnd()
        if (-not $inner.EndsWith('end')) { Stop-WithMessage 'Could not patch KGL graphics support safely.' }
        $inner = $inner.Substring(0, $inner.Length - 3).TrimEnd() + "`n"
$fallback = @'
module KGL
  # LONARPG_IOS_EMPO_PATCH_V1: KGL2.klib is Windows-native and cannot execute on iOS.
  if defined?($empo) && $empo
    @@framebuffer = nil
    @@shadowbuffer = nil
    def self.function(name, p=""); nil; end
    def self.run; print "Khas Graphics Library mobile fallback 2.0\n"; end
    def self.version; 2.0; end
    def self.load; 1; end
    def self.compressRGBA(color); color.red.to_i | (color.green.to_i << 8) | (color.blue.to_i << 16) | (color.alpha.to_i << 24); end
    def self.compressBGRA(color); color.blue.to_i | (color.green.to_i << 8) | (color.red.to_i << 16) | (color.alpha.to_i << 24); end
    def self.bindFramebuffer(bitmap); @@framebuffer = bitmap; 1; end
    def self.bindShadowbuffer(bitmap); @@shadowbuffer = bitmap; 1; end
    def self.unbindFramebuffer; @@framebuffer = nil; 1; end
    def self.unbindShadowbuffer; @@shadowbuffer = nil; 1; end
    def self.clearFramebuffer; @@framebuffer.clear if @@framebuffer && !@@framebuffer.disposed?; 1; end
    def self.loadFramebuffer(bitmap, x, y)
      @@framebuffer.blt(x, y, bitmap, Rect.new(0, 0, bitmap.width, bitmap.height)) if @@framebuffer && bitmap && !@@framebuffer.disposed? && !bitmap.disposed?
      1
    end
    def self.blank(bitmap); bitmap.clear if bitmap && !bitmap.disposed?; 1; end
    def self.clear(bitmap, color); bitmap.clear if bitmap && !bitmap.disposed?; 1; end
    def self.invert(bitmap); 1; end
    def self.clone(target, source)
      if target && source && !target.disposed? && !source.disposed?
        target.clear
        target.blt(0, 0, source, Rect.new(0, 0, source.width, source.height))
      end
      1
    end
    def self.compressAlpha(bitmap); 1; end
    def self.lightBlending(b); 1; end
    def self.lightShader(light, tx, ty, opacity); 1; end
    def self.softShadows(s); 1; end
    def self.shadowShaderH(x1, x2, y); 1; end
    def self.shadowShaderV(y1, y2, x); 1; end
    def self.shadowShaderW(y1, y2, x); 1; end
  else
'@
        Write-LF $kgl ($t.Substring(0,$start) + $fallback + $inner + "  end`nend" + $t.Substring($run))
    }

    $empo = Join-Path $Root 'empo'
    New-Item -ItemType Directory -Force -Path $empo | Out-Null
$controls = @'
{"version":1,"bindings":{"a":"KeyZ","b":"KeyX","x":"KeyA","y":"KeyS","leftshoulder":"PageUp","rightshoulder":"PageDown","lefttrigger":"ControlLeft","righttrigger":"ShiftLeft","leftstick":"KeyD","rightstick":"Space","start":"KeyX","back":"AltLeft"}}
'@
    Write-LF (Join-Path $empo 'controls.json') $controls
    Write-LF (Join-Path $empo 'port-build.txt') "LonaRPG iOS compatibility pass v1`n640x360 primary canvas`nKGL2 shader fallback enabled`n"
}

try {
    $Part1Zip = Join-Path $Base '1.zip'
    $Part2Zip = Join-Path $Base '2.zip'
    if (-not (Test-Path $Part1Zip)) { Stop-WithMessage 'Put your original 1.zip in the same folder as START-HERE-LONA.bat.' }
    if (-not (Test-Path $Part2Zip)) { Stop-WithMessage 'Put your original 2.zip in the same folder as START-HERE-LONA.bat.' }

    $Part1Dir = Join-Path $Temp 'part1'
    $Part2Dir = Join-Path $Temp 'part2'
    New-Item -ItemType Directory -Force -Path $Temp,$HostDir,$Part1Dir,$Part2Dir | Out-Null

    Write-Host '1/5 Extracting your two Lona files...'
    Expand-Archive -LiteralPath $Part1Zip -DestinationPath $Part1Dir -Force
    Expand-Archive -LiteralPath $Part2Zip -DestinationPath $Part2Dir -Force

    $GameIni = Get-ChildItem -LiteralPath $Part2Dir -Filter 'Game.ini' -File -Recurse | Select-Object -First 1
    if (-not $GameIni) { Stop-WithMessage '2.zip does not contain Game.ini. Make sure these are the original Lona 1.zip and 2.zip files.' }
    $GameRoot = $GameIni.Directory.FullName
    $AudioDir = Get-ChildItem -LiteralPath $Part1Dir -Directory -Recurse | Where-Object { $_.Name -eq 'Audio' } | Select-Object -First 1
    if (-not $AudioDir) { Stop-WithMessage '1.zip does not contain the Audio folder. Make sure these are the original Lona 1.zip and 2.zip files.' }
    $Part1Root = $AudioDir.Parent.FullName

    Require-File $GameRoot 'Data\Scripts.rvdata2' | Out-Null
    if (-not (Test-Path (Join-Path $GameRoot 'Graphics') -PathType Container)) { Stop-WithMessage '2.zip is missing the Graphics folder.' }

    Write-Host '2/5 Getting the iPhone host from GitHub...'
    $headers = @{ 'User-Agent'='Lona-iOS-Builder'; 'Accept'='application/vnd.github+json' }
    $list = Invoke-RestMethod -Uri 'https://api.github.com/repos/seeynn/ios-build-host/actions/artifacts?name=ios-host&per_page=20' -Headers $headers
    $artifact = $list.artifacts | Where-Object { -not $_.expired } | Sort-Object created_at -Descending | Select-Object -First 1
    if (-not $artifact) { Stop-WithMessage "There is no live iOS host artifact yet.`n`nOpen GitHub -> ios-build-host -> Actions -> iOS Host Build -> Run workflow. When it is green, double-click START-HERE-LONA.bat again." }
    Invoke-WebRequest -Uri $artifact.archive_download_url -Headers $headers -OutFile $HostZip -UseBasicParsing
    Expand-Archive -LiteralPath $HostZip -DestinationPath $HostDir -Force
    if (-not (Test-Path $HostIpa)) { $found = Get-ChildItem $HostDir -Filter 'LonaHost-unsigned.ipa' -File -Recurse | Select-Object -First 1; if ($found) { $HostIpa = $found.FullName } }
    if (-not (Test-Path $HostIpa)) { Stop-WithMessage 'GitHub host downloaded, but LonaHost-unsigned.ipa was not inside it.' }

    Write-Host '3/5 Applying the iOS compatibility patch...'
    Patch-Lona $GameRoot

    Write-Host '4/5 Building Lona.ipa...'
    if (Test-Path $OutputIpa) { Remove-Item $OutputIpa -Force }
    Copy-Item $HostIpa $OutputIpa

    $stream = [System.IO.File]::Open($OutputIpa,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
    $zip = New-Object System.IO.Compression.ZipArchive($stream,[System.IO.Compression.ZipArchiveMode]::Update,$false)
    try {
        @($zip.Entries | Where-Object { $_.FullName -like 'Payload/Lona.app/Game/*' }) | ForEach-Object { $_.Delete() }

        function Add-GameTree([string]$Root) {
            $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
            $i = 0
            foreach ($file in $files) {
                $i++
                $relative = $file.FullName.Substring($Root.Length).TrimStart('\','/')
                if ($relative -ieq 'Game.exe' -or $relative -ieq 'System\LonaMouseWheel.dll') { continue }
                $name = 'Payload/Lona.app/Game/' + $relative.Replace('\','/')
                $existing = $zip.GetEntry($name)
                if ($existing) { $existing.Delete() }
                $entry = $zip.CreateEntry($name,[System.IO.Compression.CompressionLevel]::Optimal)
                $entry.ExternalAttributes = [int64]0x81A40000
                $in = [System.IO.File]::OpenRead($file.FullName); $out = $entry.Open()
                try { $in.CopyTo($out) } finally { $out.Dispose(); $in.Dispose() }
                if (($i % 250) -eq 0) { Write-Progress -Activity 'Building Lona.ipa' -Status "$i / $($files.Count) files" -PercentComplete ([int](100*$i/[Math]::Max(1,$files.Count))) }
            }
        }

        Add-GameTree $GameRoot
        Add-GameTree $Part1Root
        $ver = $zip.CreateEntry('Payload/Lona.app/Game/.lona_payload_version',[System.IO.Compression.CompressionLevel]::NoCompression)
        $writer = New-Object System.IO.StreamWriter($ver.Open(),$Utf8NoBom); $writer.Write('B.0.10.5-ios-oneclick-1'); $writer.Dispose()
    } finally { $zip.Dispose(); $stream.Dispose(); Write-Progress -Activity 'Building Lona.ipa' -Completed }

    Write-Host '5/5 Checking the IPA...'
    $checkStream=[System.IO.File]::OpenRead($OutputIpa); $check=New-Object System.IO.Compression.ZipArchive($checkStream,[System.IO.Compression.ZipArchiveMode]::Read,$false)
    try {
        $names=@($check.Entries | ForEach-Object {$_.FullName})
        foreach($need in @('Payload/Lona.app/Lona','Payload/Lona.app/Info.plist','Payload/Lona.app/Game/Game.ini','Payload/Lona.app/Game/Data/Scripts.rvdata2')) { if($names -notcontains $need){ Stop-WithMessage "IPA validation failed: missing $need" } }
        if (-not ($names | Where-Object { $_ -like 'Payload/Lona.app/Game/Audio/*' } | Select-Object -First 1)) { Stop-WithMessage 'IPA validation failed: Audio files were not added.' }
        if (-not ($names | Where-Object { $_ -like 'Payload/Lona.app/Game/Graphics/*' } | Select-Object -First 1)) { Stop-WithMessage 'IPA validation failed: Graphics files were not added.' }
    } finally { $check.Dispose(); $checkStream.Dispose() }

    $size=[Math]::Round((Get-Item $OutputIpa).Length/1MB,1)
    [System.Windows.Forms.MessageBox]::Show("DONE.`n`nCreated:`n$OutputIpa`n`nSize: $size MB`n`nNext: drag Lona.ipa into Sideloadly.",'Lona iOS Builder','OK','Information') | Out-Null
    Start-Process explorer.exe "/select,`"$OutputIpa`""
}
catch {
    if ($_.Exception.Message -notlike 'There is no live*' -and $_.Exception.Message -notlike 'Put your original*' -and $_.Exception.Message -notlike 'Could not patch*' -and $_.Exception.Message -notlike 'IPA validation*' -and $_.Exception.Message -notlike 'GitHub host*' -and $_.Exception.Message -notlike '1.zip*' -and $_.Exception.Message -notlike '2.zip*') {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Lona iOS Builder','OK','Error') | Out-Null
    }
}
finally {
    if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue }
}
