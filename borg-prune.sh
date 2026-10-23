#!/bin/sh

# Bereinigt das Repository (borg prune + borg compact).
# Wird von cron als root aufgerufen, borg selbst läuft als borguser.
# Aufruf: borg-prune.sh <Anzahl Tage>

REPO="/home/borguser/repo"
PASSPHRASE_FILE="/run/borg/passphrase"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starte Bereinigung (keep-daily $1)."

if [ ! -r "$PASSPHRASE_FILE" ]; then
    echo "  - Fehler: $PASSPHRASE_FILE nicht gefunden. Abbruch."
    exit 1
fi

# Die Passphrase wird per Umgebung übergeben und taucht so nicht in der Prozessliste auf
BORG_PASSPHRASE="$(cat "$PASSPHRASE_FILE")" PRUNE_DAYS="$1" REPO="$REPO" \
    su borguser -s /bin/sh -c '
        borg prune --lock-wait 600 --list --stats --show-rc --keep-daily "$PRUNE_DAYS" "$REPO" &&
        borg compact --lock-wait 600 --show-rc "$REPO"
    '
RC=$?

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bereinigung beendet (Rückgabewert $RC)."
exit $RC
