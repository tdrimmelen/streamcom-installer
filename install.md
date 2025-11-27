# StreamCom Beltpack Installation Guide

This guide provides step-by-step instructions for installing the StreamCom beltpack software on a Raspberry Pi or compatible Linux system.

## Prerequisites

- Raspberry Pi (or compatible Linux system)
- Network connectivity (Ethernet or WiFi)
- SSH access to the device
- A unique Beltpack ID (e.g., bp0001, bp0002, etc.)

## Installation Steps

### 1. System Preparation

Copy the following files to the PI. Run on the raspberry pi:

```

curl https://tdrimmelen.github.io/streamcom-installer/prepare.sh -o prepare.sh
```

Run the preparation script to configure the system and install dependencies:

```bash
bash prepare.sh
```

This script will:
- Update and upgrade system packages
- Configure WiFi connection (if applicable)
- Enable I2C and SPI interfaces (Raspberry Pi)
- Install required packages (git, python3, pipewire, wireguard, etc.)
- Enable systemd user linger
- Configure persistent journald logging
- Generate SSH keys for git access
- Create timestamped logs in `prepare.log`

**Optional reboot:**
To automatically reboot after preparation:
```bash
REBOOT_AFTER_PREPARE=1 bash prepare.sh
```

**Note:** The script is idempotent and can be safely re-run multiple times.

### 2. SSH Key Configuration

After running prepare.sh, add the generated SSH public key to your GitHub account:

1. The public key is displayed at the end of prepare.sh or can be viewed with:
   ```bash
   cat ~/.ssh/id_rsa.pub
   ```

2. Add this key to your GitHub account:
   - Go to GitHub Settings → SSH and GPG keys
   - Click "New SSH key"
   - Paste the public key and save

### 3. Software Installation

Run the installation script with your beltpack ID:

```bash
bash install.sh <BELTPACK_ID>
```

**Example:**
```bash
bash install.sh bp0001
```

This script will:
- Clone the mumble-test repository (if not in developer mode)
- Create a Python virtual environment
- Install all required dependencies
- Create beltpack.json from template with your specified ID
- Install systemd service files
- Enable autostart services
- Create timestamped logs in `install.log`

**Note:** The script is idempotent and can be safely re-run multiple times.

### 4. Verify Installation

Check that the services are enabled:

```bash
systemctl --user status beltpack-audio.service
systemctl --user status beltpack-control.service
```

### 5. Start Services


Reboot the system to start services automatically:

```bash
sudo reboot
```

## Developer Mode

For development purposes, you can disable automatic git operations by creating a developer file:

```bash
touch ~/developer
```

When this file exists:
- `start_beltpack_audio.sh` will skip git checkout to stable tag
- You can work with local code changes without them being overwritten

To disable developer mode:
```bash
rm ~/developer
```

## Configuration

### Beltpack Configuration

The beltpack configuration is stored in:
```
~/mumble-test/src/streamcom_/beltpack/audio/beltpack.json
```

Key configuration parameters:
- `name`: Beltpack identifier (set during installation)
- `mumble_host`: Mumble server IP address
- `mumble_port`: Mumble server port (default: 64738)
- `volume`: Output volume (0.0 - 1.0)
- `mic_sensitivity`: Input sensitivity (0.0 - 1.0)
- `sidetone_volume`: Sidetone level (0.0 - 1.0)
- `parties`: Party line configurations
- `groups`: Group definitions

### WiFi Configuration

The prepare.sh script configures a WiFi connection named "StreamCom". To modify:

1. Edit the connection:
   ```bash
   sudo nmcli connection modify StreamCom wifi-sec.psk "YourPassword"
   ```

2. Or edit prepare.sh before running it to change SSID and password.

## Logs

Installation and runtime logs are stored in:
- `install/prepare.log` - System preparation log
- `install/install.log` - Software installation log
- `update.log` - Software update log (in repository root)

All logs include timestamps for troubleshooting.

## API Access

Once running, the beltpack API is available at:
```
http://<device-ip>:8000
```

### API Endpoints

- `GET /health` - Health check
- `GET /beltpack/name` - Get beltpack name
- `GET /beltpack` - Get all beltpack properties
- `GET /beltpack/output-volume` - Get output volume
- `PUT /beltpack/output-volume` - Set output volume
- `GET /beltpack/output-muted` - Get output mute status
- `PUT /beltpack/output-muted` - Set output mute
- `GET /beltpack/input-sensitivity` - Get input sensitivity
- `PUT /beltpack/input-sensitivity` - Set input sensitivity
- `GET /beltpack/input-muted` - Get input mute status
- `PUT /beltpack/input-muted` - Set input mute
- `GET /beltpack/sidetone-level` - Get sidetone level
- `PUT /beltpack/sidetone-level` - Set sidetone level
- `GET /beltpack/sidetone-enabled` - Get sidetone enabled status
- `PUT /beltpack/sidetone-enabled` - Set sidetone enabled
- `GET /beltpack/groups` - Get all groups
- `GET /beltpack/parties/{group_uuid}/mute` - Get party mute status
- `PUT /beltpack/parties/{group_uuid}/mute` - Set party mute

### API Documentation

Interactive API documentation is available at:
```
http://<device-ip>:8000/docs
```

## Troubleshooting

### Services not starting

Check service status and logs:
```bash
systemctl --user status beltpack-audio.service
journalctl --user -u beltpack-audio.service -f
```

### Audio issues

Check PipeWire status:
```bash
systemctl --user status pipewire
pw-cli info all
```

### Network connectivity

Check network configuration:
```bash
nmcli connection show
nmcli device status
```

### Git authentication issues

Verify SSH key is added to GitHub:
```bash
ssh -T git@github.com
```

### Re-running installation

Both scripts are idempotent and can be re-run safely:
```bash
# Re-run preparation
bash install/prepare.sh

# Re-run installation with same or different ID
bash install/install.sh bp0001
```

To regenerate configuration with a new ID, delete the existing config first:
```bash
rm ~/mumble-test/src/streamcom_/beltpack/audio/beltpack.json
bash install/install.sh bp0002
```

## Uninstallation

To remove the beltpack services:

```bash
# Stop services
systemctl --user stop beltpack-audio.service
systemctl --user stop beltpack-control.service

# Disable services
systemctl --user disable beltpack-audio.service
systemctl --user disable beltpack-control.service

# Remove service files
rm ~/.config/systemd/user/beltpack-*.service

# Reload systemd
systemctl --user daemon-reload

# Optionally remove repository
rm -rf ~/mumble-test
```

## Support

For issues or questions, please refer to the project documentation or contact the development team.
