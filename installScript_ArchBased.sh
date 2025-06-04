#!/bin/bash

# ADDED PRIME-RUN QUESTION AT THE VERY BEGINNING
read -r -p "Do you use prime-run for LearnSpace3D? (Render Offload for NVIDIA Optimus) [y/N] " prime_run_choice_input
prime_run_choice_input=${prime_run_choice_input:-N} # Default is "N" if the user just presses Enter

prime_run_cmd_prefix=""
if [[ "$prime_run_choice_input" =~ ^[Yy]$ ]]; then
    prime_run_cmd_prefix="prime-run " # Trailing space is important
fi

sudo echo "Requesting administrative privileges..."

# Prepare necessary tools for downloading (wget) and running the application (wine) as well as for proper GPU acceleration (winetricks/dxvk)
echo "Preparing prerequisites..."
sudo pacman -S --needed --noconfirm wget wine winetricks zenity
winetricks dxvk

# Download & install WBS LearnSpace 3D
installURL="http://itsupport.wbstraining.de/tnlogin/Business/Install_LS3D.EXE";
echo "Downloading ${installURL}..."
wget $installURL

wine "./Install_LS3D.EXE";
#####################################

## Prepare "ls3d:" link registration to make LS3D available through the web browser ##
# IMPORTANT: The Here-Document delimiter was changed from <<"EOF" to <<EOF,
# so that ${prime_run_cmd_prefix} gets expanded.
# Variables for the inner script (launch-ls3d.sh) must now be escaped (e.g., \$1, \${backendServer}).
cat <<EOF > launch-ls3d.sh
#!/bin/bash

if [[ \$1 == *"?backend="* ]]; then
    backendServer=\${1:14}
else
    backendServer=\${1:5}
fi

zenity --info --text "Starting LearnSpace3D with \${backendServer}."
${prime_run_cmd_prefix}wine learnspace3d.exe -backend \$backendServer
EOF
chmod +x launch-ls3d.sh

## Prepare: Register URI scheme ##
cat <<EOF > ls3d-handler.desktop
[Desktop Entry]
Name=LS3D
Exec=/home/$(whoami)/.wine/drive_c/users/$(whoami)/AppData/Local/TriCAT/WBS/launch-ls3d.sh %u
Type=Application
Path=/home/$(whoami)/.wine/drive_c/users/$(whoami)/AppData/Local/TriCAT/WBS/
MimeType=x-scheme-handler/ls3d;
Hidden=True
EOF
chmod +x ls3d-handler.desktop

## We're done here. Tidy up and move the new configuration
sudo mv "./launch-ls3d.sh" "/home/$(whoami)/.wine/drive_c/users/$(whoami)/AppData/Local/TriCAT/WBS/launch-ls3d.sh";
sudo mv "./ls3d-handler.desktop" "/usr/share/applications/ls3d-handler.desktop"
rm -f Install_LS3D.EXE
## Load the new configuration ##
sudo update-desktop-database
echo "Done."
## Done.
