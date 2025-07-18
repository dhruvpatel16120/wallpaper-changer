#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ #
#  Wallpaper Changer Uninstaller Script for GNOME
#  Author: dhruvpatel16120 (github.com/dhruvpatel16120)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ #

SERVICE_NAME="wallpaper-changer.service"
DESKTOP_FILE="wallpaper-changer.desktop"
AUTOSTART_PATH="/etc/xdg/autostart/$DESKTOP_FILE"
SYSTEMD_PATH="/etc/systemd/system/$SERVICE_NAME"
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
LOG_FILE="$HOME/wallpaper-changer-install.log"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ #

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log() {
    echo -e "[${CYAN}$(date +'%T')${RESET}] $1"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root."
        exit 1
    fi
}

confirm() {
    read -p "❓ Do you also want to delete wallpapers and logs? (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]]
}

prompt_reboot() {
    read -p "🔁 Do you want to reboot now to apply changes? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        log "♻️  Rebooting system..."
        reboot
    else
        log "🚫 Reboot skipped. Please reboot manually later."
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ #

log "🧼 Starting uninstallation of Wallpaper Changer..."

check_root

# Stop and disable the systemd service
if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    log "🛑 Stopping and disabling $SERVICE_NAME"
    systemctl stop "$SERVICE_NAME"
    systemctl disable "$SERVICE_NAME"
    rm -f "$SYSTEMD_PATH"
    systemctl daemon-reload
else
    log "ℹ️  Service $SERVICE_NAME not found, skipping..."
fi

# Remove autostart desktop entry
if [ -f "$AUTOSTART_PATH" ]; then
    log "🗑️  Removing autostart file..."
    rm -f "$AUTOSTART_PATH"
else
    log "ℹ️  Autostart file not found, skipping..."
fi

# Optional cleanup: Wallpapers and log file
if confirm; then
    log "🧹 Removing: $WALLPAPER_DIR"
    rm -rf "$WALLPAPER_DIR"

    log "🧹 Removing log file: $LOG_FILE"
    rm -f "$LOG_FILE"
fi

log "${GREEN}✅ Wallpaper Changer has been uninstalled successfully!${RESET}"

prompt_reboot
