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







# Füge den SSH-Schlüssel hinzu, falls er als Umgebungsvariable gesetzt wurde
if [ -n "$SSH_PUBKEY" ]; then
    echo "  - SSH-Schlüssel wurden gesetzt."
    mkdir -p /home/borguser/.ssh
    
    # Datei löschen, damit alte Schlüssel entfernt werden
    echo "" > /home/borguser/.ssh/authorized_keys

    # Fügen Sie die Schlüssel hinzu, wenn die Umgebungsvariablen gesetzt sind
    if [ -n "$SSH_PUBKEY" ]; then
        echo "$SSH_PUBKEY" >> /home/borguser/.ssh/authorized_keys
    fi

    if [ -n "$SSH_PUBKEY_2" ]; then
        echo "$SSH_PUBKEY_2" >> /home/borguser/.ssh/authorized_keys
    fi

    if [ -n "$SSH_PUBKEY_3" ]; then
        echo "$SSH_PUBKEY_3" >> /home/borguser/.ssh/authorized_keys
    fi

    if [ -n "$SSH_PUBKEY_4" ]; then
        echo "$SSH_PUBKEY_4" >> /home/borguser/.ssh/authorized_keys
    fi

    if [ -n "$SSH_PUBKEY_5" ]; then
        echo "$SSH_PUBKEY_5" >> /home/borguser/.ssh/authorized_keys
    fi
    
    chown -R borguser:borguser /home/borguser
    chmod 700 /home/borguser/.ssh
    chmod 600 /home/borguser/.ssh/authorized_keys
fi



# Contaiern SSH Schlüssel sichern
echo "  - Prüfe SSH Host Keys..."
# Wird in .ssh gesichert (host_keys)
HOST_KEYS_STORAGE="/home/borguser/.ssh/host_keys"
mkdir -p "$HOST_KEYS_STORAGE"

# Funktion, um Keys zu verwalten
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

    # 2. Key an den System-Ort kopieren (SSHD erwartet sie in /etc/ssh)
    cp "$STORAGE_PATH" "$SYSTEM_PATH"
    cp "$STORAGE_PATH.pub" "$SYSTEM_PATH.pub"

    # 3. Rechte im System korrigieren (Muss root gehören für SSHD!)
    chown root:root "$SYSTEM_PATH" "$SYSTEM_PATH.pub"
    chmod 600 "$SYSTEM_PATH"
    chmod 644 "$SYSTEM_PATH.pub"
}

manage_host_key rsa
manage_host_key ed25519

# Rechte vergeben
chown -R borguser:borguser "$HOST_KEYS_STORAGE"



# Erstelle das Repository-Verzeichnis und setze Berechtigungen.
mkdir -p "$REPO"
chown borguser:borguser "$REPO"
chmod 700 -R "/home/borguser"



# Prüfe, ob die REPOKEY-Variable gesetzt ist und initialisiere das Repo.
if [ -n "$REPOKEY" ]; then
    echo "  - BORG_PASSPHRASE wurde gesetzt."
    echo "    - Initialisiere das Repository."
    export BORG_PASSPHRASE="$REPOKEY"

    # Prüfe, ob das Repository bereits initialisiert wurde.
    if ! su - borguser -c "BORG_PASSPHRASE=$REPOKEY borg info \"$REPO\" > /dev/null 2>&1"; then
        echo "    - Repository nicht gefunden. Initialisiere neues Repository."
        su - borguser -c "BORG_PASSPHRASE=$REPOKEY borg init --encryption=repokey-blake2 \"$REPO\""
    else
        echo "    - Repository existiert bereits."
    fi
fi



# Richte die optionale Bereinigung (borg prune) ein
if [ -n "$PRUNE_DAYS" ] && [ -n "$PRUNE_TIME" ] && [ -n "$REPOKEY" ]; then
    MINUTE=${PRUNE_TIME#*:}
    HOUR=${PRUNE_TIME%%:*}

    # Definiere einen eindeutigen Kommentar für den Cron-Job, um ihn später zu finden.
    CRON_COMMENT="# Borg Prune Cron-Job"

    # Erstelle den vollständigen Borg-Prune-Befehl als String.
    PRUNE_COMMAND="BORG_PASSPHRASE=$REPOKEY /usr/bin/borg prune --list --stats --show-rc --keep-daily $PRUNE_DAYS $REPO"
    
    # Setzt den Cron-Job und entfernt den vorhandenen.
    su - borguser -c "(crontab -l 2>/dev/null | grep -v \"$CRON_COMMENT\" ; echo \"$MINUTE $HOUR * * * $PRUNE_COMMAND $CRON_COMMENT\") | crontab -" 2>/dev/null
    
    echo "  - Cron-Job erfolgreich erstellt:"
    echo "    - Bereinigung jeden Tag um $PRUNE_TIME."
    echo "    - Aufbewahrungzeit: $PRUNE_DAYS Tage."

    # Starten des Cron-Daemons
    crond
else
    echo "  - REPOKEY, PRUNE_DAYS oder PRUNE_TIME ist nicht gesetzt. Keine Bereinigung konfiguriert."
fi



echo "  - Starte den SSH-Dienst."
echo "Server Start abgeschlossen."
echo ""
# Starte den SSH-Daemon im Vordergrund, damit der Container nicht beendet wird.
exec /usr/sbin/sshd -D -e
