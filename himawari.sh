#!/usr/bin/env bash

# === Configuration ===
# Directory to save the wallpaper image
SAVE_DIR="${HOME}/Pictures/Wallpapers"
# Filename for the latest image
IMAGE_NAME="himawari8_latest.png"
# Full path to the image file
IMAGE_PATH="${SAVE_DIR}/${IMAGE_NAME}"
# Base URL for Himawari-8 images (using the 1d/550px version for simplicity)
BASE_URL="https://himawari8-dl.nict.go.jp/himawari8/img/D531106"
JSON_URL="${BASE_URL}/latest.json"
IMAGE_URL_TEMPLATE="${BASE_URL}/1d/550" # Appends /YYYY/MM/DD/HHMMSS_0_0.png

# === Script Logic ===

echo "--- Himawari-8 Wallpaper Setter ---"

# Check dependencies
if ! command -v wget &> /dev/null; then
    echo "Error: 'wget' command not found. Please install it." >&2
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' command not found. Please install it (e.g., sudo apt install jq)." >&2
    exit 1
fi

# Create save directory if it doesn't exist
mkdir -p "$SAVE_DIR"
if [ ! -d "$SAVE_DIR" ]; then
    echo "Error: Could not create save directory: $SAVE_DIR" >&2
    exit 1
fi

# --- Step 1: Get the timestamp of the latest image ---
echo "Fetching latest image timestamp..."
# Use mktemp for the temporary JSON file
JSON_TEMP=$(mktemp)
if ! wget -q -O "$JSON_TEMP" "$JSON_URL"; then
    echo "Error: Failed to download latest timestamp JSON from $JSON_URL" >&2
    rm "$JSON_TEMP"
    exit 1
fi

# Parse the date string (e.g., "2023-10-27 08:00:00")
LATEST_DATE_STR=$(jq -r '.date' "$JSON_TEMP")
rm "$JSON_TEMP" # Clean up temporary file

if [ -z "$LATEST_DATE_STR" ] || [ "$LATEST_DATE_STR" == "null" ]; then
    echo "Error: Could not parse date from JSON." >&2
    exit 1
fi
echo "Latest image timestamp: $LATEST_DATE_STR"

# --- Step 2: Format timestamp components needed for the URL ---
# Use 'date -d' which understands the JSON timestamp format
YEAR=$(date -d "$LATEST_DATE_STR" +%Y)
MONTH=$(date -d "$LATEST_DATE_STR" +%m)
DAY=$(date -d "$LATEST_DATE_STR" +%d)
HOUR=$(date -d "$LATEST_DATE_STR" +%H)
MINUTE=$(date -d "$LATEST_DATE_STR" +%M)
SECOND=$(date -d "$LATEST_DATE_STR" +%S)

# Construct the specific image URL
IMAGE_URL="${IMAGE_URL_TEMPLATE}/${YEAR}/${MONTH}/${DAY}/${HOUR}${MINUTE}${SECOND}_0_0.png"
echo "Constructed image URL: $IMAGE_URL"

# --- Step 3: Download the latest image ---
echo "Downloading latest image to $IMAGE_PATH..."
if ! wget -q -O "$IMAGE_PATH" "$IMAGE_URL"; then
    echo "Error: Failed to download image from $IMAGE_URL" >&2
    # Optionally remove partially downloaded file: rm -f "$IMAGE_PATH"
    exit 1
fi

# Check if the downloaded file looks like a valid image (basic check)
if ! file "$IMAGE_PATH" | grep -qE 'image|bitmap'; then
   echo "Error: Downloaded file does not appear to be a valid image: $IMAGE_PATH" >&2
   echo "Check the URL manually: $IMAGE_URL"
   rm -f "$IMAGE_PATH"
   exit 1
fi

echo "Image downloaded successfully."

# --- Step 4: Set the wallpaper based on Desktop Environment ---
echo "Attempting to set wallpaper for detected Desktop Environment..."

# Get absolute path for commands that need it
ABS_IMAGE_PATH=$(readlink -f "$IMAGE_PATH")
FILE_URI="file://${ABS_IMAGE_PATH}"

# Detect DE using standard environment variables first
DESKTOP_ENV=""
if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    DESKTOP_ENV=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
elif [ -n "$DESKTOP_SESSION" ]; then
    DESKTOP_ENV=$(echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]')
fi

echo "Detected DE variable: $DESKTOP_ENV"

SET_SUCCESS=false

