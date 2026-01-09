#!/bin/bash

set -euo pipefail

echo "WBS LearnSpace 3D - Universal Installer"
echo "-------------------------------------"

if [ ! -f /etc/os-release ]; then
    echo "Error: /etc/os-release not found. Cannot detect distribution."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

id_lower=${ID,,}
id_like_lower=${ID_LIKE,,}

run_installer() {
    local installer_path="$1"

    if [ ! -f "$installer_path" ]; then
        echo "Error: Installer not found at $installer_path"
        exit 1
    fi

    echo "Starting installer: $installer_path"
    bash "$installer_path"
}

if [[ "$id_lower" == "fedora" || "$id_like_lower" == *"fedora"* ]]; then
    run_installer "$(dirname "$0")/Fedora/install.sh"
elif [[ "$id_lower" == "debian" || "$id_lower" == "ubuntu" || "$id_lower" == "linuxmint" || "$id_like_lower" == *"debian"* || "$id_like_lower" == *"ubuntu"* ]]; then
    run_installer "$(dirname "$0")/Debian/install.sh"
elif [[ "$id_lower" == "arch" || "$id_like_lower" == *"arch"* ]]; then
    run_installer "$(dirname "$0")/Arch/install.sh"
else
    echo "Error: Unsupported distribution (ID=$ID, ID_LIKE=$ID_LIKE)."
    echo "Supported: Fedora, Debian/Ubuntu/Linux Mint, Arch-based."
    exit 1
fi
