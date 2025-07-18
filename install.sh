#!/bin/bash

# ─────────────────────────────────────────────────────────────
# Wallpaper Changer Installer - For GNOME DE Only
# Author: dhruvpatel16120
# GitHub: https://github.com/dhruvpatel16120/wallpaper-changer
# ─────────────────────────────────────────────────────────────

# ━━━━━━━━[ Root Check ]━━━━━━━━ #
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\n❌ ${RED}This script must be run as root to update GDM wallpaper.${RESET}"
    echo -e "🔐 Please run with: ${YELLOW}sudo ./install.sh${RESET}\n"
    exit 1
fi

# ━━━━━━━━[ Color Codes ]━━━━━━━━ #
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# ━━━━━━━━[ Banner ]━━━━━━━━ #
clear
echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo -e "║${CYAN}                          ▄█     █▄   ▄████████  ▄███████▄                ${RED}║"
echo -e "║${CYAN}                         ███     ███ ███    ███ ███                       ${RED}║"
echo -e "║${CYAN}                         ███     ███ ███    █▀  ███                       ${RED}║"
echo -e "║${CYAN}                         ███     ███ ███        ██████████                ${RED}║"
echo -e "║${CYAN}                         ███     ███ ███               ███                ${RED}║"
echo -e "║${CYAN}                         ███  █  ███ ███    █▄  ███    ███                ${RED}║"
echo -e "║${CYAN}                         ███ ███ ███ ███    ███ ███    ███                ${RED}║"
echo -e "║${CYAN}                          ▀███▀███▀  ████████▀   ▀██████▀                 ${RED}║"
echo -e "║${YELLOW}                            WCS — WallpaperChanger Script                 ${RED}║"
echo -e "║${BLUE}               ⚙️  A clean GNOME wallpaper automation tool                 ${RED}║"
echo -e "║${BLUE}               🛠️  Bash | Systemd | .desktop | Cross-Distro Support        ${RED}║"
echo -e "║${GREEN}              🔗 github.com/dhruvpatel16120/wallpaper-changer             ${RED}║"
echo -e "║${GREEN}                   GNOME Wallpaper Automation Installer                   ${RED}║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ━━━━━━━━[ Warning Message ]━━━━━━━━ #
echo -e "${YELLOW}⚠️  This script is designed ONLY for GNOME-based environments."
echo -e "   It will setup wallpaper-changer system-wide with:"
echo -e "     • Required dependencies"
echo -e "     • systemd service"
echo -e "     • .desktop auto-launch file"
echo -e "   Please ensure you have sudo access and GNOME is your active desktop."
echo -e "   🔁 Reboot After the installation to start the service properly!${RESET}\n"

# ━━━━━━━━[ Safety Net ]━━━━━━━━ #
trap 'echo -e "\n${RED}❌ Installation interrupted. Exiting...${RESET}"; exit 1;' INT TERM
set -e

# ━━━━━━━━[ Paths and Logs ]━━━━━━━━ #
LOG_FILE="$HOME/wallpaper-changer-install.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="/etc/systemd/system"
DESKTOP_AUTOSTART="$HOME/.config/autostart"
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
JAKOOLIT_REPO="https://github.com/jakoolit/wallpapers/archive/refs/heads/main.zip"
TMP_DIR="/tmp/wcs-wallpapers"

# ━━━━━━━━[ Logger ]━━━━━━━━ #
log() {
    echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

handle_error() {
    log "${RED}❌ ERROR: $1${RESET}"
    exit 1
}

# ━━━━━━━━[ Package Manager Detection ]━━━━━━━━ #
detect_package_manager() {
    if command -v apt &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v pacman &>/dev/null; then echo "pacman"
    else handle_error "Unsupported package manager. Please install dependencies manually."
    fi
}

# ━━━━━━━━[ Dependency Installer ]━━━━━━━━ #
install_dependencies() {
    log "${BLUE}🔍 Detecting package manager...${RESET}"
    PM=$(detect_package_manager)

    REQUIRED_PKGS=("xdotool" "x11-utils" "imagemagick" "libglib2.0-dev-bin" "gnome-shell" "gsettings-desktop-schemas" "libglib2.0-dev" "x11-xserver-utils")

    log "${BLUE}📦 Installing required dependencies using: ${PM}${RESET}"

    case "$PM" in
        apt)
            sudo apt update -y
            for pkg in "${REQUIRED_PKGS[@]}"; do
                if ! dpkg -s "$pkg" &>/dev/null; then
                    log "${YELLOW}➕ Installing: $pkg${RESET}"
                    sudo apt install -y "$pkg"
                else
                    log "${GREEN}✔ Already installed: $pkg${RESET}"
                fi
            done
            ;;
        dnf)
            sudo dnf check-update -y || true
            sudo dnf install -y xdotool xorg-x11-utils ImageMagick glib2 gnome-shell gsettings-desktop-schemas
            ;;
        pacman)
            sudo pacman -Sy --noconfirm
            sudo pacman -S --noconfirm xdotool xorg-xwininfo imagemagick glib2 gnome-shell gsettings-desktop-schemas
            ;;
        *)
            handle_error "❌ Package manager not recognized. Supported: apt, dnf, pacman."
            ;;
    esac

    log "${GREEN}✅ Dependency installation complete.${RESET}"
}

