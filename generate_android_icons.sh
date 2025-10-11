#!/bin/bash

# Script to generate Android app icons from a main icon
# Usage: ./generate_android_icons.sh

ICON_SOURCE="assets/images/app_icon.png"
ANDROID_RES_DIR="android/app/src/main/res"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y imagemagick
fi

# Check if source icon exists
if [ ! -f "$ICON_SOURCE" ]; then
    echo "Error: Source icon not found at $ICON_SOURCE"
    echo "Please save your icon as 'app_icon.png' in the assets/images/ directory"
    exit 1
fi

echo "Generating Android app icons from $ICON_SOURCE..."

# Generate icons for different densities
# mdpi: 48x48
convert "$ICON_SOURCE" -resize 48x48 "$ANDROID_RES_DIR/mipmap-mdpi/ic_launcher.png"

# hdpi: 72x72
convert "$ICON_SOURCE" -resize 72x72 "$ANDROID_RES_DIR/mipmap-hdpi/ic_launcher.png"

# xhdpi: 96x96
convert "$ICON_SOURCE" -resize 96x96 "$ANDROID_RES_DIR/mipmap-xhdpi/ic_launcher.png"

# xxhdpi: 144x144
convert "$ICON_SOURCE" -resize 144x144 "$ANDROID_RES_DIR/mipmap-xxhdpi/ic_launcher.png"

# xxxhdpi: 192x192
convert "$ICON_SOURCE" -resize 192x192 "$ANDROID_RES_DIR/mipmap-xxxhdpi/ic_launcher.png"

echo "Android app icons generated successfully!"
echo "Icons saved to:"
echo "  - mipmap-mdpi/ic_launcher.png (48x48)"
echo "  - mipmap-hdpi/ic_launcher.png (72x72)"
echo "  - mipmap-xhdpi/ic_launcher.png (96x96)"
echo "  - mipmap-xxhdpi/ic_launcher.png (144x144)"
echo "  - mipmap-xxxhdpi/ic_launcher.png (192x192)"
