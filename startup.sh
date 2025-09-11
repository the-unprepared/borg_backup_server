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
    # chown -R borguser:borguser /home/borguser/.ssh
    chmod 700 /home/borguser/.ssh
    chmod 600 /home/borguser/.ssh/authorized_keys
fi


# Erstelle das Repository-Verzeichnis und setze Berechtigungen.
mkdir -p "$REPO"
chown borguser:borguser "$REPO"
chmod 700 -R "$REPO"



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
