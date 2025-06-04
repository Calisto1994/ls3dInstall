#!/bin/bash

echo "WBS LearnSpace 3D Universal Installer"
echo "-------------------------------------"

# Funktion zur Überprüfung, ob ein Befehl existiert
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Sudo-Zeitstempel frühzeitig aktualisieren und am Leben erhalten
echo "Administrative Berechtigungen werden für die Installation benötigt..."
if sudo -v; then
    # Halte die Sudo-Sitzung am Leben, während das Skript läuft
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )
    SUDO_KEEPALIVE_PID=$!
    trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT
else
    echo "Fehler: Konnte keine administrativen Berechtigungen erhalten. Abbruch."
    exit 1
fi

# --- prime-run Erkennung und Abfrage ---
prime_run_cmd_prefix=""
if command_exists "prime-run"; then
    read -r -p "prime-run erkannt. Möchtest du es für LearnSpace3D verwenden? (Render Offload für NVIDIA Optimus) [j/N] " prime_run_choice_input
    prime_run_choice_input=${prime_run_choice_input:-N} # Standard ist Nein
    if [[ "$prime_run_choice_input" =~ ^[JjYy]$ ]]; then # Akzeptiert j, J, y, Y
        prime_run_cmd_prefix="prime-run "
        echo "prime-run wird verwendet."
    else
        echo "prime-run wird nicht verwendet."
    fi
else
    echo "prime-run nicht erkannt. Überspringe prime-run Konfiguration."
fi

# --- Paketmanager-Erkennung und Installation der Abhängigkeiten ---
echo "Bereite Abhängigkeiten vor..."
PACKAGES="wget wine winetricks zenity" # zenity für die Benachrichtigungen im Startskript

if command_exists apt-get; then
    echo "Debian-basiertes System erkannt. Verwende apt-get."
    sudo apt-get update
    sudo apt-get install -y $PACKAGES
elif command_exists pacman; then
    echo "Arch-basiertes System erkannt. Verwende pacman."
    sudo pacman -S --needed --noconfirm $PACKAGES
else
    echo "FEHLER: Weder apt-get noch pacman gefunden. Abhängigkeiten können nicht installiert werden."
    echo "Bitte installiere die folgenden Pakete manuell: $PACKAGES"
    # Beende das Sudo-Keepalive, bevor das Skript beendet wird
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then kill $SUDO_KEEPALIVE_PID 2>/dev/null; fi
    trap - EXIT # Entferne den Trap
    exit 1
fi

# DXVK mit Winetricks konfigurieren (gemeinsamer Schritt)
echo "Konfiguriere DXVK mit winetricks..."
winetricks dxvk

# --- Download & Installation WBS LearnSpace 3D ---
installURL="http://itsupport.wbstraining.de/tnlogin/Business/Install_LS3D.EXE"
INSTALLER_FILENAME="Install_LS3D.EXE"
echo "Lade ${installURL} herunter..."
wget -O "$INSTALLER_FILENAME" "$installURL"

if [ -f "$INSTALLER_FILENAME" ]; then
    echo "Starte WBS LearnSpace 3D Installer mit Wine..."
    wine "./$INSTALLER_FILENAME"
    echo "WBS LearnSpace 3D Installation abgeschlossen (durch den Anwendungsinstaller)."
else
    echo "FEHLER: Download von $INSTALLER_FILENAME fehlgeschlagen."
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then kill $SUDO_KEEPALIVE_PID 2>/dev/null; fi
    trap - EXIT
    exit 1
fi

# --- Erstelle launch-ls3d.sh Startskript ---
echo "Erstelle Startskript (launch-ls3d.sh)..."
# $USER sollte den aktuell angemeldeten Benutzer korrekt wiedergeben.
# Der Pfad innerhalb von Wine verwendet typischerweise den Linux-Benutzernamen.
LS3D_LAUNCH_SCRIPT_DIR_LINUX="$HOME/.wine/drive_c/users/$USER/AppData/Local/TriCAT/WBS"

