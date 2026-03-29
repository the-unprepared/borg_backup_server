#!/bin/sh

cat << "EOF"
______                  ______            _                  _____                          
| ___ \                 | ___ \          | |                /  ___|                         
| |_/ / ___  _ __ __ _  | |_/ / __ _  ___| | ___   _ _ __   \ `--.  ___ _ ____   _____ _ __ 
| ___ \/ _ \| '__/ _` | | ___ \/ _` |/ __| |/ / | | | '_ \   `--. \/ _ \ '__\ \ / / _ \ '__|
| |_/ / (_) | | | (_| | | |_/ / (_| | (__|   <| |_| | |_) | /\__/ /  __/ |   \ V /  __/ |   
\____/ \___/|_|  \__, | \____/ \__,_|\___|_|\_\\__,_| .__/  \____/ \___|_|    \_/ \___|_|   
                  __/ |                             | |                                     
                 |___/                              |_|                                     
EOF

echo ''
echo 'Server Start wird durchgeführt.'

# Setze die Zeitzone, falls angegeben
if [ -n "$TIMEZONE" ]; then
    echo "  - Setze die Zeitzone auf $TIMEZONE"
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
fi

# Setze den Repository-Pfad
REPO="/home/borguser/repo"

# Füge die SSH-Schlüssel hinzu, falls die Variable gesetzt wurde (unterstützt mehrzeilige Strings)
if [ -n "$SSH_PUBKEYS" ]; then
    echo "  - SSH-Schlüssel werden konfiguriert."
    mkdir -p /home/borguser/.ssh
    
    # Schreibt alle übergebenen Schlüssel direkt in die Datei (überschreibt alte Einträge sauber)
    echo "$SSH_PUBKEYS" > /home/borguser/.ssh/authorized_keys
    
    chown -R borguser:borguser /home/borguser
    chmod 700 /home/borguser/.ssh
    chmod 600 /home/borguser/.ssh/authorized_keys
fi

# Container SSH Host Keys sichern und wiederherstellen
echo "  - Prüfe SSH Host Keys..."
HOST_KEYS_STORAGE="/home/borguser/.ssh/host_keys"
mkdir -p "$HOST_KEYS_STORAGE"

manage_host_key() {
    KEY_TYPE=$1
    KEY_NAME="ssh_host_${KEY_TYPE}_key"
    STORAGE_PATH="$HOST_KEYS_STORAGE/$KEY_NAME"
    SYSTEM_PATH="/etc/ssh/$KEY_NAME"

    # Wenn Key im Storage nicht existiert, neu erstellen
    if [ ! -f "$STORAGE_PATH" ]; then
        echo "    - Generiere permanenten $KEY_TYPE Key..."
        ssh-keygen -q -t $KEY_TYPE -f "$STORAGE_PATH" -N "" > /dev/null 2>&1
    else
        echo "    - Stelle vorhandenen $KEY_TYPE Key wieder her..."
    fi

    # Key an den System-Ort kopieren
    cp "$STORAGE_PATH" "$SYSTEM_PATH"
    cp "$STORAGE_PATH.pub" "$SYSTEM_PATH.pub"

    # Rechte im System korrigieren (SSHD erwartet root-Besitz)
    chown root:root "$SYSTEM_PATH" "$SYSTEM_PATH.pub"
    chmod 600 "$SYSTEM_PATH"
    chmod 644 "$SYSTEM_PATH.pub"
}

manage_host_key rsa
manage_host_key ed25519

# Rechte für den Storage-Ordner vergeben
chown -R borguser:borguser "$HOST_KEYS_STORAGE"

# Erstelle das Repository-Verzeichnis und setze Berechtigungen
mkdir -p "$REPO"
chown -R borguser:borguser "$REPO"
chmod 700 -R "/home/borguser"

# Prüfe, ob die REPOKEY-Variable gesetzt ist und initialisiere das Repo
if [ -n "$REPOKEY" ]; then
    echo "  - BORG_PASSPHRASE wurde gesetzt."
    export BORG_PASSPHRASE="$REPOKEY"

    # Prüfe, ob das Repository bereits initialisiert wurde
    if ! su - borguser -c "BORG_PASSPHRASE=$REPOKEY borg info \"$REPO\" > /dev/null 2>&1"; then
        echo "    - Repository nicht gefunden. Initialisiere neues Repository."
        # Ausgabe von borg init wird ins Leere umgeleitet, um Logs sauber zu halten
        su - borguser -c "BORG_PASSPHRASE=$REPOKEY borg init --encryption=repokey-blake2 \"$REPO\" > /dev/null 2>&1"
    else
        echo "    - Repository existiert bereits."
    fi
fi

# Richte die optionale Bereinigung (borg prune) ein
if [ -n "$PRUNE_DAYS" ] && [ -n "$PRUNE_TIME" ] && [ -n "$REPOKEY" ]; then
    MINUTE=${PRUNE_TIME#*:}
    HOUR=${PRUNE_TIME%%:*}

    CRON_COMMENT="# Borg Prune Cron-Job"
    PRUNE_COMMAND="BORG_PASSPHRASE=$REPOKEY /usr/bin/borg prune --list --stats --show-rc --keep-daily $PRUNE_DAYS $REPO"
    
    # Cron-Job setzen
    su - borguser -c "(crontab -l 2>/dev/null | grep -v \"$CRON_COMMENT\" ; echo \"$MINUTE $HOUR * * * $PRUNE_COMMAND $CRON_COMMENT\") | crontab - > /dev/null 2>&1"
    
    echo "  - Cron-Job erfolgreich erstellt:"
    echo "    - Bereinigung jeden Tag um $PRUNE_TIME."
    echo "    - Aufbewahrungzeit: $PRUNE_DAYS Tage."

    # Starten des Cron-Daemons
    crond
else
    echo "  - Keine vollständige Bereinigungs-Konfiguration gefunden (PRUNE_DAYS, PRUNE_TIME, REPOKEY). Überspringe Prune-Job."
fi

echo "  - Starte den SSH-Dienst."
echo "Server Start abgeschlossen."
echo ""

# Starte den SSH-Daemon im Vordergrund (exec ersetzt den Shell-Prozess für sauberes Stoppen)
exec /usr/sbin/sshd -D -e
