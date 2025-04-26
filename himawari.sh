#!/usr/bin/env bash

# ====================================================================
# Himawari-8 Wallpaper Setter
# This script downloads the latest image from the Himawari-8 satellite
# and sets it as the desktop wallpaper across multiple desktop environments
# ====================================================================

set -e  # Exit immediately if a command fails

# === Configuration ===
SAVE_DIR="${HOME}/Pictures/Wallpapers"
IMAGE_NAME="himawari8_latest.png"
IMAGE_PATH="${SAVE_DIR}/${IMAGE_NAME}"
BASE_URL="https://himawari8-dl.nict.go.jp/himawari8/img/D531106"
JSON_URL="${BASE_URL}/latest.json"
IMAGE_URL_TEMPLATE="${BASE_URL}/1d/550"  # Will append /YYYY/MM/DD/HHMMSS_0_0.png

# === Helper Functions ===

# Display error message and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Log messages with timestamp
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Set wallpaper using various methods based on desktop environment
set_wallpaper() {
    local image_path="$1"
    local file_uri="file://${image_path}"
    local success=false
    
    log_msg "Attempting to set wallpaper using available methods..."
    
    # Try GNOME-based environments (GNOME, Ubuntu, Pop!_OS, Budgie, etc.)
    if command_exists gsettings; then
        log_msg "Trying gsettings (GNOME/Ubuntu/Pop!_OS/Budgie)..."
        gsettings set org.gnome.desktop.background picture-uri "$file_uri" 2>/dev/null && \
        gsettings set org.gnome.desktop.background picture-uri-dark "$file_uri" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via gsettings."
    fi
    
    # Try Cinnamon
    if ! $success && command_exists gsettings; then
        log_msg "Trying Cinnamon settings..."
        gsettings set org.cinnamon.desktop.background picture-uri "$file_uri" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via Cinnamon."
    fi
    
    # Try MATE
    if ! $success && command_exists gsettings; then
        log_msg "Trying MATE settings..."
        gsettings set org.mate.background picture-filename "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via MATE."
    fi
    
    # Try XFCE
    if ! $success && command_exists xfconf-query; then
        log_msg "Trying XFCE settings..."
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via XFCE."
        
        # Try setting for all monitors/workspaces in XFCE
        if ! $success; then
            if xfconf-query -c xfce4-desktop -l | grep -q 'last-image$'; then
                xfconf-query -c xfce4-desktop -l | grep 'last-image$' | while read -r property; do
                    xfconf-query -c xfce4-desktop -p "$property" -s "$image_path" 2>/dev/null
                done
                success=true && log_msg "Wallpaper set for all XFCE workspaces."
            fi
        fi
    fi
    
    # Try KDE Plasma
    if ! $success && command_exists plasma-apply-wallpaperimage; then
        log_msg "Trying KDE Plasma with plasma-apply-wallpaperimage..."
        plasma-apply-wallpaperimage "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via plasma-apply-wallpaperimage."
    elif ! $success && command_exists qdbus; then
        log_msg "Trying KDE Plasma with qdbus..."
        qdbus_script="
            var allDesktops = desktops();
            for (i=0; i<allDesktops.length; i++) {
                d = allDesktops[i];
                d.wallpaperPlugin = 'org.kde.image';
                d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
                d.writeConfig('Image', '$file_uri');
            }"
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$qdbus_script" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via KDE qdbus."
    fi
    
    # Try LXQt/LXDE with pcmanfm
    if ! $success && command_exists pcmanfm-qt; then
        log_msg "Trying LXQt with pcmanfm-qt..."
        pcmanfm-qt --set-wallpaper="$image_path" --wallpaper-mode=fit 2>/dev/null && \
        success=true && log_msg "Wallpaper set via pcmanfm-qt."
    elif ! $success && command_exists pcmanfm; then
        log_msg "Trying LXDE with pcmanfm..."
        pcmanfm --set-wallpaper="$image_path" --wallpaper-mode=fit 2>/dev/null && \
        success=true && log_msg "Wallpaper set via pcmanfm."
    fi
    
    # Try Enlightenment
    if ! $success && command_exists enlightenment_remote; then
        log_msg "Trying Enlightenment..."
        enlightenment_remote -desktop-bg-add 0 0 0 0 "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via Enlightenment."
    fi
    
    # Try Sway (Wayland)
    if ! $success && command_exists swaymsg && [ "$WAYLAND_DISPLAY" ]; then
        log_msg "Trying Sway (Wayland)..."
        swaymsg "output * bg '$image_path' fill" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via Sway."
    fi
    
    # Try Hyprland (Wayland)
    if ! $success && command_exists hyprctl && [ "$WAYLAND_DISPLAY" ]; then
        log_msg "Trying Hyprland (Wayland)..."
        hyprctl hyprpaper preload "$image_path" 2>/dev/null && \
        hyprctl hyprpaper wallpaper "eDP-1,$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via Hyprland."
    fi
    
    # Try common wallpaper tools as fallback
    # feh (commonly used by i3, openbox, and other window managers)
    if ! $success && command_exists feh; then
        log_msg "Trying feh (common WM fallback)..."
        feh --bg-fill "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via feh."
    fi
    
    # hsetroot (alternative to feh)
    if ! $success && command_exists hsetroot; then
        log_msg "Trying hsetroot..."
        hsetroot -fill "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via hsetroot."
    fi
    
    # nitrogen (another common wallpaper setter)
    if ! $success && command_exists nitrogen; then
        log_msg "Trying nitrogen..."
        nitrogen --set-zoom-fill --save "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via nitrogen."
    fi
    
    # xwallpaper (newer alternative)
    if ! $success && command_exists xwallpaper; then
        log_msg "Trying xwallpaper..."
        xwallpaper --zoom "$image_path" 2>/dev/null && \
        success=true && log_msg "Wallpaper set via xwallpaper."
    fi

    # Return result
    $success
}

