#!/bin/bash

echo "WBS LearnSpace 3D Universal Installer"
echo "-------------------------------------"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update sudo timestamp early and keep it alive
echo "Administrative privileges are needed for installation..."
if sudo -v; then
    # Keep the sudo session alive while the script runs
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )
    SUDO_KEEPALIVE_PID=$!
    trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT
else
    echo "Error: Could not obtain administrative privileges. Aborting."
    exit 1
fi

# --- 1. prime-run detection and prompt ---
prime_run_cmd_prefix=""
if command_exists "prime-run"; then
    read -r -p "prime-run detected. Do you want to use it for LearnSpace3D? (Render Offload for NVIDIA Optimus) [y/N] " prime_run_choice_input
    prime_run_choice_input=${prime_run_choice_input:-N} # Default is No
    if [[ "$prime_run_choice_input" =~ ^[JjYy]$ ]]; then # Accepts j, J, y, Y
        prime_run_cmd_prefix="prime-run "
        echo "prime-run will be used."
    else
        echo "prime-run will not be used."
    fi
else
    echo "prime-run not detected. Skipping prime-run configuration."
fi

# --- 2. MangoHud FPS Limit detection and prompt ---
mangohud_cmd_prefix=""
if command_exists "mangohud"; then
    echo "MangoHud detected."
    read -r -p "Do you want to limit FPS to 60 for LearnSpace3D? (Overlay will be hidden) [y/N] " fps_limit_choice_input
    fps_limit_choice_input=${fps_limit_choice_input:-N} # Default is No
    if [[ "$fps_limit_choice_input" =~ ^[JjYy]$ ]]; then # Accepts j, J, y, Y
        # Set the prefix to include MANGOHUD_CONFIG and the mangohud command itself
        # The environment variable needs to be exported in the inner script for wine/the game to see it.
        # We only pass the command prefix here, the ENV export happens in launch-ls3d.sh
        mangohud_cmd_prefix="MANGOHUD_CONFIG=\"fps_limit=60,no_display\" mangohud "
        echo "FPS will be limited to 60 and the overlay will be hidden."
    else
        echo "FPS will not be limited by MangoHud."
    fi
else
    echo "MangoHud not detected. Skipping FPS limit configuration."
fi

# --- Package manager detection and dependency installation ---
echo "Preparing dependencies..."
PACKAGES="wget wine winetricks zenity" # zenity for notifications in the launch script

if command_exists apt-get; then
    echo "Debian-based system detected. Using apt-get."
    sudo apt-get update
    sudo apt-get install -y $PACKAGES
elif command_exists pacman; then
    echo "Arch-based system detected. Using pacman."
    sudo pacman -S --needed --noconfirm $PACKAGES
else
    echo "ERROR: Neither apt-get nor pacman found. Cannot install dependencies."
    echo "Please install the following packages manually: $PACKAGES"
    # Kill the sudo keepalive before exiting the script
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then kill $SUDO_KEEPALIVE_PID 2>/dev/null; fi
    trap - EXIT # Remove the trap
    exit 1
fi

# Configure DXVK with Winetricks (common step)
echo "Configuring DXVK with winetricks..."
winetricks dxvk

# --- Download & Install WBS LearnSpace 3D ---
installURL="http://itsupport.wbstraining.de/tnlogin/Business/Install_LS3D.EXE"
INSTALLER_FILENAME="Install_LS3D.EXE"
echo "Downloading ${installURL}..."
wget -O "$INSTALLER_FILENAME" "$installURL"

if [ -f "$INSTALLER_FILENAME" ]; then
    echo "Starting WBS LearnSpace 3D Installer with Wine..."
    wine "./$INSTALLER_FILENAME"
    echo "WBS LearnSpace 3D installation finished (by the application installer)."
else
    echo "ERROR: Download of $INSTALLER_FILENAME failed."
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then kill $SUDO_KEEPALIVE_PID 2>/dev/null; fi
    trap - EXIT
    exit 1
