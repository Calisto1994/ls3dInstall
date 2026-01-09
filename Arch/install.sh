#!/bin/bash

echo "WBS LearnSpace 3D - Universal Arch Installer"
echo "---------------------------------------------"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Install dependencies
echo "Preparing system and installing packages (Wine, Zenity, Winetricks)..."
sudo pacman -S --needed --noconfirm wget wine winetricks zenity

# 2. NVIDIA Detection and Variable Setup
# We check for nvidia-smi to see if Hardware + Drivers are present
nvidia_prefix=""
if command_exists "nvidia-smi"; then
    echo "NVIDIA Graphics Card detected."
    read -r -p "Do you want to start the application with the NVIDIA GPU? (Render Offload) [y/N] " nv_choice
    nv_choice=${nv_choice:-N}
    if [[ "$nv_choice" =~ ^[JjYy]$ ]]; then
        # These are the native variables for NVIDIA Prime Render Offload
        nvidia_prefix="__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only "
        echo ">>> NVIDIA Offload enabled."
    else
        echo ">>> NVIDIA Offload disabled. Using integrated graphics."
    fi
fi

# 3. MangoHud FPS Limit Setup
mangohud_prefix=""

read -r -p "Do you want to enable a 60 FPS limit (recommended for laptops, this will install mangohud)? [y/N] " fps_choice
fps_choice=${fps_choice:-N}
if [[ "$fps_choice" =~ ^[JjYy]$ ]]; then
    sudo pacman -S --needed --noconfirm mangohud
    mangohud_prefix="MANGOHUD_CONFIG=\"fps_limit=60,no_display\" mangohud "
    echo ">>> FPS Limit (60) enabled."
else
    echo ">>> No FPS limit via MangoHud."
fi

# 4. DXVK Configuration
echo "Configuring DXVK (for better 3D performance under Wine)..."
winetricks dxvk

# 5. Download & Installation
installURL="http://itsupport.wbstraining.de/tnlogin/Business/Install_LS3D.EXE"
INSTALLER="Install_LS3D.EXE"
echo "Downloading WBS Installer..."
wget -O "$INSTALLER" "$installURL"

if [ -f "$INSTALLER" ]; then
    echo "Starting WBS Installer..."
    wine "./$INSTALLER"
else
    echo "Error: Download failed."
    exit 1
fi

# 6. Create Launch Script
# This script will be called by the browser via the URI handler
LAUNCH_DIR="$HOME/.wine/drive_c/users/$USER/AppData/Local/TriCAT/WBS"
mkdir -p "$LAUNCH_DIR"

echo "Creating launch script..."
cat <<EOF_SCRIPT > "$LAUNCH_DIR/launch-ls3d.sh"
#!/bin/bash
URI="\$1"

# Extract backend from URI
if [[ "\$URI" == *"?backend="* ]]; then
    backendServer=\$(echo "\$URI" | sed -n 's/.*[?&]backend=\([^&]*\).*/\1/p')
else
    backendServer=\${URI#ls3d:}
    backendServer=\${backendServer##//}
fi
backendServer=\$(echo "\$backendServer" | sed 's:/*\$::')

if [ -z "\$backendServer" ]; then
    zenity --error --text="Error: Could not determine backend server."
    exit 1
fi

# Actual program start with the selected prefixes
cd "$LAUNCH_DIR"
${mangohud_prefix}${nvidia_prefix}wine learnspace3d.exe -backend "\$backendServer"
EOF_SCRIPT

chmod +x "$LAUNCH_DIR/launch-ls3d.sh"

# 7. Desktop Integration (URI Handler)
DESKTOP_PATH="$HOME/.local/share/applications/ls3d-wbs-handler.desktop"

echo "[Desktop Entry]
Name=LS3D WBS LearnSpace Handler
Exec=$LAUNCH_DIR/launch-ls3d.sh %u
Icon=wine
Type=Application
Terminal=false
MimeType=x-scheme-handler/ls3d;
NoDisplay=true
Path=$LAUNCH_DIR" > "$DESKTOP_PATH"

update-desktop-database "$HOME/.local/share/applications"

echo "------------------------------------------------"
echo "DONE! The system is ready."
echo "LearnSpace3D will now start via ls3d:// links."
rm -f "$INSTALLER"