# Stelle sicher, dass das Zielverzeichnis für launch-ls3d.sh existiert
mkdir -p "$LS3D_LAUNCH_SCRIPT_DIR_LINUX"

# Der Inhalt von launch-ls3d.sh. ${prime_run_cmd_prefix} wird vom äußeren Skript expandiert.
# Variablen wie \$1 und \${backendServer} sind für das innere Skript und müssen escaped werden.
cat <<EOF > "$LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh"
#!/bin/bash
URI="\$1"
# Standard-Prime-Run-Präfix (wird durch äußeres Skript ersetzt, falls dort definiert)
prime_prefix_placeholder="${prime_run_cmd_prefix}"

if [[ "\$URI" == *"?backend="* ]]; then
    # Extrahiere den Wert des 'backend' Query-Parameters
    backendServer=\$(echo "\$URI" | sed -n 's/.*[?&]backend=\([^&]*\).*/\1/p')
else
    # Nehme an, URI ist ls3d:backendServer oder ls3d://backendServer
    backendServer=\${URI#ls3d:}
    backendServer=\${backendServer##//} # Entferne führende //
fi

# Bereinige mögliche nachgestellte Schrägstriche
backendServer=\$(echo "\$backendServer" | sed 's:/*\$::')

if [ -z "\$backendServer" ]; then
    zenity --error --text="Konnte Backend-Server nicht aus URI bestimmen: \$URI" --title="LearnSpace3D Fehler"
    exit 1
fi

zenity --info --text="Starte LearnSpace3D mit Backend: \${backendServer}." --title="LearnSpace3D"
# Der 'Path' im .desktop File setzt das Arbeitsverzeichnis, learnspace3d.exe sollte dort sein.
\${prime_prefix_placeholder}wine learnspace3d.exe -backend "\$backendServer"
EOF
chmod +x "$LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh"
echo "Startskript erstellt unter $LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh"

# --- Erstelle ls3d-handler.desktop Datei ---
echo "Erstelle ls3d URI Handler Desktop-Datei..."
DESKTOP_FILE_NAME="ls3d-wbs-handler.desktop"
DESKTOP_FILE_PATH="/usr/share/applications/$DESKTOP_FILE_NAME"

# Inhalt der .desktop Datei
# Das Arbeitsverzeichnis (Path) ist wichtig, damit wine die learnspace3d.exe findet.
DESKTOP_FILE_CONTENT="[Desktop Entry]
Name=LS3D WBS LearnSpace Handler
Comment=Handles ls3d:// URI scheme for WBS LearnSpace 3D
Exec=$LS3D_LAUNCH_SCRIPT_DIR_LINUX/launch-ls3d.sh %u
Icon=wine
Type=Application
Terminal=false
MimeType=x-scheme-handler/ls3d;
NoDisplay=true
Path=$LS3D_LAUNCH_SCRIPT_DIR_LINUX
"

# Schreibe die .desktop-Datei mit sudo, da sie in /usr/share/applications liegt
echo "$DESKTOP_FILE_CONTENT" | sudo tee "$DESKTOP_FILE_PATH" > /dev/null
# chmod +x ist für .desktop-Dateien nicht zwingend erforderlich, schadet aber nicht.
sudo chmod 644 "$DESKTOP_FILE_PATH" # Korrekte Berechtigungen für .desktop-Dateien
echo "Desktop-Datei erstellt unter $DESKTOP_FILE_PATH"

# --- Abschließende Schritte ---
echo "Aktualisiere Desktop-Datenbank..."
sudo update-desktop-database

echo "Räume heruntergeladenen Installer auf..."
rm -f "$INSTALLER_FILENAME"

# Beende das Sudo-Keepalive
if [ -n "$SUDO_KEEPALIVE_PID" ]; then kill $SUDO_KEEPALIVE_PID 2>/dev/null; fi
trap - EXIT # Entferne den Trap am Ende des erfolgreichen Laufs

echo ""
echo "Installation von WBS LearnSpace 3D sollte abgeschlossen sein."
echo "Du kannst nun versuchen, einen ls3d:// Link zu öffnen."
echo "Fertig."
