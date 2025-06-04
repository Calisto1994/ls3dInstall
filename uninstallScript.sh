

#!/bin/bash

# Funktion zur Überprüfung, ob ein Befehl existiert
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Aktuellen Benutzer und dessen Home-Verzeichnis ermitteln
# $HOME sollte für den Benutzer, der das Skript ausführt, korrekt sein.
# $(whoami) gibt den aktuellen Benutzernamen zurück.
CURRENT_USER=$(whoami)
USER_HOME="$HOME"

# Pfade zu den relevanten Dateien und Verzeichnissen
LS3D_APP_DATA_ROOT_PATH="$USER_HOME/.wine/drive_c/users/$CURRENT_USER/AppData/Local/TriCAT"
LS3D_APP_DATA_PATH="$LS3D_APP_DATA_ROOT_PATH/WBS" # WBS ist der spezifische Unterordner
LAUNCH_SCRIPT_PATH="$LS3D_APP_DATA_PATH/launch-ls3d.sh"
UNINSTALL_EXE_PATH="$LS3D_APP_DATA_PATH/Uninstall.exe" # Annahme, dass die Uninstall.exe hier liegt
DESKTOP_FILE_PATH="/usr/share/applications/ls3d-handler.desktop"

echo "WBS LearnSpace 3D Uninstaller"
echo "--------------------------------"

# Administrative Berechtigungen frühzeitig anfordern
sudo echo "Administrative Berechtigungen für einige Operationen erforderlich."

# 1. Den anwendungseigenen Uninstaller ausführen (falls vorhanden)
if [ -f "$UNINSTALL_EXE_PATH" ]; then
    echo "Versuche, den Uninstaller der Anwendung auszuführen: $UNINSTALL_EXE_PATH"
    echo "Bitte folge den Anweisungen des WBS LearnSpace 3D Uninstallers."
    wine "$UNINSTALL_EXE_PATH"
    echo "Anwendungs-Uninstaller beendet."

    # Kurze Pause, damit der Uninstaller der Anwendung Zeit hat, seine Arbeit zu erledigen,
    # bevor wir versuchen, das Verzeichnis zu löschen (optional).
    sleep 2

    # Optional: Versuchen, das WBS-Verzeichnis zu entfernen, falls es nach der Deinstallation leer ist
    # oder wenn der Uninstaller es nicht vollständig entfernt.
    # Vorsicht: Nur löschen, wenn es sicher ist, dass nichts anderes im TriCAT-Ordner benötigt wird,
    # oder spezifischer den WBS-Ordner.
    if [ -d "$LS3D_APP_DATA_PATH" ]; then
        echo "Überprüfe das Anwendungsverzeichnis: $LS3D_APP_DATA_PATH"
        # Wenn der Ordner leer ist, kann er entfernt werden.
        # Für eine aggressivere Reinigung könnte man direkt `rm -rf "$LS3D_APP_DATA_PATH"` in Erwägung ziehen,
        # aber das ist riskant, wenn der Uninstaller nicht alle Dateien entfernt oder wenn der Benutzer dort manuell etwas gespeichert hat.
        # Vorerst belassen wir es dabei, dass der Haupt-Uninstaller der Anwendung dies handhaben sollte.
    fi
else
    echo "WARNUNG: Anwendungs-Uninstaller nicht gefunden unter $UNINSTALL_EXE_PATH."
    echo "Dies könnte bedeuten, dass die Anwendung bereits teilweise deinstalliert wurde oder nicht korrekt installiert war."
    echo "Fahre mit dem Entfernen der benutzerdefinierten Skripte und Desktop-Dateien fort."
fi

# 2. Benutzerdefiniertes Startskript entfernen
# Die Installationsskripte haben sudo verwendet, um diese Datei zu verschieben,
# daher ist sudo hier sicherer, falls die Datei Root gehört.
if [ -f "$LAUNCH_SCRIPT_PATH" ]; then
    echo "Entferne benutzerdefiniertes Startskript: $LAUNCH_SCRIPT_PATH"
    sudo rm -f "$LAUNCH_SCRIPT_PATH"
else
    echo "Benutzerdefiniertes Startskript nicht gefunden (bereits entfernt oder nicht installiert): $LAUNCH_SCRIPT_PATH"
fi

# 3. Desktop-Datei entfernen und Datenbank aktualisieren
if [ -f "$DESKTOP_FILE_PATH" ]; then
    echo "Entferne Desktop-Datei: $DESKTOP_FILE_PATH"
    sudo rm -f "$DESKTOP_FILE_PATH"
    echo "Aktualisiere Desktop-Datenbank..."
    sudo update-desktop-database
else
    echo "Desktop-Datei nicht gefunden (bereits entfernt oder nicht installiert): $DESKTOP_FILE_PATH"
fi

# 4. Anbieten, die installierten Pakete zu entfernen
# Zenity war Teil der Installation in beiden Skripten.
PACKAGES_TO_REMOVE="wget wine winetricks zenity"
echo ""
read -r -p "Möchtest du versuchen, die folgenden Pakete zu entfernen: $PACKAGES_TO_REMOVE? (Diese könnten von anderen Anwendungen verwendet werden) [j/N]: " REMOVE_PACKAGES_CHOICE
REMOVE_PACKAGES_CHOICE=${REMOVE_PACKAGES_CHOICE:-N} # Standard ist Nein

if [[ "$REMOVE_PACKAGES_CHOICE" =~ ^[JjYy]$ ]]; then # Akzeptiert j, J, y, Y
    if command_exists apt-get; then
        echo "Debian-basiertes System erkannt. Verwende apt-get."
        echo "Versuche, Pakete zu entfernen: $PACKAGES_TO_REMOVE"
        sudo apt-get remove $PACKAGES_TO_REMOVE
        echo "Du könntest 'sudo apt autoremove' ausführen, um weitere nicht mehr benötigte Abhängigkeiten zu entfernen."
    elif command_exists pacman; then
        echo "Arch-basiertes System erkannt. Verwende pacman."
        echo "Versuche, Pakete zu entfernen: $PACKAGES_TO_REMOVE"
        # -Rns entfernt das Paket, seine nicht benötigten Abhängigkeiten und Konfigurationsdateien.
        sudo pacman -Rns $PACKAGES_TO_REMOVE
    else
        echo "Konnte keinen unterstützten Paketmanager (apt-get/pacman) finden. Überspringe Paketentfernung."
        echo "Bitte entferne die Pakete ($PACKAGES_TO_REMOVE) manuell, falls gewünscht."
    fi
else
    echo "Überspringe das Entfernen der Pakete: $PACKAGES_TO_REMOVE."
fi

echo ""
echo "Deinstallationsprozess für WBS LearnSpace 3D ist abgeschlossen."
echo "Hinweis: Dieses Skript entfernt nicht das ~/.wine Verzeichnis (dein Wine-Präfix) oder darin installiertes DXVK."
echo "Falls du diese entfernen möchtest, musst du dies manuell tun."
echo "Fertig."
