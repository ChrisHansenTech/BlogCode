# UniFi G4 Doorbell Animation and Sound Tools

These scripts make it easy to upload custom **animations** and **visitor tones** to the
**UniFi G4 Doorbell Pro** using SSH and SCP. They were created as part of the blog series on
[ChrisHansen.Tech](https://chrishansen.tech) and are based on
[Part 4: Using SCP and SSH to Update UniFi Doorbell G4 Animations and Tones](https://chrishansen.tech/posts/unifi_g4_doorbell_pro_part4/).

---

## Overview

The UniFi G4 Doorbell Pro stores its LCD animations and visitor tones as files under
`/etc/persistent/lcm/animation` and `/etc/persistent/sounds/`.  
These scripts automate the process of:

- Uploading PNG sprite sheets or audio files  
- Generating MD5 checksum files  
- Updating the JSON configuration  
- Restarting the necessary UniFi processes  

They’re designed for **advanced users** comfortable with SSH and file transfers.


## Folder Layout

```
bash/          → Linux and macOS Bash scripts
powershell/    → Windows PowerShell versions
```


## Requirements

### For Bash
- macOS or Linux terminal  
- `scp` and `ssh` (included in most systems)  
- `jq` (for `doorbell_tone.sh`)
  ```bash
  sudo apt install jq      # Debian/Ubuntu
  brew install jq          # macOS
  ```
- The doorbell’s **IP address** and **recovery code** (used as SSH password)

### For PowerShell
- PowerShell 7+  
- OpenSSH client installed (`scp`, `ssh`)  
- Run scripts from a PowerShell terminal with execution policy that allows local scripts:
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```


## Authentication

By default, both Bash and PowerShell scripts rely on the SSH and SCP prompts
to ask for the password interactively.  
This is the most secure and portable option.

If you prefer to automate authentication, you can:
- Use SSH keys, or  
- Add `sshpass` (Bash) or `Get-Credential` (PowerShell) logic yourself, or  
- Set the password in an environment variable for CI/Docker automation.

**Example for non-interactive Bash use (optional):**

```bash
export SSHPASS='your_recovery_code'
sshpass -p "$SSHPASS" scp -O myfile.png ubnt@192.168.1.50:/etc/persistent/lcm/animation/
```


## Usage Examples

### Bash
#### Upload a new animation
```bash
cd bash
chmod +x doorbell_anim.sh
./doorbell_anim.sh 192.168.1.50 welcome 12 750 ubnt
```

#### Upload a new visitor tone
```bash
cd bash
chmod +x doorbell_tone.sh
./doorbell_tone.sh 192.168.1.50 chime.wav 100 1 ubnt
```

### PowerShell
#### Upload a new animation
```powershell
cd powershell
.\doorbell_anim.ps1 -Ip 192.168.1.50 -ImageBase welcome -SpriteCount 12 -DurationMs 750 -User ubnt
```

#### Upload a new visitor tone
```powershell
cd powershell
.\doorbell_tone.ps1 -Ip 192.168.1.50 -AudioFile chime.wav -Volume 100 -RepeatTimes 1 -User ubnt
```


## Important Notes

- The `ubnt_lcm_gui.conf` file can be **safely overwritten**.  
- The `ubnt_sounds_leds.conf` file contains additional settings; the tone scripts **merge**
  only the `customSounds` section to preserve the rest.  
- Files must be **1 MB or smaller** (`1,048,576 bytes`) due to UniFi Protect whitelist limits.  
- Custom animations and tones persist through a reboot **only while UniFi Protect is offline**.  
  When the `ubnt_avclient` process reconnects to Protect, it will restore the last Protect-set values.


## Testing Tips

- Always back up the config before making changes:
  ```bash
  ssh ubnt@192.168.1.50 'cp /etc/persistent/lcm/ubnt_sounds_leds.conf /etc/persistent/lcm/ubnt_sounds_leds.conf.bak'
  ```
- Test file sizes with:
  ```bash
  stat -c%s yourfile.png
  ```
- Restart doorbell processes to apply changes:
  ```bash
  ssh ubnt@192.168.1.50 'killall ubnt_lcm_gui || true; killall ubnt_sounds_leds || true'
  ```


## License

Released under the MIT License.  
Use and modify freely, but use caution — these scripts are for educational and experimental purposes only.


## Related Blog Posts

- [Part 1: Living with the UniFi G4 Doorbell Pro](https://chrishansen.tech/posts/unifi_g4_doorbell_pro_review/)
- [Part 2: Automating UniFi Protect Alarms and Webhooks](https://chrishansen.tech/posts/unifi_g4_doorbell_pro_part2/)
- [Part 3: NFC and Fingerprint Access with Home Assistant](https://chrishansen.tech/posts/unifi_g4_doorbell_pro_part3/)
- [Part 4: Custom Animations and Sounds with SSH and SCP](https://chrishansen.tech/posts/unifi_g4_doorbell_pro_part4/)
