#!/bin/bash
set -euo pipefail

echo "WBS LearnSpace 3D - Universal Debian/Ubuntu Installer"
echo "---------------------------------------------"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

BASE_PKGS=(wget wine winetricks zenity xdg-utils desktop-file-utils libglib2.0-bin)
MANGOHUD_PKGS=(mangohud)

pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed'; }
pkg_install() { sudo apt-get update && sudo apt-get install -y "$@"; }

# Ask a yes/no question; any non-"y" answer (or no terminal) counts as "no"
ask_yes_no() {
    local answer=""
    read -r -p "$1" answer || answer=""
    [[ "$answer" =~ ^[JjYy]$ ]]
}

# Install only missing packages and remember them, so the uninstaller
# removes nothing that was already on the system before.
install_pkgs() {
    local pkg
    local to_install=()
    for pkg in "$@"; do
        if ! pkg_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    if [ "${#to_install[@]}" -gt 0 ]; then
        pkg_install "${to_install[@]}"
        printf '%s\n' "${to_install[@]}" >> "$STATE_DIR/packages"
    fi
}

# 0. Sanity checks and WINEPREFIX setup
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Please run this script as a normal user (not root / sudo). It asks for sudo itself when needed."
    exit 1
fi
if ! command_exists sudo; then
    echo "Error: sudo is required but not installed."
    exit 1
fi

USER_NAME="$(id -un)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ls3d-installer"
mkdir -p "$STATE_DIR"
touch "$STATE_DIR/packages"

# Dedicated prefix so existing prefixes stay untouched
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/wineprefixes/ls3d}"
mkdir -p "$WINEPREFIX"
touch "$WINEPREFIX/.ls3d-installer"
printf '%s\n' "$WINEPREFIX" > "$STATE_DIR/prefix"
echo "Using Wine prefix: $WINEPREFIX"

# 1. Install dependencies
echo "Preparing system and installing packages (Wine, Zenity, Winetricks)..."
install_pkgs "${BASE_PKGS[@]}"

# 2. NVIDIA Detection and Variable Setup
# We check for nvidia-smi to see if Hardware + Drivers are present
extra_env=""
if command_exists "nvidia-smi"; then
    echo "NVIDIA Graphics Card detected."
    if ask_yes_no "Do you want to start the application with the NVIDIA GPU? (Render Offload) [y/N] "; then
        # These are the native variables for NVIDIA Prime Render Offload
        extra_env+=$'export __NV_PRIME_RENDER_OFFLOAD=1\n'
        extra_env+=$'export __GLX_VENDOR_LIBRARY_NAME=nvidia\n'
        extra_env+=$'export __VK_LAYER_NV_optimus=NVIDIA_only\n'
        echo ">>> NVIDIA Offload enabled."
    else
        echo ">>> NVIDIA Offload disabled. Using integrated graphics."
    fi
fi

# 3. MangoHud FPS Limit Setup
# mangohud is a wrapper command, so it must come right before "wine";
# environment variables are exported separately in the launch script.
mangohud_wrapper=""
if ask_yes_no "Do you want to enable a 60 FPS limit (recommended for laptops, this will install mangohud)? [y/N] "; then
    install_pkgs "${MANGOHUD_PKGS[@]}"
    extra_env+=$'export MANGOHUD_CONFIG=fps_limit=60,no_display\n'
    mangohud_wrapper="mangohud "
    echo ">>> FPS Limit (60) enabled."
else
    echo ">>> No FPS limit via MangoHud."
fi

# 4. DXVK Configuration
echo "Configuring DXVK (for better 3D performance under Wine)..."
winetricks -q dxvk

# 5. Download & Installation (into a private temp dir, cleaned up on exit)
installURL="https://itsupport.wbstraining.de/tnlogin/Business/Install_LS3D.EXE"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
INSTALLER="$TMP_DIR/Install_LS3D.EXE"
echo "Downloading WBS Installer..."
if ! wget -O "$INSTALLER" "$installURL"; then
    echo "Error: Download failed."
    exit 1
fi

echo "Starting WBS Installer..."
# Windows installers often return non-zero codes; success is verified below.
wine "$INSTALLER" || echo "Warning: The installer returned a non-zero exit code. Checking installation..."
wineserver -w || true

# 6. Locate the installed application and create the launch script
# This script will be called by the browser via the URI handler
LAUNCH_DIR="$WINEPREFIX/drive_c/users/$USER_NAME/AppData/Local/TriCAT/WBS"
found_exe="$(find "$LAUNCH_DIR" -maxdepth 1 -iname 'learnspace3d.exe' -print -quit 2>/dev/null || true)"
if [ -z "$found_exe" ]; then
    found_exe="$(find "$WINEPREFIX/drive_c" -iname 'learnspace3d.exe' -print -quit 2>/dev/null || true)"
fi
if [ -z "$found_exe" ]; then
    echo "Error: learnspace3d.exe was not found in the Wine prefix. The WBS installer did not finish successfully."
    exit 1
fi
LAUNCH_DIR="$(dirname "$found_exe")"
EXE_NAME="$(basename "$found_exe")"
printf '%s\n' "$LAUNCH_DIR" > "$STATE_DIR/launch_dir"

echo "Creating launch script..."
q_prefix="$(printf '%q' "$WINEPREFIX")"
q_launch_dir="$(printf '%q' "$LAUNCH_DIR")"
q_exe="$(printf '%q' "$EXE_NAME")"
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

# Actual program start with the selected options
export WINEPREFIX=$q_prefix
${extra_env}cd $q_launch_dir
${mangohud_wrapper}wine $q_exe -backend "\$backendServer"
EOF_SCRIPT
chmod +x "$LAUNCH_DIR/launch-ls3d.sh"

# 7. Desktop Integration (URI Handler)
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_PATH="$APPS_DIR/ls3d-wbs-handler.desktop"
mkdir -p "$APPS_DIR"

# Quote a value for the Exec/Path keys of a .desktop file
desktop_quote() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//\`/\\\`}"
    s="${s//\$/\\\$}"
    s="${s//%/%%}"
    printf '"%s"' "$s"
}

cat > "$DESKTOP_PATH" <<EOF_DESKTOP
[Desktop Entry]
Name=LS3D WBS LearnSpace Handler
Exec=$(desktop_quote "$LAUNCH_DIR/launch-ls3d.sh") %u
Icon=wine
Type=Application
Terminal=false
MimeType=x-scheme-handler/ls3d;
NoDisplay=true
Path=$LAUNCH_DIR
EOF_DESKTOP

if command_exists update-desktop-database; then
    update-desktop-database "$APPS_DIR" || echo "Warning: update-desktop-database failed."
fi
if command_exists gio; then
    gio mime x-scheme-handler/ls3d ls3d-wbs-handler.desktop || echo "Warning: could not register the ls3d:// handler."
elif command_exists xdg-mime; then
    xdg-mime default ls3d-wbs-handler.desktop x-scheme-handler/ls3d || echo "Warning: could not register the ls3d:// handler."
fi

echo "------------------------------------------------"
echo "DONE! The system is ready."
echo "LearnSpace3D will now start via ls3d:// links."
