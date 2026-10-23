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
echo "Server Start wird durchgeführt ($(borg --version))."

HOME_DIR="/home/borguser"
REPO="$HOME_DIR/repo"
HOST_KEYS_STORAGE="$HOME_DIR/.ssh/host_keys"
AUTH_KEYS_DIR="/etc/ssh/authorized_keys"
AUTH_KEYS="$AUTH_KEYS_DIR/borguser"
LEGACY_AUTH_KEYS="$HOME_DIR/.ssh/authorized_keys"
PASSPHRASE_FILE="/run/borg/passphrase"

# Gültige Schlüsseltypen in authorized_keys
KEY_TYPES_REGEX='^(ssh-(rsa|dss|ed25519)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh[.]com)$'

# Liefert 0 für true/yes/1/on (Groß-/Kleinschreibung egal)
is_true() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        true|yes|1|on) return 0 ;;
    esac
    return 1
}

# Zerlegt einen Text in einzelne Schlüssel (eine Ausgabezeile pro Schlüssel: "typ blob kommentar").
# Funktioniert mit Zeilenumbrüchen, aber auch wenn YAML mehrere Schlüssel in eine Zeile gefaltet hat.
# Alles vor dem ersten Schlüsseltyp einer Zeile (z. B. ein "|" oder Optionen) wird verworfen.
split_keys() {
    printf '%s\n' "$1" | tr -d '\r' | awk -v re="$KEY_TYPES_REGEX" '
        /^[[:space:]]*#/ { next }
        {
            line = ""
            for (i = 1; i <= NF; i++) {
                if ($i ~ re) { if (line != "") print line; line = $i }
                else if (line != "") line = line " " $i
            }
            if (line != "") print line
        }'
}

# Prüft einen Schlüssel und hängt ihn an die neue authorized_keys an
# $1 = Quelle (für die Ausgabe), $2 = "typ blob kommentar"
add_key() {
    read -r KTYPE KBLOB KCOMMENT << EOK
$2
EOK
    printf '%s %s\n' "$KTYPE" "$KBLOB" > "$AUTH_KEYS.check"
    if ! FP=$(ssh-keygen -l -f "$AUTH_KEYS.check" 2>/dev/null); then
        echo "    - WARNUNG ($1): Ungültiger Schlüssel ignoriert: $KTYPE $(printf '%.20s' "$KBLOB")"
        return
    fi
    if grep -qF "$KTYPE $KBLOB" "$AUTH_KEYS.new"; then
        echo "    - $1: Doppelter Schlüssel ignoriert."
        return
    fi
    echo "${KEY_OPTIONS:+$KEY_OPTIONS }$KTYPE $KBLOB${KCOMMENT:+ $KCOMMENT}" >> "$AUTH_KEYS.new"
    KEY_COUNT=$((KEY_COUNT + 1))
    echo "    - $1: $(echo "$FP" | awk '{print $NF, $2}') ${KCOMMENT}"
}

# Zeitzone setzen (TIMEZONE, alternativ die Standardvariable TZ)
TIMEZONE="${TIMEZONE:-$TZ}"
if [ -n "$TIMEZONE" ]; then
    if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
        echo "  - Setze die Zeitzone auf $TIMEZONE"
        ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
        echo "$TIMEZONE" > /etc/timezone
    else
        echo "  - WARNUNG: Unbekannte Zeitzone '$TIMEZONE', verwende UTC."
    fi
fi

# Verzeichnisse und Berechtigungen (bewusst nicht rekursiv, damit große Repositories schnell starten)
mkdir -p "$REPO" "$HOME_DIR/.ssh" "$HOST_KEYS_STORAGE" "$AUTH_KEYS_DIR"
chown borguser:borguser "$HOME_DIR" "$HOME_DIR/.ssh" "$REPO"
chmod 700 "$HOME_DIR" "$HOME_DIR/.ssh" "$REPO"
if [ -n "$(find "$REPO" ! -user borguser -print 2>/dev/null | head -n 1)" ]; then
    echo "  - Korrigiere Besitzrechte im Repository..."
    chown -R borguser:borguser "$REPO"
fi

# Container SSH Host Keys dauerhaft im Volume speichern (nur für root lesbar)
echo "  - Prüfe SSH Host Keys..."
chown root:root "$HOST_KEYS_STORAGE"
chmod 700 "$HOST_KEYS_STORAGE"