fi

# --- Create launch-ls3d.sh startup script ---
echo "Creating launch script (launch-ls3d.sh)..."
# $USER should correctly reflect the currently logged-in user.
# The path within Wine typically uses the Linux username.
LS3D_LAUNCH_SCRIPT_DIR_LINUX="$HOME/.wine/drive_c/users/$USER/AppData/Local/TriCAT/WBS"

# Ensure the target directory for launch-ls3d.sh exists
mkdir -p "$LS3D_LAUNCH_SCRIPT_DIR_LINUX"

# The content of launch-ls3d.sh. ${prime_run_cmd_prefix} and ${mangohud_cmd_prefix} will be expanded by the outer script.
# The `mangohud_cmd_prefix` contains the necessary variables and the `mangohud` command itself.
cat <<EOF > "$LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh"
#!/bin/bash
URI="\$1"
# Command prefix determined by the outer script (e.g., mangohud prime-run)
CMD_PREFIX="${mangohud_cmd_prefix}${prime_run_cmd_prefix}"

if [[ "\$URI" == *"?backend="* ]]; then
    # Extract the value of the 'backend' query parameter
    backendServer=\$(echo "\$URI" | sed -n 's/.*[?&]backend=\([^&]*\).*/\1/p')
else
    # Assume URI is ls3d:backendServer or ls3d://backendServer
    backendServer=\${URI#ls3d:}
    backendServer=\${backendServer##//} # Remove leading //
fi

# Clean up possible trailing slashes
backendServer=\$(echo "\$backendServer" | sed 's:/*\$::')

if [ -z "\$backendServer" ]; then
    zenity --error --text="Could not determine backend server from URI: \$URI" --title="LearnSpace3D Error"
    exit 1
fi

zenity --info --text="Starting LearnSpace3D with Backend: \${backendServer}." --title="LearnSpace3D"
# Execute: [MANGOHUD_CONFIG=... mangohud] [prime-run] wine learnspace3d.exe -backend "\$backendServer"
\${CMD_PREFIX}wine learnspace3d.exe -backend "\$backendServer"
EOF
chmod +x "$LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh"
echo "Launch script created at $LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh"

# --- Create ls3d-handler.desktop file ---
echo "Creating ls3d URI Handler Desktop file..."
DESKTOP_FILE_NAME="ls3d-wbs-handler.desktop"
DESKTOP_FILE_PATH="/usr/share/applications/$DESKTOP_FILE_NAME"

# Content of the .desktop file
# The working directory (Path) is important for wine to find learnspace3d.exe.
DESKTOP_FILE_CONTENT="[Desktop Entry]
Name=LS3D WBS LearnSpace Handler
Comment=Handles ls3d:// URI scheme for WBS LearnSpace 3D
Exec=$LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh %u
Icon=wine
Type=Application
Terminal=false
MimeType=x-scheme-handler/ls3d;
NoDisplay=true
Path=$LS3D_LAUNCH_SCRIPT_DIR_LINUX
"

# Write the .desktop file with sudo as it's in /usr/share/applications
echo "$DESKTOP_FILE_CONTENT" | sudo tee "$DESKTOP_FILE_PATH" > /dev/null
# chmod +x is not strictly required for .desktop files, but doesn't hurt.
sudo chmod 644 "$DESKTOP_FILE_PATH" # Correct permissions for .desktop files
echo "Desktop file created at $DESKTOP_FILE_PATH"

# --- Final steps ---
echo "Updating desktop database..."
sudo update-desktop-database

echo "Cleaning up downloaded installer..."
rm -f "$INSTALLER_FILENAME"

# Kill the sudo keepalive
if [ -n "$SUDO_KEEPALIVE_PID" ]; then kill $SUDO_KEEPALIVE_PID 2>/dev/null; fi
trap - EXIT # Remove the trap at the end of a successful run

echo ""
echo "WBS LearnSpace 3D installation should be complete."
echo "You can now try to open an ls3d:// link."
echo "Done."