# ━━━━━━━━[ File Setup ]━━━━━━━━ #
setup_files() {
    log "${CYAN}📁 Setting up files...${RESET}"
    mkdir -p "$HOME/.local/bin"
    cp "$SCRIPT_DIR/scripts/wallpaper-changer.sh" "$HOME/.local/bin/wallpaper-changer.sh"
    chmod +x "$HOME/.local/bin/wallpaper-changer.sh"

    # systemd
    if [[ -f "$SCRIPT_DIR/system/wallpaper-changer.service" ]]; then
        sudo cp "$SCRIPT_DIR/system/wallpaper-changer.service" "$SERVICE_DIR/"
        sudo systemctl daemon-reexec
        sudo systemctl enable wallpaper-changer.service
        sudo systemctl start wallpaper-changer.service
        log "${GREEN}✅ systemd service installed and started.${RESET}"
    fi

    # autostart
    mkdir -p "$DESKTOP_AUTOSTART"
    if [[ -f "$SCRIPT_DIR/system/wallpaper-changer.desktop" ]]; then
        cp "$SCRIPT_DIR/system/wallpaper-changer.desktop" "$DESKTOP_AUTOSTART/"
        log "${GREEN}✅ .desktop autostart created.${RESET}"
    fi
}

# Prompt user
download_wallpapers_prompt() {
    echo -e "\n\e[1;96m📥 Do you want to download wallpapers from Jakoolit's GitHub repo? (y/n)\e[0m"
    read -rp "Your choice: " choice

    case "$choice" in
        y|Y)
            download_jakoolit_wallpapers
            ;;
        n|N)
            echo -e "\e[1;93m⚠️  Skipping wallpaper download...\e[0m"
            ;;
        *)
            echo -e "\e[1;91m❌ Invalid choice. Skipping...\e[0m"
            ;;
    esac
}

download_jakoolit_wallpapers() {
    local WALLPAPER_DIR="$HOME/Pictures/wallpapers"
    local TMP_DIR="/tmp/wcs_download"
    local GIT_REPO="https://github.com/jakoolit/wallpapers.git"

    echo -e "\n\033[1;96m📥 Downloading wallpapers from Jakoolit's GitHub repository...\033[0m"

    # Ensure required tools
    if ! command -v git &>/dev/null; then
        echo -e "\033[1;91m❌ Git is not installed. Please install it and try again.\033[0m"
        return 1
    fi

    # Prepare folders
    mkdir -p "$TMP_DIR" "$WALLPAPER_DIR"
    rm -rf "$TMP_DIR"/*

    echo -e "\n\033[1;93m🔧 Cloning repository to temporary directory...\033[0m"
    if git clone --depth=1 "$GIT_REPO" "$TMP_DIR/wallpapers"; then
        echo -e "\n\033[1;92m✅ Clone successful!\033[0m"
    else
        echo -e "\033[1;91m❌ Failed to clone the repository. See output above.\033[0m"
        return 1
    fi

    echo -e "\n\033[1;93m📂 Copying wallpapers to: $WALLPAPER_DIR...\033[0m"
    if cp -r "$TMP_DIR/wallpapers/"* "$WALLPAPER_DIR"/; then
        echo -e "\033[1;92m✅ Wallpapers copied successfully!\033[0m"
    else
        echo -e "\033[1;91m❌ Failed to copy wallpapers.\033[0m"
        return 1
    fi

    echo -e "\n\033[1;94m🧹 Cleaning up temporary files...\033[0m"
    rm -rf "$TMP_DIR"

    echo -e "\n\033[1;92m🎉 Wallpapers are ready at: $WALLPAPER_DIR\033[0m"
}

# ━━━━━━━━[ Final Message ]━━━━━━━━ #
print_success() {
    echo -e "\n${GREEN}✅ Installation completed successfully!${RESET}"
    echo -e "🔁 Wallpaper will rotate every 60 seconds via GNOME + systemd"
    echo -e "📂 Place wallpapers inside: ${CYAN}$HOME/Pictures/wallpapers${RESET}"
    echo -e "📄 Log file: ${YELLOW}$LOG_FILE${RESET}"
    echo -e "🖥️ GDM login screen background has been patched."
    echo -e "\n${YELLOW}🔄 A system reboot is required to apply GDM changes.${RESET}"

    read -rp $'\n❓ Do you want to reboot now? (y/N): ' reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}♻️ Rebooting now...${RESET}"
        reboot
    else
        echo -e "${RED}🚫 Reboot skipped. Please reboot manually later.${RESET}"
    fi
}



download_wallpapers_prompt
echo -e " "
log "🚀 Starting installation..."
install_dependencies
setup_files
print_success