manage_host_key() {
    KEY_TYPE=$1
    KEY_NAME="ssh_host_${KEY_TYPE}_key"
    STORAGE_PATH="$HOST_KEYS_STORAGE/$KEY_NAME"
    SYSTEM_PATH="/etc/ssh/$KEY_NAME"

    # Wenn Key im Storage nicht existiert, neu erstellen
    if [ ! -f "$STORAGE_PATH" ]; then
        echo "    - Generiere permanenten $KEY_TYPE Key..."
        rm -f "$STORAGE_PATH.pub"
        ssh-keygen -q -t "$KEY_TYPE" -f "$STORAGE_PATH" -N "" > /dev/null
    fi

    # Key an den System-Ort kopieren und Rechte setzen (SSHD erwartet root-Besitz)
    cp "$STORAGE_PATH" "$SYSTEM_PATH"
    cp "$STORAGE_PATH.pub" "$SYSTEM_PATH.pub"
    chown root:root "$STORAGE_PATH" "$STORAGE_PATH.pub" "$SYSTEM_PATH" "$SYSTEM_PATH.pub"
    chmod 600 "$STORAGE_PATH" "$SYSTEM_PATH"
    chmod 644 "$STORAGE_PATH.pub" "$SYSTEM_PATH.pub"
    echo "    - $(ssh-keygen -l -f "$SYSTEM_PATH.pub" | awk '{print $NF, $2}')"
}

manage_host_key ed25519
manage_host_key rsa

# SSH-Schlüssel der Clients einrichten
# Quellen: SSH_PUBKEY, SSH_PUBKEY_<Name>, SSH_PUBKEYS und SSH_PUBKEYS_<Name>
echo "  - SSH-Schlüssel werden konfiguriert."
if is_true "${SSH_RESTRICT:-true}"; then
    if is_true "${APPEND_ONLY:-false}"; then
        KEY_OPTIONS="restrict,command=\"borg serve --append-only --restrict-to-repository $REPO\""
        echo "    - Zugriff nur per 'borg serve' auf $REPO (append-only)."
    else
        KEY_OPTIONS="restrict,command=\"borg serve --restrict-to-repository $REPO\""
        echo "    - Zugriff nur per 'borg serve' auf $REPO."
    fi
else
    KEY_OPTIONS=""
    echo "    - WARNUNG: SSH_RESTRICT ist deaktiviert, Clients erhalten eine vollständige Shell."
fi

: > "$AUTH_KEYS.new"
KEY_COUNT=0
KEY_VARS=$(env | sed -n 's/^\(SSH_PUBKEYS\{0,1\}\(_[A-Za-z0-9_]*\)\{0,1\}\)=.*/\1/p' | sort -u)
for VAR in $KEY_VARS; do
    eval "VALUE=\${$VAR}"
    [ -n "$VALUE" ] || continue
    split_keys "$VALUE" > "$AUTH_KEYS.split"
    if [ ! -s "$AUTH_KEYS.split" ]; then
        echo "    - WARNUNG ($VAR): Kein gültiger Schlüssel gefunden."
    fi
    while IFS= read -r KEY; do
        add_key "$VAR" "$KEY"
    done < "$AUTH_KEYS.split"
done

# Ältere Versionen haben die authorized_keys im Volume abgelegt. Sie wird nicht mehr verwendet und
# entfernt, damit dort keine veralteten Schlüssel liegen bleiben.
if [ -f "$LEGACY_AUTH_KEYS" ]; then
    rm -f "$LEGACY_AUTH_KEYS"
    echo "    - Veraltete $LEGACY_AUTH_KEYS entfernt (Schlüssel kommen nur noch aus SSH_PUBKEY*)."
fi

mv "$AUTH_KEYS.new" "$AUTH_KEYS"
rm -f "$AUTH_KEYS.check" "$AUTH_KEYS.split"
chown root:root "$AUTH_KEYS"
chmod 644 "$AUTH_KEYS"
if [ "$KEY_COUNT" -eq 0 ]; then
    echo "    - WARNUNG: Kein SSH-Schlüssel konfiguriert, eine Anmeldung ist nicht möglich!"
fi

