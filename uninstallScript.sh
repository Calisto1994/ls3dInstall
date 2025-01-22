#!/bin/bash

sudo echo Administrative privileges granted.

# Prepare necessary tools for downloading (wget) and running the application (wine) as well as for proper GPU acceleration (winetricks/dxvk)
echo "Preparing prerequisites..."
sudo apt install wget wine winetricks
winetricks dxvk

sudo rm -f /home/`whoami`/.wine/drive_c/users/`whoami`/AppData/Local/TriCAT/WBS/launch-ls3d.sh
sudo rm -f /usr/share/applications/ls3d-handler.desktop
wine /home/`whoami`/.wine/drive_c/users/`whoami`/AppData/Local/TriCAT/WBS/Uninstall.exe

## Load the new configuration ##
sudo update-desktop-database


## We're done here. Tidy up.
rm -f Install_LS3D.EXE
echo Done.
