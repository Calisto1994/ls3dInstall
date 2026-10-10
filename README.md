# WBS LearnSpace 3D Installation (for Linux)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

WBS LearnSpace 3D provides official installers for Windows and macOS, but does not offer a native installer for Linux. This repository provides scripts that make it possible to install and run the Windows version of WBS LearnSpace 3D on Linux using [Wine](https://www.winehq.org/). It also provides a script to remove the application if no longer needed.

## Installation

To install _WBS LearnSpace 3D_ on Linux, give execution permission to the `install.sh` and run it:

```bash
chmod +x install.sh
./install.sh
```

Run it as a normal user (not as root); `sudo` is requested automatically when packages need to be installed.

The script will:
- Install Wine and the other required packages, but only if they are missing (the uninstaller only offers to remove packages the installer installed itself).
- Use a dedicated Wine prefix `~/.local/share/wineprefixes/ls3d` (can be overridden via `WINEPREFIX`).
- Optionally enable NVIDIA Render Offload and a 60 FPS limit via MangoHud.
- Set up a Wine environment with [DXVK](https://github.com/doitsujin/dxvk) for better compatibility with 3D graphics accelerators.
- Download and run the official Windows installer for WBS LearnSpace 3D via [Wget](https://de.wikipedia.org/wiki/Wget).
- Create shortcuts and perform any additional configuration needed to make the application usable on Linux, e.g. register a URI scheme handler so you can launch WBS LearnSpace 3D to a specific server from your browser.

## Uninstallation

To uninstall the software, run:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

The uninstaller removes the URI handler and, after asking, the app data, the Wine prefix and the packages the installer installed itself. Wine prefixes not created by the installer (e.g. `~/.wine`) are never deleted.

The installer and uninstaller will automatically detect your distribution and run the matching script from `Fedora/`, `Debian/`, or `Arch/`.

## Notes

- This setup does **not** provide a native Linux version of WBS LearnSpace 3D; it enables the Windows version to run under Linux via Wine.
- Some features may have minor compatibility issues due to the use of Wine.
- For troubleshooting, consult the Wine documentation or check for updates to this script.
