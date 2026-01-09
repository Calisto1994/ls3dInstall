#!/bin/bash

set -euo pipefail

echo "WBS LearnSpace 3D - Universal Installer"
echo "-------------------------------------"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_installer() {
    local installer_path="$1"

    if [ ! -f "$installer_path" ]; then
        echo "Error: Installer not found at $installer_path"
        exit 1
    fi

    echo "Starting installer: $installer_path"
    bash "$installer_path"
}

if command_exists dnf; then
    run_installer "$(dirname "$0")/Fedora/install.sh"
elif command_exists apt-get; then
    run_installer "$(dirname "$0")/Debian/install.sh"
elif command_exists pacman; then
    run_installer "$(dirname "$0")/Arch/install.sh"
else
    echo "Error: Unsupported distribution (no dnf/apt-get/pacman found)."
    echo "Supported: Fedora (dnf), Debian/Ubuntu/Linux Mint (apt-get), Arch (pacman)."
    exit 1
fi