if [[ "$DESKTOP_ENV" == *"gnome"* ]] || [[ "$DESKTOP_ENV" == *"cinnamon"* ]] || [[ "$DESKTOP_ENV" == *"mate"* ]] || [[ "$DESKTOP_ENV" == *"budgie"* ]]; then
    echo "Setting wallpaper using gsettings (GNOME/Cinnamon/MATE/Budgie)..."
    if command -v gsettings &> /dev/null; then
        # Set for both light and dark modes
        gsettings set org.gnome.desktop.background picture-uri "$FILE_URI" && \
        gsettings set org.gnome.desktop.background picture-uri-dark "$FILE_URI"
        if [ $? -eq 0 ]; then
             echo "Wallpaper set via gsettings."
             SET_SUCCESS=true
        else
             echo "gsettings command failed." >&2
        fi
    else
        echo "gsettings command not found, cannot set wallpaper for GNOME/Cinnamon/MATE." >&2
    fi

elif [[ "$DESKTOP_ENV" == *"xfce"* ]]; then
    echo "Setting wallpaper using xfconf-query (XFCE)..."
    if command -v xfconf-query &> /dev/null; then
        # Find all 'last-image' properties under xfce4-desktop and set them
        xfconf-query -c xfce4-desktop -l | grep 'last-image$' | while read -r property; do
             echo "Setting property: $property"
             xfconf-query -c xfce4-desktop -p "$property" -s "$ABS_IMAGE_PATH"
        done
        # Check if at least one property was likely set (heuristic)
        if xfconf-query -c xfce4-desktop -l | grep -q 'last-image$'; then
             echo "Wallpaper set via xfconf-query (check all monitors/workspaces)."
             SET_SUCCESS=true # Assume success if command ran
        else
             echo "xfconf-query failed or no properties found." >&2
        fi
    else
        echo "xfconf-query command not found, cannot set wallpaper for XFCE." >&2
    fi

elif [[ "$DESKTOP_ENV" == *"kde"* ]] || [[ "$DESKTOP_ENV" == *"plasma"* ]]; then
    echo "Setting wallpaper using qdbus (KDE Plasma)..."
    if command -v qdbus &> /dev/null; then
        # KDE Plasma 5/6 script using qdbus
        qdbus_script="
            var allDesktops = desktops();
            print (allDesktops);
            for (i=0; i<allDesktops.length; i++) {
                d = allDesktops[i];
                d.wallpaperPlugin = 'org.kde.image';
                d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
                d.writeConfig('Image', '$FILE_URI');
            }"
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$qdbus_script"
         if [ $? -eq 0 ]; then
              echo "Wallpaper set via qdbus."
              SET_SUCCESS=true
         else
              echo "qdbus command failed." >&2
         fi
    else
        echo "qdbus command not found. Cannot set wallpaper for KDE Plasma. Try installing qttools5-dev-tools or similar." >&2
    fi

elif [[ "$DESKTOP_ENV" == *"lxqt"* ]]; then
     echo "Setting wallpaper using pcmanfm (LXQt)..."
     if command -v pcmanfm &> /dev/null; then
        pcmanfm --set-wallpaper="$ABS_IMAGE_PATH" --wallpaper-mode=stretch # or fit, center, tile
        if [ $? -eq 0 ]; then
             echo "Wallpaper set via pcmanfm."
             SET_SUCCESS=true
        else
             echo "pcmanfm command failed." >&2
        fi
     else
         echo "pcmanfm command not found, cannot set wallpaper for LXQt." >&2
     fi
fi

# Fallback or specific method for tiling WMs using feh
if ! $SET_SUCCESS && command -v feh &> /dev/null; then
    echo "Trying fallback method using feh (common for i3, Sway, etc.)..."
    feh --bg-scale "$ABS_IMAGE_PATH" # Other options: --bg-center, --bg-fill, --bg-tile
    if [ $? -eq 0 ]; then
         echo "Wallpaper set via feh."
         SET_SUCCESS=true
    else
         echo "feh command failed." >&2
    fi
elif ! $SET_SUCCESS && [ ! -f "$(command -v feh)" ]; then
     echo "feh command not found, skipping feh fallback." >&2
fi


# Final status
if $SET_SUCCESS; then
    echo "--- Wallpaper updated successfully! ---"
else
    echo "--- Wallpaper could not be set automatically. ---" >&2
    echo "Image saved to: $IMAGE_PATH" >&2
    echo "You may need to set it manually using your Desktop Environment's settings." >&2
    exit 1
fi

exit 0