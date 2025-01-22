#!/bin/bash

sudo echo Administrative privileges granted.

# Prepare necessary tools for downloading (wget) and running the application (wine) as well as for proper GPU acceleration (winetricks/dxvk)
echo "Preparing prerequisites..."
sudo apt install wget wine winetricks
winetricks dxvk

# Download & install WBS LearnSpace 3D
installURL="http://itsupport.wbstraining.de/tnlogin/Business/Install_LS3D.EXE";
echo "Downloading ${installURL}..."
wget $installURL

wine "./Install_LS3D.EXE";
#####################################

## Prepare "ls3d:" link registration to make LS3D available through the web browser ##
cat <<"EOF" > launch-ls3d.sh
#!/bin/bash

if [[ $1 == *"?backend="* ]]; then
    backendServer=${1:14}
else
    backendServer=${1:5}
fi

zenity --info --text "Starte LearnSpace3D mit ${backendServer}."
wine learnspace3d.exe -backend $backendServer
EOF
chmod +x launch-ls3d.sh

## Prepare: Register URI scheme ##
cat <<EOF > ls3d-handler.desktop
[Desktop Entry]
Name=LS3D
Exec=/home/`whoami`/.wine/drive_c/users/`whoami`/AppData/Local/TriCAT/WBS/launch-ls3d.sh %u
Type=Application
Path=/home/`whoami`/.wine/drive_c/users/`whoami`/AppData/Local/TriCAT/WBS/
MimeType=x-scheme-handler/ls3d;
Hidden=True
EOF
chmod +x ls3d-handler.desktop

## We're done here. Tidy up and move the new configuration
sudo mv "./launch-ls3d.sh" "/home/`whoami`/.wine/drive_c/users/`whoami`/AppData/Local/TriCAT/WBS/launch-ls3d.sh";
sudo mv "./ls3d-handler.desktop" "/usr/share/applications/ls3d-handler.desktop"
rm -f Install_LS3D.EXE
## Load the new configuration ##
sudo update-desktop-database
echo Done.
## Done.
