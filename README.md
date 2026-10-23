# 🛡️ Borg Backup Server

Ein minimalistischer und effizienter Backup-Server zum einfachen Speichern deiner [Borg Backup](https://www.borgbackup.org/) Archive über SSH.
Besonders gut geeignet für NAS-Systeme mit Docker-Unterstützung. Dieser Server ist ausschließlich für die Nutzung mit der Borg Backup Software konzipiert.

[![Docker Hub](https://img.shields.io/badge/Docker_Hub-unprepared%2Fborg__backup__server-blue?logo=docker)](https://hub.docker.com/r/unprepared/borg_backup_server)

---

![Borg Backup Server Logo](logo.jpg)

> ⚠️ **Wichtiger Hinweis:**
> Dies ist ein privates Hobby-Projekt! Es wird keine Haftung für Datenverlust übernommen und es gibt keine Garantie auf Funktion. Nutzung auf eigene Gefahr. Teste deine Backups und Restores regelmäßig!

---

## 🚀 Quick Start (Docker Compose)

Hier ist ein Beispiel, wie du den Server schnell und einfach mit `docker compose` starten kannst.

**SSH-Schlüssel:** Jeder Rechner, der auf das Backup zugreifen darf, bekommt eine eigene Variable `SSH_PUBKEY_<NAME>` mit genau einem Schlüssel in einer Zeile. Den Namen hinter `SSH_PUBKEY_` kannst du frei wählen (z. B. `SSH_PUBKEY_1`, `SSH_PUBKEY_2` oder `SSH_PUBKEY_LAPTOP`). Das ist besonders praktisch, wenn du nicht nur vom Haupt-Rechner sichern möchtest, sondern später vielleicht von einem anderen Rechner (z. B. deinem Laptop) auf das Backup-Archiv zugreifen musst, um Dateien wiederherzustellen. Die Schreibweise funktioniert auch in NAS-Oberflächen (Synology, Unraid, Portainer, …), die nur einzeilige Werte erlauben.

```yaml
services:
  bbs:
    image: unprepared/borg_backup_server:latest
    container_name: borg_backup_server
    ports:
      - "2222:22"
    environment:
      - TIMEZONE=Europe/Berlin
      - REPOKEY=DeinGeheimerRepoSchlüssel
      - PRUNE_DAYS=14
      - PRUNE_TIME=03:00
      - SSH_PUBKEY_DESKTOP=ssh-ed25519 AAAAC3Nz... rechner1@backup
      - SSH_PUBKEY_LAPTOP=ssh-ed25519 AAAAC3Nz... rechner2@restore
    volumes:
      - bbs_volumen:/home/borguser
    restart: unless-stopped

volumes:
  bbs_volumen:
```

Beim Start zeigt das Log (`docker logs borg_backup_server`) für jeden Schlüssel den Fingerprint an. Ungültige oder abgeschnittene Schlüssel werden mit einer Warnung übersprungen.

---

## ⚙️ Umgebungsvariablen (Environment)

| Variable | Status | Beschreibung |
| --- | --- | --- |
| `SSH_PUBKEY_<NAME>` | **Erforderlich** (mind. ein Schlüssel) | Ein Public Key pro Variable, z. B. `SSH_PUBKEY_1`, `SSH_PUBKEY_LAPTOP`. Beliebig viele möglich. Der Name darf nur Buchstaben, Ziffern und `_` enthalten, also `SSH_PUBKEY_DOCKER_SERVER` statt `SSH_PUBKEY_DOCKER-SERVER`. |
| `SSH_PUBKEYS` | Optional | Ältere Variante: mehrere Keys in einer Variable. Funktioniert weiterhin (auch versehentlich in eine Zeile zusammengefaltete Keys werden erkannt), siehe [Mehrere Keys in einer Variable](#mehrere-keys-in-einer-variable). |
| `REPOKEY` | Optional | Das Passwort, mit dem das Repository verschlüsselt wird (`repokey-blake2`). Ist dies gesetzt, wird das Repo beim ersten Start automatisch angelegt. Ohne diesen Key musst du das Repo selbst vom Client aus initialisieren (`borg init`). _Hinweis: Der Key steht im Klartext in der Compose-Datei und ist per `docker inspect` sichtbar. Nur auf eigener, sicherer Hardware setzen oder `REPOKEY_FILE` verwenden._ |
| `REPOKEY_FILE` | Optional | Pfad zu einer Datei mit dem Passwort, z. B. ein [Docker Secret](https://docs.docker.com/compose/how-tos/use-secrets/) (`/run/secrets/repokey`). Wird verwendet, wenn `REPOKEY` nicht gesetzt ist. |
| `TIMEZONE` | Optional | Die Zeitzone (z. B. `Europe/Berlin`), die für die korrekte Ausführung des Prune-Jobs wichtig ist. Alternativ wird auch `TZ` ausgewertet. Eine vollständige Liste findest du in der [Wikipedia-Liste der tz-Datenbank](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). Standard: UTC. |
| `PRUNE_DAYS` | Optional | Anzahl der Tage, für die jeweils das letzte Backup des Tages behalten wird (`borg prune --keep-daily`). Danach gibt `borg compact` den Speicher frei. Erfordert `PRUNE_TIME` und `REPOKEY`. |
| `PRUNE_TIME` | Optional | Die Uhrzeit im Format `HH:MM` (z. B. `03:00`), zu der die automatische Bereinigung ausgeführt wird. Die Ausgabe erscheint im Docker-Log. |
| `APPEND_ONLY` | Optional | `true` schaltet den [Append-only-Modus](https://borgbackup.readthedocs.io/en/stable/usage/notes.html#append-only-mode-forbid-compaction) für alle Clients ein: Clients können Backups anlegen, aber nichts endgültig löschen (Schutz vor Ransomware). Die Bereinigung über `PRUNE_DAYS` läuft trotzdem. Standard: `false`. |
| `SSH_RESTRICT` | Optional | Standard `true`: Clients dürfen per SSH ausschließlich `borg serve` auf `/home/borguser/repo` ausführen, keine Shell, kein Port-Forwarding. `false` erlaubt eine normale Shell (nicht empfohlen). |

### Was bedeutet `PRUNE_DAYS` genau?

`--keep-daily 14` behält **pro Tag das letzte Archiv** für die letzten 14 Tage, _an denen es Backups gab_. Das ist nicht dasselbe wie „alles löschen, was älter als 14 Tage ist“:

- Mehrere Backups am selben Tag werden auf eines reduziert.
- Fallen Backups eine Zeit lang aus, bleiben entsprechend ältere Archive erhalten.
- Die Bereinigung wirkt auf **alle Archive im Repository gemeinsam**. Sichern mehrere Rechner in dasselbe Repository, bleibt pro Tag nur das letzte Archiv _eines_ Rechners übrig. Lass in diesem Fall `PRUNE_DAYS` weg und führe `borg prune` auf jedem Client mit `--glob-archives 'Rechner_Name--*'` aus, oder betreibe pro Rechner einen eigenen Container.

### Mehrere Keys in einer Variable

Die alte Schreibweise mit `SSH_PUBKEYS` funktioniert weiterhin. Ein mehrzeiliger Wert (`|`) ist in YAML aber **nur in der Mapping-Schreibweise** möglich (`KEY: wert` statt `- KEY=wert`):

```yaml
    environment:
      SSH_PUBKEYS: |
        ssh-ed25519 AAAAC3Nz... rechner1@backup
        ssh-ed25519 AAAAC3Nz... rechner2@restore
```

In der Listen-Schreibweise (`- SSH_PUBKEYS=|`) macht YAML aus allen Zeilen eine einzige Zeile mit einem `|` am Anfang. Ältere Versionen dieses Images konnten das nicht verarbeiten, die aktuelle Version trennt solche Zeilen wieder in einzelne Keys auf. Empfohlen ist trotzdem `SSH_PUBKEY_<NAME>`.

---

## 🔐 Sicherheit

- **Nur Borg:** Jeder Schlüssel ist auf `borg serve --restrict-to-repository /home/borguser/repo` beschränkt. Ein gestohlener Client-Schlüssel erlaubt keine Shell auf dem Server, aber (ohne `APPEND_ONLY`) das Löschen von Backups.
- **Append-only und Bereinigung:** Im Append-only-Modus kann ein Client Archive zwar scheinbar löschen, die Daten bleiben aber erhalten, bis auf dem Server `borg compact` läuft. Das passiert bei gesetztem `PRUNE_DAYS` jede Nacht. Für maximalen Schutz `PRUNE_*` weglassen und Bereinigungen manuell nach einer Kontrolle durchführen.
- **Keys kommen nur aus der Konfiguration:** Die `authorized_keys` wird bei jedem Start ausschließlich aus den `SSH_PUBKEY*`-Variablen neu erzeugt. Entfernst du eine Variable und erstellst den Container neu (`docker compose up -d`), ist der Zugriff für diesen Schlüssel sofort weg. Ist keine Variable gesetzt, ist keine Anmeldung möglich.
- **Host-Key prüfen:** Beim Start werden die Fingerprints der SSH-Host-Keys im Log ausgegeben. Vergleiche sie bei der ersten Verbindung mit der Anzeige deines Clients. Die Host-Keys liegen dauerhaft im Volume, damit sich der Fingerprint bei Updates nicht ändert.
- **Repository-Schlüssel sichern:** Bei `repokey` liegt der Schlüssel im Repository. Ist das Repository beschädigt, sind ohne Schlüssel-Backup alle Daten verloren. Exportiere ihn einmalig und bewahre ihn getrennt vom Server auf:

  ```sh
  borg key export ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo borg-key.txt
  ```

---

## 📦 Kompatibilität

Das Image enthält **Borg 1.4** (die genaue Version steht beim Start im Log). Auf den Clients muss ebenfalls Borg 1.x (1.2 oder neuer empfohlen) installiert sein. Borg 2.x ist zu Borg 1.x nicht kompatibel.

---

## 📜 Beispiel: Backup-Skript für den Client

So könnte ein einfaches Shell-Skript auf deinem Rechner aussehen, das die Daten auf diesen Container sichert. Passe die IP und den Port entsprechend an.

Verbinde dich vorher **einmal manuell** (z. B. mit `borg list`, siehe unten) und bestätige den Host-Key, sonst bleibt das Skript bei der ersten Verbindung an der Abfrage hängen.

```sh
#!/bin/sh

# Verbindungsdaten zum Docker Container
export BORG_REPO="ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo"
export BORG_PASSPHRASE='<REPOKEY>'

# Backup-Job ausführen
borg create \
  ::'Rechner_Name--{now:%Y-%m-%dT%H:%M}' \
  /home \
  --verbose \
  --filter AME \
  --list \
  --stats \
  --show-rc \
  --compression lz4 \
  --exclude-caches \
  --exclude '/home/*/.local/share/Trash/*' \
  --exclude '/home/*/.cache/*'
```

---

## 🔄 Restore von einem zweiten Rechner (z. B. Laptop)

Da du mehrere SSH-Schlüssel hinterlegen kannst, ist es möglich, von einem anderen Gerät auf das Archiv zuzugreifen.

So gehst du vor, um einen Restore von einem Zweitgerät zu testen:

### 1. SSH-Key des Zweitgeräts hinzufügen

Trage den öffentlichen SSH-Schlüssel deines Laptops (Inhalt von `~/.ssh/id_ed25519.pub` oder `~/.ssh/id_rsa.pub`) als weitere Variable in die `docker-compose.yml` ein, z. B. `SSH_PUBKEY_LAPTOP=ssh-ed25519 AAAA...`.
Übernimm die Änderung mit `docker compose up -d`. Compose erstellt den Container dabei automatisch neu, das Volume mit den Backups bleibt erhalten. Ein reines `docker restart` reicht **nicht**, weil geänderte Umgebungsvariablen nur beim Neuerstellen übernommen werden.

### 2. Archive auflisten

Öffne das Terminal auf deinem Laptop und setze die Verbindungsdaten. Danach listest du alle vorhandenen Backups auf:

```sh
export BORG_REPO="ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo"
export BORG_PASSPHRASE='<REPOKEY>'

# Zeigt dir alle vorhandenen Sicherungen an
borg list
```

Notiere dir den Namen des Archivs, das du wiederherstellen möchtest (z. B. `Rechner_Name--2023-10-27T15:30`).

### 3. Daten wiederherstellen (Extract)

Erstelle einen leeren Ordner auf deinem Laptop, wechsle hinein und entpacke das gewünschte Archiv:

```sh
mkdir ~/restore_test
cd ~/restore_test

# Entpackt den gesamten Inhalt des Archivs in den aktuellen Ordner
borg extract ::'Rechner_Name--2023-10-27T15:30'
```

_Tipp: Wenn du nur eine bestimmte Datei brauchst, kannst du den Pfad (ohne führenden `/`) am Ende anhängen, z. B. `borg extract ::'ArchivName' home/user/wichtiges_dokument.txt`._

### 4. Alternativ: Backup als Laufwerk einbinden (Mount)

Anstatt alles zu entpacken, kannst du das Backup auch durchsuchen. Dafür braucht Borg auf dem Client FUSE-Unterstützung (unter Linux z. B. das Paket `python3-pyfuse3` bzw. `python3-llfuse`).

```sh
mkdir ~/borg_mount
borg mount ::'Rechner_Name--2023-10-27T15:30' ~/borg_mount

# Jetzt kannst du mit deinem Dateimanager in ~/borg_mount deine Dateien durchsuchen!

# Wenn du fertig bist, hänge das Archiv wieder aus:
borg umount ~/borg_mount
```

---

## ⬆️ Hinweise zum Update von älteren Versionen

- Bestehende Volumes, Repositories und Host-Keys werden weiterverwendet.
- SSH-Schlüssel kommen ausschließlich aus den `SSH_PUBKEY*`-Variablen. Die alte `/home/borguser/.ssh/authorized_keys` im Volume wird beim ersten Start gelöscht. Trage deine Schlüssel also vor dem Update als Variablen ein.
- Clients haben keine Shell mehr, sondern nur noch Borg-Zugriff. Wer die Shell braucht, setzt `SSH_RESTRICT=false`.
