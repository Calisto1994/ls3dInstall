#!/bin/bash

set -euo pipefail

echo "WBS LearnSpace 3D - Universal Uninstaller"
echo "----------------------------------------"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_uninstaller() {
    local uninstaller_path="$1"

    if [ ! -f "$uninstaller_path" ]; then
        echo "Error: Uninstaller not found at $uninstaller_path"
        exit 1
    fi

    echo "Starting uninstaller: $uninstaller_path"
    bash "$uninstaller_path"
}

if command_exists dnf; then
    run_uninstaller "$(dirname "$0")/Fedora/uninstall.sh"
elif command_exists apt-get; then
    run_uninstaller "$(dirname "$0")/Debian/uninstall.sh"
elif command_exists pacman; then
    run_uninstaller "$(dirname "$0")/Arch/uninstall.sh"
else
    echo "Error: Unsupported distribution (no dnf/apt-get/pacman found)."
    echo "Supported: Fedora (dnf), Debian/Ubuntu/Linux Mint (apt-get), Arch (pacman)."
    exit 1
fi
