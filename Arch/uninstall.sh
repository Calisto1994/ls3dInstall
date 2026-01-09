#!/bin/bash

echo "WBS LearnSpace 3D - Arch Uninstaller"
echo "------------------------------------"

# 1. Define Paths
LAUNCH_DIR="$HOME/.wine/drive_c/users/$USER/AppData/Local/TriCAT/WBS"
DESKTOP_PATH="$HOME/.local/share/applications/ls3d-wbs-handler.desktop"

# 2. Remove Desktop Integration
if [ -f "$DESKTOP_PATH" ]; then
    echo "Removing URI handler desktop file..."
    rm -f "$DESKTOP_PATH"
    update-desktop-database "$HOME/.local/share/applications"
else
    echo "Desktop file not found. Skipping."
fi

# 3. Remove Launch Script and Application Data
if [ -d "$LAUNCH_DIR" ]; then
    read -r -p "Do you want to delete the LearnSpace3D app data and launch script? [y/N] " delete_data
    if [[ "$delete_data" =~ ^[JjYy]$ ]]; then
        echo "Deleting $LAUNCH_DIR..."
        rm -rf "$LAUNCH_DIR"
    else
        echo "Keeping app data."
    fi
else
    echo "Application data directory not found. Skipping."
fi

# 4. Optional: Remove Pacman Packages
read -r -p "Do you want to uninstall the dependencies (wine, winetricks, zenity, mangohud)? [y/N] " remove_pkgs
if [[ "$remove_pkgs" =~ ^[JjYy]$ ]]; then
    echo "Removing packages..."
    sudo pacman -Rns wine winetricks zenity mangohud
else
    echo "Keeping installed packages."
fi

echo "------------------------------------"
echo "Uninstallation process finished."
echo "Done."