# Repository-Passwort (REPOKEY oder als Docker Secret über REPOKEY_FILE)
if [ -z "$REPOKEY" ] && [ -n "$REPOKEY_FILE" ]; then
    if [ -r "$REPOKEY_FILE" ]; then
        REPOKEY=$(cat "$REPOKEY_FILE")
    else
        echo "  - WARNUNG: REPOKEY_FILE '$REPOKEY_FILE' ist nicht lesbar."
    fi
fi

# Die Passphrase nur für root ablegen (wird vom Prune-Job benötigt)
mkdir -p "$(dirname "$PASSPHRASE_FILE")"
chmod 700 "$(dirname "$PASSPHRASE_FILE")"
rm -f "$PASSPHRASE_FILE"
if [ -n "$REPOKEY" ]; then
    (umask 077; printf '%s' "$REPOKEY" > "$PASSPHRASE_FILE")
fi

# Repository prüfen bzw. initialisieren
if [ -f "$REPO/config" ]; then
    echo "  - Repository existiert bereits."
    if [ -n "$REPOKEY" ] && ! BORG_PASSPHRASE="$REPOKEY" REPO="$REPO" \
        su borguser -s /bin/sh -c 'borg list --lock-wait 10 --last 1 --short "$REPO"' > /dev/null 2>&1; then
        echo "    - WARNUNG: Repository konnte mit REPOKEY nicht geöffnet werden (falsches Passwort oder gesperrt)."
    fi
elif [ -n "$REPOKEY" ]; then
    echo "  - Repository nicht gefunden. Initialisiere neues Repository (repokey-blake2)."
    if INIT_LOG=$(BORG_PASSPHRASE="$REPOKEY" REPO="$REPO" \
        su borguser -s /bin/sh -c 'borg init --encryption=repokey-blake2 "$REPO"' 2>&1); then
        echo "    - Repository erstellt. Exportiere den Schlüssel und bewahre ihn sicher auf:"
        echo "      borg key export ssh://borguser@<HOST>:<PORT>$REPO borg-key.txt"
    else
        echo "    - FEHLER: Initialisierung fehlgeschlagen:"
        echo "$INIT_LOG"
    fi
else
    echo "  - Kein Repository vorhanden und kein REPOKEY gesetzt."
    echo "    - Initialisiere es vom Client aus mit: borg init --encryption=repokey-blake2 ssh://borguser@<HOST>:<PORT>$REPO"
fi

# Richte die optionale Bereinigung (borg prune + compact) ein
if [ -n "$PRUNE_DAYS" ] || [ -n "$PRUNE_TIME" ]; then
    PRUNE_OK=1
    case "$PRUNE_DAYS" in
        ''|*[!0-9]*|0) echo "  - WARNUNG: PRUNE_DAYS muss eine Zahl größer 0 sein."; PRUNE_OK=0 ;;
    esac
    case "$PRUNE_TIME" in
        [0-9]:[0-5][0-9]|[01][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9]) ;;
        *) echo "  - WARNUNG: PRUNE_TIME muss das Format HH:MM haben (z. B. 03:00)."; PRUNE_OK=0 ;;
    esac
    if [ -z "$REPOKEY" ]; then
        echo "  - WARNUNG: Für die Bereinigung wird REPOKEY benötigt."
        PRUNE_OK=0
    fi

    if [ "$PRUNE_OK" -eq 1 ]; then
        MINUTE=${PRUNE_TIME#*:}
        HOUR=${PRUNE_TIME%%:*}
        # Ausgabe landet über PID 1 im Docker-Log
        echo "$MINUTE $HOUR * * * root /usr/local/bin/borg-prune.sh $PRUNE_DAYS > /proc/1/fd/1 2>&1" > /etc/cron.d/borg-prune
        chmod 644 /etc/cron.d/borg-prune
        crond

        echo "  - Cron-Job erfolgreich erstellt:"
        echo "    - Bereinigung jeden Tag um $PRUNE_TIME (borg prune --keep-daily $PRUNE_DAYS + borg compact)."
    else
        echo "  - Überspringe Prune-Job."
    fi
else
    echo "  - Keine Bereinigung konfiguriert (PRUNE_DAYS, PRUNE_TIME)."
fi

echo "  - Starte den SSH-Dienst."
echo "Server Start abgeschlossen."
echo ""

# Geheimnisse nicht an sshd vererben
unset REPOKEY

# Starte den SSH-Daemon im Vordergrund (exec ersetzt den Shell-Prozess für sauberes Stoppen)
exec /usr/sbin/sshd -D -e
