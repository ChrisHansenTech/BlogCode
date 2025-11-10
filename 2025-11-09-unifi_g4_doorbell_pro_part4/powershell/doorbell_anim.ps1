# doorbell_anim.ps1
# Usage:
#   .\doorbell_anim.ps1 -Ip 192.168.1.50 -ImageBase welcome -SpriteCount 12 -DurationMs 3000 -User ubnt

param(
  [Parameter(Mandatory=$true)] [string]$Ip,
  [Parameter(Mandatory=$true)] [string]$ImageBase,
  [Parameter(Mandatory=$true)] [int]$SpriteCount,
  [Parameter(Mandatory=$true)] [int]$DurationMs,
  [string]$User = "ubnt"
)

$Png = "$ImageBase.png"
if (-not (Test-Path $Png)) { throw "File not found: $Png" }

# File size check
$size = (Get-Item $Png).Length
if ($size -gt 1048576) { throw "$Png is larger than 1,048,576 bytes (1 MB)." }

$remoteAnim = "/etc/persistent/lcm/animation/$ImageBase.png.anim"
$remoteMd5  = "/etc/persistent/lcm/animation/$ImageBase.png.md5"
$remoteConf = "/etc/persistent/ubnt_lcm_gui.conf"

Write-Host "[1/5] Uploading sprite sheet -> $remoteAnim"
scp -O $Png "${User}@${Ip}:${remoteAnim}"

Write-Host "[2/5] Generating MD5 on device"
$remoteCmd = "md5sum $remoteAnim | awk `"{print \`$1}`" > $remoteMd5"
ssh "$User@$Ip" $remoteCmd

# Build JSON locally and upload as a file to avoid quoting hell
$tmp = New-TemporaryFile
@"
{
  "customAnimations": [
    {
      "count": $SpriteCount,
      "durationMs": $DurationMs,
      "enable": true,
      "file": "$ImageBase.png",
      "guiId": "WELCOME",
      "loop": true
    }
  ]
}
"@ | Set-Content -NoNewline -Encoding UTF8 $tmp

Write-Host "[3/5] Backing up and writing animation config"
ssh "$User@$Ip" "cp -f '$remoteConf' '${remoteConf}.bak' 2>/dev/null || true"
scp -O $tmp "${User}@${Ip}:${remoteConf}"
Remove-Item $tmp -Force

Write-Host "[4/5] Restarting services"
ssh "$User@$Ip" "killall ubnt_lcm_gui || true; killall ubnt_sounds_leds || true"

Write-Host "[5/5] Done."
Write-Host "Note: changes persist through reboot only while UniFi Protect is offline."
Write-Host "When the doorbell reconnects to UniFi Protect, ubnt_avclient will restore Protect settings."
