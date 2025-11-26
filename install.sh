#!/usr/bin/env bash
set -euo pipefail

# Check if beltpack ID is provided
if [ $# -eq 0 ]; then
  echo "Error: Beltpack ID is required"
  echo "Usage: $0 <BELTPACK_ID>"
  echo "Example: $0 bp0001"
  exit 1
fi

BELTPACK_ID="$1"

# Log file path (relative to repo/install/)
LOG_FILE="$(dirname "$0")/install.log"

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
  echo "[START] install.sh with Beltpack ID: $BELTPACK_ID"

  # Define the repository directory
  REPO_DIR="$HOME/mumble-test"

  # Clone the mumble-test repository if it doesn't exist
  if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning mumble-test repository..."
    git clone git@github.com:tdrimmelen/mumble-test.git "$REPO_DIR"
  else
    echo "Repository already exists at $REPO_DIR"
    # Optionally pull latest changes
    cd "$REPO_DIR"
    echo "Pulling latest changes..."
    git pull || true
  fi

  cd "$REPO_DIR"

  # Create virtual environment if it doesn't exist
  if [ ! -d ".venv-beltpack" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv-beltpack --system-site-packages
  else
    echo "Virtual environment already exists"
  fi

  # Install/update dependencies
  echo "Installing dependencies..."
  source .venv-beltpack/bin/activate
  pip install -e .[beltpack] -r requirements-beltpack.txt
  deactivate

  # Copy beltpack config if it doesn't exist
  BELTPACK_CONFIG="src/streamcom_/beltpack/audio/beltpack.json"
  BELTPACK_TEMPLATE="src/streamcom_/beltpack/audio/beltpack template.json"
  
  if [ ! -f "$BELTPACK_CONFIG" ]; then
    if [ -f "$BELTPACK_TEMPLATE" ]; then
      echo "Creating beltpack.json from template with ID: $BELTPACK_ID..."
      # Replace <<BPID>> marker with actual beltpack ID
      sed "s/<<BPID>>/$BELTPACK_ID/g" "$BELTPACK_TEMPLATE" > "$BELTPACK_CONFIG"
      echo "Beltpack configuration created successfully"
    else
      echo "Warning: beltpack template.json not found"
    fi
  else
    echo "beltpack.json already exists, skipping template copy"
    echo "To regenerate with new ID, delete $BELTPACK_CONFIG and run again"
  fi

  # Setup autostart software
  SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
  if [ -d "$SYSTEMD_USER_DIR" ]; then
    echo "Installing systemd service files to $SYSTEMD_USER_DIR..."
    cp systemd/*.service "$SYSTEMD_USER_DIR/" || true
  else
    echo "Warning: $SYSTEMD_USER_DIR directory not found"
    echo "Creating directory..."
    mkdir -p "$SYSTEMD_USER_DIR"
    if [ -d "systemd" ]; then
      cp systemd/*.service "$SYSTEMD_USER_DIR/" || true
    fi
  fi

  # Make bin scripts executable if they exist
  if [ -d "bin" ]; then
    echo "Making bin scripts executable..."
    chmod +x bin/*sh 2>/dev/null || true
  fi

  # Enable systemd services if not already enabled
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user list-unit-files beltpack-audio.service >/dev/null 2>&1; then
      if ! systemctl --user is-enabled beltpack-audio.service >/dev/null 2>&1; then
        echo "Enabling beltpack-audio.service..."
        systemctl --user enable beltpack-audio.service
      else
        echo "beltpack-audio.service already enabled"
      fi
    fi

    if systemctl --user list-unit-files beltpack-control.service >/dev/null 2>&1; then
      if ! systemctl --user is-enabled beltpack-control.service >/dev/null 2>&1; then
        echo "Enabling beltpack-control.service..."
        systemctl --user enable beltpack-control.service
      else
        echo "beltpack-control.service already enabled"
      fi
    fi
  fi

  echo "[DONE] install.sh"

} 2>&1 | add_timestamp | tee -a "$LOG_FILE"
