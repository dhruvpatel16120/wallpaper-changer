#!/bin/bash

# === Configuration ===
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
LOG_FILE="$HOME/.wallpaper_changer.log"
TEMP_DIR="/tmp/gs-theme-$$"
RESOURCE="/usr/share/gnome-shell/gnome-shell-theme.gresource"
BACKUP="$RESOURCE.bak"
SLEEP_INTERVAL=60

# === Helper Functions ===

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

check_dependencies() {
    local deps=("xdotool" "xwininfo" "xrandr" "convert" "gresource" "glib-compile-resources" "gsettings")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log "Error: Missing dependency '$cmd'. Please install it."
            exit 1
        fi
    done
}

is_fullscreen() {
    local win_id=$(xdotool getactivewindow 2>/dev/null)
    [[ -z "$win_id" ]] && return 1

    local win_geometry=$(xwininfo -id "$win_id" 2>/dev/null | grep -E 'Width|Height')
    local screen_geometry=$(xrandr | grep '*' | awk '{print $1}' | head -n1)

    local screen_width=$(echo "$screen_geometry" | cut -d'x' -f1)
    local screen_height=$(echo "$screen_geometry" | cut -d'x' -f2)
    local win_width=$(echo "$win_geometry" | grep Width | awk '{print $2}')
    local win_height=$(echo "$win_geometry" | grep Height | awk '{print $2}')

    [[ "$win_width" -ge "$screen_width" && "$win_height" -ge "$screen_height" ]]
}

change_gdm_background() {
    local image="$1"

    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR" || return 1

    # Backup original GResource
    if [[ ! -f "$BACKUP" ]]; then
        sudo cp "$RESOURCE" "$BACKUP"
    fi

    # Extract the default texture
    sudo gresource extract "$RESOURCE" /org/gnome/shell/theme/noise-texture.png > noise-texture.png 2>/dev/null || {
        log "Failed to extract GDM resource"
        return 1
    }

    # Convert wallpaper to PNG
    local converted="wall.png"
    convert "$image" "$converted" || {
        log "Image conversion failed for GDM update."
        return 1
    }

    sudo cp "$converted" noise-texture.png

    # Create GResource XML
    cat > gnome-shell-theme.gresource.xml <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gresources>
  <gresource prefix='/org/gnome/shell/theme'>
    <file>noise-texture.png</file>
  </gresource>
</gresources>
EOF

    sudo glib-compile-resources gnome-shell-theme.gresource.xml --target=gnome-shell-theme.gresource --sourcedir=. || {
        log "Failed to compile new GDM theme resource."
        return 1
    }

    sudo cp gnome-shell-theme.gresource "$RESOURCE"
    log "GDM wallpaper successfully updated."
}

set_gnome_wallpaper() {
    local image="$1"
    gsettings set org.gnome.desktop.background picture-uri "file://$image"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$image"
    log "GNOME wallpaper set to: $image"
}

# === Execution Starts ===

check_dependencies

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    log "Wallpaper directory not found: $WALLPAPER_DIR"
    exit 1
fi

log "Wallpaper changer started on GNOME."

LAST_IMAGE=""

while true; do
    if is_fullscreen; then
        log "Fullscreen app detected. Skipping change."
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    IMAGE=$(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | shuf -n1)

    if [[ -z "$IMAGE" ]]; then
        log "No images found in $WALLPAPER_DIR"
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    if [[ "$IMAGE" == "$LAST_IMAGE" ]]; then
        log "Same wallpaper detected, skipping."
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    set_gnome_wallpaper "$IMAGE"
    change_gdm_background "$IMAGE"

    LAST_IMAGE="$IMAGE"
    sleep "$SLEEP_INTERVAL"
done
