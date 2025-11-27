#!/usr/bin/env bash
set -euo pipefail

# Log file path (relative to repo/install/)
LOG_FILE="$(dirname "$0")/prepare.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Timestamp function - adds timestamp to each line
add_timestamp() {
  while IFS= read -r line; do
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
  done
}

# Export the function so it's available in subshells
export -f add_timestamp

# Duplicate all output to both console and log file with timestamps
{
  # Make apt non-interactive and consistent
  export DEBIAN_FRONTEND=noninteractive

  echo "[START] prepare.sh"

  #Download install script
  curl https://tdrimmelen.github.io/streamcom-installer/install.sh -o install.sh
  curl https://tdrimmelen.github.io/streamcom-installer/uninstall.sh -o uninstall.sh

  # Update and upgrade
  sudo apt-get update -y
  sudo apt-get dist-upgrade -y

  # Configure Wi-Fi connection using nmcli if not already present
  if command -v nmcli >/dev/null 2>&1; then
    if ! sudo nmcli -t -f NAME connection show | grep -qx "StreamCom"; then
      echo "Creating nmcli connection 'StreamCom'"
      sudo nmcli connection add type wifi ifname wlan0 con-name StreamCom ssid "StreamCom" || true
    else
      echo "nmcli connection 'StreamCom' already exists"
    fi
    # Ensure settings are applied idempotently
    sudo nmcli connection modify StreamCom wifi-sec.key-mgmt wpa-psk || true
    sudo nmcli connection modify StreamCom wifi-sec.psk "Interc0msZ1jnG@af!" || true
    sudo nmcli connection modify StreamCom connection.autoconnect yes || true
    sudo nmcli connection modify StreamCom ipv6.method disable || true
  fi

  # Enable I2C and SPI only if raspi-config exists (Raspberry Pi)
  if command -v raspi-config >/dev/null 2>&1; then
    sudo raspi-config nonint do_i2c 0 || true
    sudo raspi-config nonint do_spi 0 || true
  fi

  # Install packages (idempotent with apt-get)
  sudo apt-get install -y vim git python3-pip python3-systemd \
    pipewire pipewire-audio pulseaudio-utils libportaudio2 wireguard resolvconf

  # Prepare the system for auto start
  if command -v loginctl >/dev/null 2>&1; then
    # Enable linger for current user
    CURRENT_USER="${SUDO_USER:-$USER}"
    if id -u "$CURRENT_USER" >/dev/null 2>&1; then
      echo "Enabling linger for user: $CURRENT_USER"
      loginctl enable-linger "$CURRENT_USER" || true
      # Get the actual home directory of the user
      USER_HOME=$(eval echo "~$CURRENT_USER")
      mkdir -p "$USER_HOME/.config/systemd/user"
    fi
  fi

  # Ensure persistent journald only if not already configured
  if [ ! -f /etc/systemd/journald.conf.d/00-persistent.conf ]; then
    sudo mkdir -p /etc/systemd/journald.conf.d
    echo -e "[Journal]\nStorage=persistent" | \
        sudo tee /etc/systemd/journald.conf.d/00-persistent.conf >/dev/null
  fi  

  # Generate SSH key to be used in git if it doesn't exist
  if [ -d "$HOME" ]; then
    mkdir -p "$HOME/.ssh"
    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
      echo "Generating SSH key at $HOME/.ssh/id_rsa"
      ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa"
    fi
    # Show the public key path if it exists
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
      echo "SSH public key:"
      cat "$HOME/.ssh/id_rsa.pub"
    fi
  fi

  # Reboot only if explicitly requested
  if [ "${REBOOT_AFTER_PREPARE:-}" = "1" ]; then
    echo "Reboot requested via REBOOT_AFTER_PREPARE=1"
    sudo reboot
  fi

  echo "[DONE] prepare.sh"

} 2>&1 | add_timestamp | tee -a "$LOG_FILE"
