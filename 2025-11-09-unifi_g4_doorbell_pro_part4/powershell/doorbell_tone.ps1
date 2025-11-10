# doorbell_tone.ps1
# Usage:
#   .\doorbell_tone.ps1 -Ip 192.168.1.50 -AudioFile chime.wav -Volume 100 -RepeatTimes 1 -User ubnt

param(
  [Parameter(Mandatory=$true)] [string]$Ip,
  [Parameter(Mandatory=$true)] [string]$AudioFile,
  [int]$Volume = 100,
  [int]$RepeatTimes = 1,
  [string]$User = "ubnt"
)

if (-not (Test-Path $AudioFile)) { throw "File not found: $AudioFile" }

# File size check
$size = (Get-Item $AudioFile).Length
if ($size -gt 1048576) { throw "$AudioFile is larger than 1,048,576 bytes (1 MB)." }

$remoteSoundDir = "/etc/persistent/sounds"
$remoteFile = "$remoteSoundDir/$AudioFile"
$remoteMd5  = "$remoteFile.md5"
$remoteConf = "/etc/persistent/ubnt_sounds_leds.conf"

$tmpLocal = New-TemporaryFile
$tmpMerged = New-TemporaryFile

Write-Host "[1/7] Uploading audio -> $remoteFile"
scp -O $AudioFile "${User}@${Ip}:${remoteFile}"

Write-Host "[2/7] Generating MD5 on device"
$remoteCmd = "md5sum $remoteFile | awk `"{print \`$1}`" > $remoteMd5"
ssh "$User@$Ip" $remoteCmd

Write-Host "[3/7] Downloading existing sound config"
& scp -O "${User}@${Ip}:${remoteConf}" "$($tmpLocal.FullName)" 2>$null

# Check process exit code
if ($LASTEXITCODE -ne 0) {
  Write-Host "No existing config on device (scp failed). Using empty JSON."
  "{}" | Set-Content -NoNewline -Encoding UTF8 $tmpLocal
} else {
  # If a zero-byte file somehow came down, treat as empty JSON
  if ((Get-Item $tmpLocal).Length -eq 0) {
    Write-Host "Downloaded config is empty. Using empty JSON."
    "{}" | Set-Content -NoNewline -Encoding UTF8 $tmpLocal
  }
}

Write-Host "[4/7] Merging customSounds into JSON (preserving all other keys)"
try {
  $json = Get-Content $tmpLocal -Raw | ConvertFrom-Json
} catch {
  # If file was empty or invalid, start fresh
  $json = @{}
}

$custom = [ordered]@{
  enable         = $true
  file           = $AudioFile
  repeatTimes    = $RepeatTimes
  soundStateName = "RING_BUTTON_PRESSED"
  volume         = $Volume
}

# Add/replace the customSounds property safely
if ($json -is [System.Collections.IDictionary]) {
  # Hashtable path
  $json['customSounds'] = @($custom)
} else {
  # PSCustomObject path
  $null = $json | Add-Member -NotePropertyName customSounds -NotePropertyValue @($custom) -Force
}

# Keep depth high so nested structures are preserved
($json | ConvertTo-Json -Depth 20) | Set-Content -NoNewline -Encoding UTF8 $tmpMerged

Write-Host "[5/7] Backing up remote config"
ssh "$User@$Ip" "cp -f '$remoteConf' '${remoteConf}.bak' 2>/dev/null || true"

Write-Host "[6/7] Uploading merged config"
scp -O $tmpMerged "${User}@${ip}:${remoteConf}"

Write-Host "[7/7] Restarting sound service"
ssh "$User@$Ip" "killall ubnt_sounds_leds || true"

Remove-Item $tmpLocal,$tmpMerged -Force

Write-Host "Done. Note: changes persist through reboot only while UniFi Protect is offline."
Write-Host "When the doorbell reconnects, ubnt_avclient restores the Protect settings."
