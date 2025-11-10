#!/usr/bin/env bash
# doorbell_tone.sh
# Usage:
#   ./doorbell_tone.sh <doorbell_ip> <audio_filename_with_ext> [volume] [repeatTimes] [user]
# Example:
#   ./doorbell_tone.sh 192.168.1.50 chime.wav 100 1 ubnt

set -euo pipefail

IP="${1:-}"; AUDIO_FILE="${2:-}"
VOLUME="${3:-100}"
REPEAT="${4:-1}"
USER="${5:-ubnt}"

if [[ -z "$IP" || -z "$AUDIO_FILE" ]]; then
  echo "Usage: $0 <doorbell_ip> <audio_filename_with_ext> [volume] [repeatTimes] [user]"
  exit 1
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "Error: ${AUDIO_FILE} not found in current directory."
  exit 1
fi

# File size check (<= 1,048,576 bytes)
SIZE=$(stat -c%s "$AUDIO_FILE" 2>/dev/null || stat -f%z "$AUDIO_FILE")
if (( SIZE > 1048576 )); then
  echo "Error: ${AUDIO_FILE} is larger than 1,048,576 bytes (1 MB)."
  exit 1
fi

REMOTE_SOUND_DIR="/etc/persistent/sounds"
REMOTE_FILE="${REMOTE_SOUND_DIR}/${AUDIO_FILE}"
REMOTE_MD5="${REMOTE_FILE}.md5"
REMOTE_CONF="/etc/persistent/ubnt_sounds_leds.conf"

TMP_LOCAL="$(mktemp)"
TMP_LOCAL_NEW="$(mktemp)"

echo "[1/7] Uploading audio -> ${REMOTE_FILE}"
scp -O "${AUDIO_FILE}" "${USER}@${IP}:${REMOTE_FILE}"

echo "[2/7] Generating MD5 on device"
ssh "${USER}@${IP}" "md5sum '${REMOTE_FILE}' | awk '{print \$1}' > '${REMOTE_MD5}'"

echo "[3/7] Downloading existing sound config"
scp -O "${USER}@${IP}:${REMOTE_CONF}" "${TMP_LOCAL}" || {
  echo "No existing config; creating a fresh JSON object."
  echo '{}' > "${TMP_LOCAL}"
}

echo "[4/7] Merging customSounds into JSON (preserving all other keys)"
jq \
  --arg file "${AUDIO_FILE}" \
  --arg state "RING_BUTTON_PRESSED" \
  --argjson volume "${VOLUME}" \
  --argjson repeat "${REPEAT}" \
  '.customSounds = [
     {
       enable: true,
       file: $file,
       repeatTimes: $repeat,
       soundStateName: $state,
       volume: $volume
     }
   ]' \
  "${TMP_LOCAL}" > "${TMP_LOCAL_NEW}"

echo "[5/7] Backing up remote config"
ssh "${USER}@${IP}" "cp -f '${REMOTE_CONF}' '${REMOTE_CONF}.bak' 2>/dev/null || true"

echo "[6/7] Uploading merged config"
scp -O "${TMP_LOCAL_NEW}" "${USER}@${IP}:${REMOTE_CONF}"

echo "[7/7] Restarting sound service"
ssh "${USER}@${IP}" "killall ubnt_sounds_leds || true"

rm -f "${TMP_LOCAL}" "${TMP_LOCAL_NEW}"

echo "Done. Note: changes persist through reboot only while UniFi Protect is offline."
echo "When the doorbell reconnects, \`ubnt_avclient\` restores the Protect settings."
