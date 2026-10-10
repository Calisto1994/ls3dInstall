#!/bin/bash
set -euo pipefail

echo "WBS LearnSpace 3D - Debian/Ubuntu Uninstaller"
echo "------------------------------------"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed'; }
pkg_remove() { sudo apt-get remove -y "$@"; }

ask_yes_no() {
    local answer=""
    read -r -p "$1" answer || answer=""
    [[ "$answer" =~ ^[JjYy]$ ]]
}

# 1. Define Paths (state written by the installer wins over defaults)
USER_NAME="$(id -un)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ls3d-installer"
DEFAULT_PREFIX="$HOME/.local/share/wineprefixes/ls3d"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_PATH="$APPS_DIR/ls3d-wbs-handler.desktop"

if [ -n "${WINEPREFIX:-}" ]; then
    :
elif [ -s "$STATE_DIR/prefix" ]; then
    WINEPREFIX="$(head -n1 "$STATE_DIR/prefix")"
elif [ ! -d "$DEFAULT_PREFIX" ] && [ -d "$HOME/.wine/drive_c/users/$USER_NAME/AppData/Local/TriCAT/WBS" ]; then
    # Legacy install into the default ~/.wine prefix
    WINEPREFIX="$HOME/.wine"
else
    WINEPREFIX="$DEFAULT_PREFIX"
fi

if [ -s "$STATE_DIR/launch_dir" ]; then
    LAUNCH_DIR="$(head -n1 "$STATE_DIR/launch_dir")"
else
    LAUNCH_DIR="$WINEPREFIX/drive_c/users/$USER_NAME/AppData/Local/TriCAT/WBS"
fi

# 2. Remove Desktop Integration
if [ -f "$DESKTOP_PATH" ]; then
    echo "Removing URI handler desktop file..."
    rm -f "$DESKTOP_PATH"
    if command_exists update-desktop-database; then
        update-desktop-database "$APPS_DIR" || true
    fi
    if [ -f "$HOME/.config/mimeapps.list" ]; then
        sed -i '/ls3d-wbs-handler\.desktop/d' "$HOME/.config/mimeapps.list"
    fi
else
    echo "Desktop file not found. Skipping."
fi

# 3. Remove Launch Script and Application Data
if [ -d "$LAUNCH_DIR" ]; then
    if [[ "$LAUNCH_DIR" != "$WINEPREFIX"/drive_c/* ]]; then
        echo "Refusing to delete $LAUNCH_DIR (not inside the Wine prefix). Skipping."
    elif ask_yes_no "Do you want to delete the LearnSpace3D app data and launch script? [y/N] "; then
        echo "Deleting $LAUNCH_DIR..."
        rm -rf "$LAUNCH_DIR"
    else
        echo "Keeping app data."
    fi
else
    echo "Application data directory not found. Skipping."
fi

# 3b. Optionally remove the whole Wine prefix (incl. DXVK)
# Only prefixes created by this installer are ever deleted.
if [ -d "$WINEPREFIX" ]; then
    if [ "$WINEPREFIX" = "/" ] || [ "$WINEPREFIX" = "$HOME" ] || [ "$WINEPREFIX" = "$HOME/.wine" ]; then
        echo "Refusing to delete $WINEPREFIX (not a dedicated LS3D prefix). Skipping."
    elif [ ! -f "$WINEPREFIX/.ls3d-installer" ] && [ "$WINEPREFIX" != "$DEFAULT_PREFIX" ]; then
        echo "Wine prefix $WINEPREFIX was not created by this installer. Skipping."
    elif ask_yes_no "Do you want to delete the dedicated Wine prefix ($WINEPREFIX)? [y/N] "; then
        echo "Deleting $WINEPREFIX..."
        rm -rf "$WINEPREFIX"
    else
        echo "Keeping Wine prefix."
    fi
else
    echo "Wine prefix not found. Skipping."
fi

# 4. Optional: Remove packages (only those the installer actually installed)
if [ -s "$STATE_DIR/packages" ]; then
    installed_pkgs=()
    while IFS= read -r pkg; do
        if [ -n "$pkg" ] && pkg_installed "$pkg"; then
            installed_pkgs+=("$pkg")
        fi
    done < <(sort -u "$STATE_DIR/packages")
    if [ "${#installed_pkgs[@]}" -gt 0 ]; then
        echo "Packages installed by the LS3D installer: ${installed_pkgs[*]}"
        if ask_yes_no "Do you want to uninstall these packages? [y/N] "; then
            pkg_remove "${installed_pkgs[@]}"
            : > "$STATE_DIR/packages"
        else
            echo "Keeping installed packages."
        fi
    else
        echo "No matching packages installed. Skipping."
    fi
else
    echo "No record of packages installed by the LS3D installer. Keeping all packages."
fi

# 5. Clean up installer state if nothing is left to track
if [ ! -s "$STATE_DIR/packages" ] && [ ! -d "$WINEPREFIX" ]; then
    rm -rf "$STATE_DIR"
fi

echo "------------------------------------"
echo "Uninstallation process finished."
echo "Done."
