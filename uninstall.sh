#!/usr/bin/env bash
set -euo pipefail

# Log file path (in the directory where the script is run from)
LOG_FILE="$(pwd)/uninstall.log"

# No git prompting
export GIT_TERMINAL_PROMPT=0

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
  echo "[START] uninstall.sh"

  # Define the repository directory
  REPO_DIR="$HOME/mumble-test"
  SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

  # Display what will be removed
  echo "=========================================="
  echo "MUMBLE-TEST UNINSTALL"
  echo "=========================================="
  echo ""
  echo "This script will:"
  echo "  1. Stop and disable systemd services (beltpack-audio, beltpack-control)"
  echo "  2. Remove service files from $SYSTEMD_USER_DIR"
  echo "  3. Delete the mumble-test directory: $REPO_DIR"
  echo ""
  echo "WARNING: This action cannot be undone!"
  echo ""
  echo "Are you sure you want to uninstall? (yes/no): "

  # Ask for confirmation
  read CONFIRMATION

  if [ "$CONFIRMATION" != "yes" ]; then
    echo "Uninstall cancelled by user"
    echo "[CANCELLED] uninstall.sh"
    exit 0
  fi

  echo ""
  echo "Starting uninstall process..."
  echo ""

  # Stop and disable systemd services
  if command -v systemctl >/dev/null 2>&1; then
    echo "Stopping and disabling systemd services..."
    
    # Stop and disable beltpack-audio.service
    if systemctl --user list-unit-files beltpack-audio.service >/dev/null 2>&1; then
      echo "  - Stopping beltpack-audio.service..."
      systemctl --user stop beltpack-audio.service 2>/dev/null || echo "    (service was not running)"
      
      if systemctl --user is-enabled beltpack-audio.service >/dev/null 2>&1; then
        echo "  - Disabling beltpack-audio.service..."
        systemctl --user disable beltpack-audio.service
      else
        echo "    (service was not enabled)"
      fi
    else
      echo "  - beltpack-audio.service not found"
    fi

    # Stop and disable beltpack-control.service
    if systemctl --user list-unit-files beltpack-control.service >/dev/null 2>&1; then
      echo "  - Stopping beltpack-control.service..."
      systemctl --user stop beltpack-control.service 2>/dev/null || echo "    (service was not running)"
      
      if systemctl --user is-enabled beltpack-control.service >/dev/null 2>&1; then
        echo "  - Disabling beltpack-control.service..."
        systemctl --user disable beltpack-control.service
      else
        echo "    (service was not enabled)"
      fi
    else
      echo "  - beltpack-control.service not found"
    fi

    echo "  - Reloading systemd daemon..."
    systemctl --user daemon-reload
  else
    echo "systemctl not found, skipping service management"
  fi

  # Remove service files from systemd user directory
  if [ -d "$SYSTEMD_USER_DIR" ]; then
    echo ""
    echo "Removing service files from $SYSTEMD_USER_DIR..."
    
    if [ -f "$SYSTEMD_USER_DIR/beltpack-audio.service" ]; then
      echo "  - Removing beltpack-audio.service"
      rm -f "$SYSTEMD_USER_DIR/beltpack-audio.service"
    else
      echo "  - beltpack-audio.service not found"
    fi
    
    if [ -f "$SYSTEMD_USER_DIR/beltpack-control.service" ]; then
      echo "  - Removing beltpack-control.service"
      rm -f "$SYSTEMD_USER_DIR/beltpack-control.service"
    else
      echo "  - beltpack-control.service not found"
    fi
  else
    echo "Systemd user directory not found, skipping service file removal"
  fi

  # Remove the mumble-test directory
  if [ -d "$REPO_DIR" ]; then
    echo ""
    echo "Removing mumble-test directory: $REPO_DIR..."
    rm -rf "$REPO_DIR"
    echo "  - Directory removed successfully"
  else
    echo ""
    echo "mumble-test directory not found at $REPO_DIR"
    echo "  - Nothing to remove"
  fi

  echo ""
  echo "=========================================="
  echo "UNINSTALL COMPLETE"
  echo "=========================================="
  echo ""
  echo "The following items have been removed:"
  echo "  - Systemd services (stopped and disabled)"
  echo "  - Service files from $SYSTEMD_USER_DIR"
  echo "  - mumble-test directory from $REPO_DIR"
  echo ""
  echo "Uninstall log saved to: $LOG_FILE"
  echo ""
  echo "[DONE] uninstall.sh"

} 2>&1 | add_timestamp | tee -a "$LOG_FILE"
