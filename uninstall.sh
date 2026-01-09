#!/bin/bash

set -euo pipefail

echo "WBS LearnSpace 3D - Universal Uninstaller"
echo "----------------------------------------"

if [ ! -f /etc/os-release ]; then
    echo "Error: /etc/os-release not found. Cannot detect distribution."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

id_lower=${ID,,}
id_like_lower=${ID_LIKE,,}

run_uninstaller() {
    local uninstaller_path="$1"

    if [ ! -f "$uninstaller_path" ]; then
        echo "Error: Uninstaller not found at $uninstaller_path"
        exit 1
    fi

    echo "Starting uninstaller: $uninstaller_path"
    bash "$uninstaller_path"
}

if [[ "$id_lower" == "fedora" || "$id_like_lower" == *"fedora"* ]]; then
    run_uninstaller "$(dirname "$0")/Fedora/uninstall.sh"
elif [[ "$id_lower" == "debian" || "$id_lower" == "ubuntu" || "$id_lower" == "linuxmint" || "$id_like_lower" == *"debian"* || "$id_like_lower" == *"ubuntu"* ]]; then
    run_uninstaller "$(dirname "$0")/Debian/uninstall.sh"
elif [[ "$id_lower" == "arch" || "$id_like_lower" == *"arch"* ]]; then
    run_uninstaller "$(dirname "$0")/Arch/uninstall.sh"
else
    echo "Error: Unsupported distribution (ID=$ID, ID_LIKE=$ID_LIKE)."
    echo "Supported: Fedora, Debian/Ubuntu/Linux Mint, Arch-based."
    exit 1
fi
