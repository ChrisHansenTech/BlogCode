#!/usr/bin/env bash
# doorbell_anim.sh
# Usage: ./doorbell_anim.sh <doorbell_ip> <image_base_no_ext> <sprite_count> <duration_ms> [user]
# Example: ./doorbell_anim.sh 192.168.1.50 welcome 12 3000 ubnt

set -euo pipefail

IP="${1:-}"; IMG_BASE="${2:-}"; SPRITE_COUNT="${3:-}"; DURATION_MS="${4:-}"
USER="${5:-ubnt}"
PNG_FILE="${IMG_BASE}.png"
REMOTE_ANIM="/etc/persistent/lcm/animation/${IMG_BASE}.png.anim"
REMOTE_MD5="/etc/persistent/lcm/animation/${IMG_BASE}.png.md5"
REMOTE_CONF="/etc/persistent/ubnt_lcm_gui.conf"

if [[ -z "$IP" || -z "$IMG_BASE" || -z "$SPRITE_COUNT" || -z "$DURATION_MS" ]]; then
  echo "Usage: $0 <doorbell_ip> <image_base_no_ext> <sprite_count> <duration_ms> [user]"
  exit 1
fi

if [[ ! -f "$PNG_FILE" ]]; then
  echo "Error: ${PNG_FILE} not found in current directory."
  exit 1
fi

# File size check (<= 1,048,576 bytes)
SIZE=$(stat -c%s "$PNG_FILE" 2>/dev/null || stat -f%z "$PNG_FILE")
if (( SIZE > 1048576 )); then
  echo "Error: ${PNG_FILE} is larger than 1,048,576 bytes (1 MB)."
  exit 1
fi

echo "[1/5] Uploading sprite sheet -> ${REMOTE_ANIM}"
scp -O "${PNG_FILE}" "${USER}@${IP}:${REMOTE_ANIM}"

echo "[2/5] Generating MD5 on device"
ssh "${USER}@${IP}" "md5sum '${REMOTE_ANIM}' | awk '{print \$1}' > '${REMOTE_MD5}'"

echo "[3/5] Backing up and writing animation config"
ssh "${USER}@${IP}" "cp -f '${REMOTE_CONF}' '${REMOTE_CONF}.bak' 2>/dev/null || true"
ssh "${USER}@${IP}" "cat > '${REMOTE_CONF}' <<'JSON'
{
  \"customAnimations\": [
    {
      \"count\": ${SPRITE_COUNT},
      \"durationMs\": ${DURATION_MS},
      \"enable\": true,
      \"file\": \"${IMG_BASE}.png\",
      \"guiId\": \"WELCOME\",
      \"loop\": true
    }
  ]
}
JSON"

echo "[4/5] Restarting services"
ssh "${USER}@${IP}" "killall ubnt_lcm_gui || true; killall ubnt_sounds_leds || true"

echo "[5/5] Done."
echo "Note: changes persist through reboot only while UniFi Protect is offline."
echo "When the doorbell reconnects to UniFi Protect, \`ubnt_avclient\` will restore Protect settings."

