# 🛡️ Borg Backup Server

Ein minimalistischer und effizienter Backup-Server zum einfachen Speichern deiner [Borg Backup](https://www.borgbackup.org/) Archive über SSH.  
Besonders gut geeignet für NAS-Systeme mit Docker-Unterstützung. Dieser Server ist ausschließlich für die Nutzung mit der Borg Backup Software konzipiert.

![Docker Hub](https://img.shields.io/badge/Docker_Hub-unprepared%2Fborg__backup__server-blue?logo=docker)

---

![Borg Backup Server Logo](logo.jpg)

> ⚠️ **Wichtiger Hinweis:** > Dies ist ein privates Hobby-Projekt! Es wird keine Haftung für Datenverlust übernommen und es gibt keine Garantie auf Funktion. Nutzung auf eigene Gefahr. Teste deine Backups und Restores regelmäßig!

---

## 🚀 Quick Start (Docker Compose)

Hier ist ein Beispiel, wie du den Server schnell und einfach mit `docker-compose` starten kannst.

**Besonderheit:** Über die Variable `SSH_PUBKEYS` kannst du ganz bequem mehrere SSH-Schlüssel hinterlegen (einfach zeilenweise untereinander). Das ist besonders praktisch, wenn du nicht nur vom Haupt-Rechner sichern möchtest, sondern später vielleicht von einem anderen Rechner (z. B. deinem Laptop) auf das Backup-Archiv zugreifen musst, um Dateien wiederherzustellen.

```yaml
services:
  bbs:
    image: unprepared/borg_backup_server:latest
    container_name: borg_backup_server
    ports:
      - 2222:22
    environment:
      - TIMEZONE=Europe/Berlin
      - REPOKEY=DeinGeheimerRepoSchlüssel
      - PRUNE_DAYS=14
      - PRUNE_TIME=03:00
      - SSH_PUBKEYS=|
          ssh-rsa AAAAB3NzaC1yc... rechner1@backup
          ssh-ed25519 AAAAC3Nz... rechner2@restore
    volumes:
      - bbs_volumen:/home/borguser
    restart: unless-stopped

volumes:
  bbs_volumen:
```

---

## ⚙️ Umgebungsvariablen (Environment)

|     |     |     |
| --- | --- | --- |
|     |     |     |
| Variable | Status | Beschreibung |
| `SSH_PUBKEYS` | **Erforderlich** | Die Public Keys der Rechner, die Zugriff auf das Backup benötigen. Mehrere Keys können als mehrzeiliger String hinterlegt werden. |
| `REPOKEY` | Optional | Das Passwort, mit dem das Repository verschlüsselt wird. Ist dies gesetzt, wird das Repo beim Start automatisch angelegt. Ohne diesen Key musst du das Repo selbst über SSH initialisieren (`borg init`). _Hinweis: Nur setzen, wenn der Container auf eigener, sicherer Hardware läuft, da der Key im Klartext in der Compose-Datei steht._ |
| `TIMEZONE` | Optional | Die Zeitzone (z. B. `Europe/Berlin`), die für die korrekte Ausführung des Prune-Jobs wichtig ist. Eine vollständige Liste aller gültigen Zeitzonen-Namen findest du in der [Wikipedia-Liste der tz-Datenbank](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). |
| `PRUNE_DAYS` | Optional | Löscht automatisch Backups, die älter als `X` Tage sind. Erfordert, dass auch `PRUNE_TIME` und `REPOKEY` gesetzt sind. |
| `PRUNE_TIME` | Optional | Die Uhrzeit (z. B. `03:00`), zu der die automatische Bereinigung (Prune) ausgeführt werden soll. |

---

## 📜 Beispiel: Backup-Skript für den Client

So könnte ein einfaches Shell-Skript auf deinem Rechner aussehen, das die Daten auf diesen Container sichert. Passe die IP und den Port entsprechend an:

```
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
  --exclude '/home/*/.cache/*' \
  --exclude '/var/tmp/*'
```

---

## 🔄 Restore von einem zweiten Rechner (z. B. Laptop)

Da du über die Variable `SSH_PUBKEYS` mehrere SSH-Schlüssel hinterlegen kannst, ist es möglich von einem anderen Gerät auf das Archiv zuzugreifen.

So gehst du vor, um einen Restore von einem Zweitgerät zu testen:

### 1\. SSH-Key des Zweitgeräts hinzufügen

Stelle sicher, dass der öffentliche SSH-Schlüssel (`~/.ssh/id_rsa.pub` oder `~/.ssh/id_ed25519.pub`) deines Laptops in der `docker-compose.yml` unter `SSH_PUBKEYS` eingetragen ist. Starte den Container danach neu (`docker compose up -d` oder Container neu bauen, falls nötig).

### 2\. Archive auflisten

Öffne das Terminal auf deinem Laptop und setze die Verbindungsdaten. Danach listest du alle vorhandenen Backups auf:

```
export BORG_REPO="ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo"
export BORG_PASSPHRASE='<REPOKEY>'

# Zeigt dir alle vorhandenen Sicherungen an
```

Notiere dir den Namen des Archivs, das du wiederherstellen möchtest (z. B. `Rechner_Name--2023-10-27T15:30`).

### 3\. Daten wiederherstellen (Extract)

Erstelle einen leeren Ordner auf deinem Laptop, wechsle hinein und entpacke das gewünschte Archiv:

```
mkdir ~/restore_test
cd ~/restore_test

# Entpackt den gesamten Inhalt des Archivs in den aktuellen Ordner
borg extract ::'Rechner_Name--2023-10-27T15:30'
```

_Tipp: Wenn du nur eine bestimmte Datei brauchst, kannst du den Pfad am Ende anhängen (z. B._ `borg extract ::'ArchivName' home/user/wichtiges_dokument.txt`_)._

### 4\. Alternativ: Backup als Laufwerk einbinden (Mount)

Anstatt alles zu entpacken, kannst du das Backup auch durchsuchen:

```
mkdir ~/borg_mount
borg mount ::'Rechner_Name--2023-10-27T15:30' ~/borg_mount

# Jetzt kannst du mit deinem Dateimanager in ~/borg_mount deine Dateien durchsuchen!

# Wenn du fertig bist, hänge das Archiv wieder aus:
borg umount ~/borg_mount
```
