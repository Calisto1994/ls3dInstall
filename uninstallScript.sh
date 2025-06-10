#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Determine current user and their home directory
# $HOME should be correct for the user running the script.
# $(whoami) returns the current username.
CURRENT_USER=$(whoami)
USER_HOME="$HOME"

# Paths to relevant files and directories
LS3D_APP_DATA_ROOT_PATH="$USER_HOME/.wine/drive_c/users/$CURRENT_USER/AppData/Local/TriCAT"
LS3D_APP_DATA_PATH="$LS3D_APP_DATA_ROOT_PATH/WBS" # WBS is the specific subfolder
LAUNCH_SCRIPT_PATH="$LS3D_APP_DATA_PATH/launch-ls3d.sh"
UNINSTALL_EXE_PATH="$LS3D_APP_DATA_PATH/Uninstall.exe" # Assumption that Uninstall.exe is located here
DESKTOP_FILE_PATH="/usr/share/applications/ls3d-handler.desktop"

echo "WBS LearnSpace 3D Uninstaller"
echo "--------------------------------"

# Request administrative privileges early
sudo echo "Administrative privileges required for some operations."

# 1. Execute the application's own uninstaller (if present)
if [ -f "$UNINSTALL_EXE_PATH" ]; then
    echo "Attempting to run the application's uninstaller: $UNINSTALL_EXE_PATH"
    echo "Please follow the instructions of the WBS LearnSpace 3D Uninstaller."
    wine "$UNINSTALL_EXE_PATH"
    echo "Application uninstaller finished."
    
    sleep 2
else
    echo "WARNING: Application uninstaller not found at $UNINSTALL_EXE_PATH."
    echo "This might mean the application was already partially uninstalled or not correctly installed."
    echo "Continuing with removal of custom scripts and desktop files."
fi

# 2. Remove custom launch script
# The installation script used sudo to move this file,
# so sudo is safer here in case the file is owned by root.
if [ -f "$LAUNCH_SCRIPT_PATH" ]; then
    echo "Removing custom launch script: $LAUNCH_SCRIPT_PATH"
    sudo rm -f "$LAUNCH_SCRIPT_PATH"
else
    echo "Custom launch script not found (already removed or not installed): $LAUNCH_SCRIPT_PATH"
fi

# 3. Remove desktop file and update database
if [ -f "$DESKTOP_FILE_PATH" ]; then
    echo "Removing desktop file: $DESKTOP_FILE_PATH"
    sudo rm -f "$DESKTOP_FILE_PATH"
    echo "Updating desktop database..."
    sudo update-desktop-database
else
    echo "Desktop file not found (already removed or not installed): $DESKTOP_FILE_PATH"
fi

# 4. Offer to remove installed packages
PACKAGES_TO_REMOVE="wget wine winetricks zenity"
echo ""
read -r -p "Do you want to try to remove the following packages: $PACKAGES_TO_REMOVE? (These might be used by other applications) [y/N]: " REMOVE_PACKAGES_CHOICE
REMOVE_PACKAGES_CHOICE=${REMOVE_PACKAGES_CHOICE:-N} # Default is No

if [[ "$REMOVE_PACKAGES_CHOICE" =~ ^[JjYy]$ ]]; then # Accepts j, J, y, Y
    if command_exists apt-get; then
        echo "Debian-based system detected. Using apt-get."
        echo "Attempting to remove packages: $PACKAGES_TO_REMOVE"
        sudo apt-get remove $PACKAGES_TO_REMOVE
        echo "You might want to run 'sudo apt autoremove' to remove further no longer needed dependencies."
    elif command_exists pacman; then
        echo "Arch-based system detected. Using pacman."
        echo "Attempting to remove packages: $PACKAGES_TO_REMOVE"
        # -Rns removes the package, its unneeded dependencies, and configuration files.
        sudo pacman -Rns $PACKAGES_TO_REMOVE
    else
        echo "Could not find a supported package manager (apt-get/pacman). Skipping package removal."
        echo "Please remove the packages ($PACKAGES_TO_REMOVE) manually if desired."
    fi
else
    echo "Skipping removal of packages: $PACKAGES_TO_REMOVE."
fi

echo ""
echo "Uninstallation process for WBS LearnSpace 3D is complete."
echo "Note: This script does not remove the ~/.wine directory (your Wine prefix) or DXVK installed within it."
echo "If you wish to remove these, you will need to do so manually."
echo "Done."