# Detect if running in curl or wget environment
get_download_tool() {
    if command_exists curl; then
        echo "curl"
    elif command_exists wget; then
        echo "wget"
    else
        error_exit "Neither curl nor wget found. Please install one of them."
    fi
}

# Download file using available tool
download_file() {
    local url="$1"
    local output="$2"
    local tool=$(get_download_tool)
    
    if [ "$tool" = "curl" ]; then
        curl -s -f -o "$output" "$url" || return 1
    else
        wget -q -O "$output" "$url" || return 1
    fi
    return 0
}

# Parse JSON without requiring jq
parse_json_date() {
    local json_file="$1"
    local date_str=""
    
    if command_exists jq; then
        # Use jq if available
        date_str=$(jq -r '.date' "$json_file")
    else
        # Fallback to grep/sed if jq not available
        date_str=$(grep -o '"date":"[^"]*"' "$json_file" | sed 's/"date":"//;s/"//')
    fi
    
    echo "$date_str"
}

# === Main Script ===

log_msg "Starting Himawari-8 Wallpaper Setter"

# Create save directory if it doesn't exist
mkdir -p "$SAVE_DIR" || error_exit "Could not create save directory: $SAVE_DIR"

# Step 1: Get the timestamp of the latest image
log_msg "Fetching latest image timestamp..."
JSON_TEMP=$(mktemp) || error_exit "Could not create temporary file"
download_file "$JSON_URL" "$JSON_TEMP" || error_exit "Failed to download latest timestamp JSON from $JSON_URL"

# Parse the date string
LATEST_DATE_STR=$(parse_json_date "$JSON_TEMP")
rm "$JSON_TEMP" # Clean up temporary file

if [ -z "$LATEST_DATE_STR" ] || [ "$LATEST_DATE_STR" = "null" ]; then
    error_exit "Could not parse date from JSON."
fi
log_msg "Latest image timestamp: $LATEST_DATE_STR"

# Step 2: Format timestamp components needed for the URL
# Handle date formatting across different systems (GNU/BSD date)
format_date() {
    local format="$1"
    local date_str="$2"
    
    # Try GNU date format with -d option
    if date -d "$date_str" +"$format" 2>/dev/null; then
        return 0
    fi
    
    # Try BSD date format with -j option (macOS)
    if date -j -f "%Y-%m-%d %H:%M:%S" "$date_str" +"$format" 2>/dev/null; then
        return 0
    fi
    
    # Manual parsing as last resort
    local year=$(echo "$date_str" | cut -d'-' -f1)
    local month=$(echo "$date_str" | cut -d'-' -f2)
    local day=$(echo "$date_str" | cut -d' ' -f1 | cut -d'-' -f3)
    local time=$(echo "$date_str" | cut -d' ' -f2)
    local hour=$(echo "$time" | cut -d':' -f1)
    local minute=$(echo "$time" | cut -d':' -f2)
    local second=$(echo "$time" | cut -d':' -f3)
    
    case "$format" in
        "%Y") echo "$year" ;;
        "%m") echo "$month" ;;
        "%d") echo "$day" ;;
        "%H") echo "$hour" ;;
        "%M") echo "$minute" ;;
        "%S") echo "$second" ;;
        *) return 1 ;;
    esac
}

# Get date components
YEAR=$(format_date "%Y" "$LATEST_DATE_STR")
MONTH=$(format_date "%m" "$LATEST_DATE_STR")
DAY=$(format_date "%d" "$LATEST_DATE_STR")
HOUR=$(format_date "%H" "$LATEST_DATE_STR")
MINUTE=$(format_date "%M" "$LATEST_DATE_STR")
SECOND=$(format_date "%S" "$LATEST_DATE_STR")

# Construct the specific image URL
IMAGE_URL="${IMAGE_URL_TEMPLATE}/${YEAR}/${MONTH}/${DAY}/${HOUR}${MINUTE}${SECOND}_0_0.png"
log_msg "Constructed image URL: $IMAGE_URL"

# Step 3: Download the latest image
log_msg "Downloading latest image to $IMAGE_PATH..."
download_file "$IMAGE_URL" "$IMAGE_PATH" || error_exit "Failed to download image from $IMAGE_URL"

# Basic image validation
if command_exists file; then
    if ! file "$IMAGE_PATH" | grep -qE 'image|bitmap|PNG'; then
        error_exit "Downloaded file does not appear to be a valid image: $IMAGE_PATH"
    fi
else
    # Simple size check if 'file' command not available
    if [ ! -s "$IMAGE_PATH" ]; then
        error_exit "Downloaded file is empty: $IMAGE_PATH"
    fi
fi

log_msg "Image downloaded successfully."

# Step 4: Set the wallpaper
ABS_IMAGE_PATH=$(readlink -f "$IMAGE_PATH" 2>/dev/null || echo "$IMAGE_PATH")
if set_wallpaper "$ABS_IMAGE_PATH"; then
    log_msg "Wallpaper set successfully!"
else
    log_msg "Could not set wallpaper automatically. Image saved to: $IMAGE_PATH"
    log_msg "You may need to set it manually using your Desktop Environment's settings."
    exit 1
fi

exit 0
