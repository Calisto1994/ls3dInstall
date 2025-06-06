# WBS LearnSpace 3D Installation (for Linux)

WBS LearnSpace 3D provides official installers for Windows and macOS, but does not offer a native installer for Linux. This repository provides scripts that make it possible to install and run the Windows version of WBS LearnSpace 3D on Linux using [Wine](https://www.winehq.org/). It also provides a script to remove the application if no longer needed.

## Installation

To install _WBS LearnSpace 3D_ on Linux, give execution permission to the `installScript.sh` and run it:

```bash
chmod +x installScript.sh
./installScript.sh
```

The script will:
- Install Wine if it is not already present.
- Set up a Wine environment with [DXVK](https://github.com/doitsujin/dxvk) for better compatibility with 3D graphics accelerators.
- Download and run the official Windows installer for WBS LearnSpace 3D via [Wget](https://de.wikipedia.org/wiki/Wget).
- Create shortcuts and perform any additional configuration needed to make the application usable on Linux, e.g. register a URI scheme handler so you can launch WBS LearnSpace 3D to a specific server from your browser.

## Uninstallation

To uninstall the software, run:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Notes

- This setup does **not** provide a native Linux version of WBS LearnSpace 3D; it enables the Windows version to run under Linux via Wine.
- Some features may have minor compatibility issues due to the use of Wine.
- For troubleshooting, consult the Wine documentation or check for updates to this script.
