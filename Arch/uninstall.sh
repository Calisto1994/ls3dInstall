#!/bin/bash
set -euo pipefail

echo "WBS LearnSpace 3D - Arch Uninstaller"
echo "------------------------------------"

# 1. Define Paths
WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/wineprefixes/ls3d}"
LAUNCH_DIR="$WINEPREFIX/drive_c/users/$USER/AppData/Local/TriCAT/WBS"
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

# 3b. Optionally remove the whole Wine prefix (incl. DXVK)
if [ -d "$WINEPREFIX" ]; then
    read -r -p "Do you want to delete the dedicated Wine prefix ($WINEPREFIX)? [y/N] " delete_prefix
    if [[ "$delete_prefix" =~ ^[JjYy]$ ]]; then
        echo "Deleting $WINEPREFIX..."
        rm -rf "$WINEPREFIX"
    else
        echo "Keeping Wine prefix."
    fi
else
    echo "Wine prefix not found. Skipping."
fi

# 4. Optional: Remove Pacman Packages (only the ones actually installed)
read -r -p "Do you want to uninstall the dependencies (wine, winetricks, zenity, mangohud)? [y/N] " remove_pkgs
if [[ "$remove_pkgs" =~ ^[JjYy]$ ]]; then
    installed_pkgs=""
    for pkg in wine winetricks zenity mangohud; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            installed_pkgs="$installed_pkgs $pkg"
        fi
    done
    if [ -n "${installed_pkgs// /}" ]; then
        echo "Removing packages:$installed_pkgs"
        sudo pacman -Rns --noconfirm $installed_pkgs
    else
        echo "No matching packages installed. Skipping."
    fi
else
    echo "Keeping installed packages."
fi

echo "------------------------------------"
echo "Uninstallation process finished."
echo "Done."
