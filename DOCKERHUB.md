# 🛡️ Borg Backup Server

Ein minimalistischer und effizienter Backup-Server zum einfachen Speichern deiner [Borg Backup](https://www.borgbackup.org/) Archive über SSH.
Besonders gut geeignet für NAS-Systeme mit Docker-Unterstützung. Dieser Server ist ausschließlich für die Nutzung mit der Borg Backup Software konzipiert.

📦 **Quellcode, Fragen und Fehlermeldungen:** [github.com/the-unprepared/borg_backup_server](https://github.com/the-unprepared/borg_backup_server)

> ⚠️ **Wichtiger Hinweis:**
> Dies ist ein privates Hobby-Projekt! Es wird keine Haftung für Datenverlust übernommen und es gibt keine Garantie auf Funktion. Nutzung auf eigene Gefahr. Teste deine Backups und Restores regelmäßig!

---

## ✨ Funktionen

- Borg-Server über SSH, nur mit Public Keys
- Mehrere Rechner bzw. Schlüssel, jeweils in einer eigenen Variable
- Clients dürfen ausschließlich `borg serve` ausführen, keine Shell
- Optional: Repository automatisch anlegen, tägliche Bereinigung (`prune` + `compact`), Append-only-Modus
- Schlüssel werden bei jedem Start neu aus der Konfiguration erzeugt: Variable entfernen, Container neu erstellen, Zugriff weg
- Host-Keys bleiben über Updates hinweg erhalten
- Klein: basiert auf Alpine Linux

## 🏷️ Tags und Architekturen

| Tag | Architekturen | Inhalt |
| --- | --- | --- |
| `latest` | `amd64`, `arm64` | Alpine Linux mit Borg 1.4, wird am 1. und 15. jedes Monats automatisch neu gebaut, damit Sicherheitsupdates enthalten sind. |

Auf den Clients muss Borg 1.x (1.2 oder neuer empfohlen) installiert sein. Borg 2.x ist nicht kompatibel.

---

## 🚀 Quick Start (Docker Compose)

Jeder Rechner, der auf das Backup zugreifen darf, bekommt eine eigene Variable `SSH_PUBKEY_<NAME>` mit genau einem Schlüssel. Den Namen hinter `SSH_PUBKEY_` kannst du frei wählen (z. B. `SSH_PUBKEY_1` oder `SSH_PUBKEY_LAPTOP`). Das funktioniert auch in NAS-Oberflächen (Synology, Unraid, Portainer, …), die nur einzeilige Werte erlauben.

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

Nach dem Start zeigt `docker logs borg_backup_server` die Fingerprints der Host-Keys und jedes hinterlegten Schlüssels. Ungültige oder abgeschnittene Schlüssel werden mit einer Warnung übersprungen.

---

## ⚙️ Umgebungsvariablen

| Variable | Status | Beschreibung |
| --- | --- | --- |
| `SSH_PUBKEY_<NAME>` | **Erforderlich** (mind. ein Schlüssel) | Ein Public Key pro Variable, beliebig viele möglich. Der Name darf nur Buchstaben, Ziffern und `_` enthalten, also `SSH_PUBKEY_DOCKER_SERVER` statt `SSH_PUBKEY_DOCKER-SERVER`. |
| `SSH_PUBKEYS` | Optional | Ältere Variante: mehrere Keys in einer Variable. Mehrzeilig nur in der YAML-Mapping-Schreibweise (`SSH_PUBKEYS: \|`). |
| `REPOKEY` | Optional | Passwort des Repositorys (`repokey-blake2`). Ist es gesetzt, wird das Repository beim ersten Start automatisch angelegt. Sonst legst du es vom Client aus mit `borg init` an. |
| `REPOKEY_FILE` | Optional | Pfad zu einer Datei mit dem Passwort, z. B. ein Docker Secret (`/run/secrets/repokey`). Wird verwendet, wenn `REPOKEY` nicht gesetzt ist. |
| `TIMEZONE` | Optional | Zeitzone, z. B. `Europe/Berlin` (alternativ `TZ`). Standard: UTC. |
| `PRUNE_DAYS` | Optional | Behält für so viele Tage jeweils das letzte Backup des Tages (`borg prune --keep-daily`), danach gibt `borg compact` den Speicher frei. Erfordert `PRUNE_TIME` und `REPOKEY`. |
| `PRUNE_TIME` | Optional | Uhrzeit der Bereinigung im Format `HH:MM`. Die Ausgabe erscheint im Docker-Log. |
| `APPEND_ONLY` | Optional | `true`: Clients können Backups anlegen, aber nichts endgültig löschen (Schutz vor Ransomware). Standard: `false`. |
| `SSH_RESTRICT` | Optional | Standard `true`: Clients dürfen nur `borg serve` auf `/home/borguser/repo` ausführen. `false` erlaubt eine normale Shell (nicht empfohlen). |

**Volume:** `/home/borguser` enthält das Repository (`/home/borguser/repo`), die SSH-Host-Keys und den Borg-Cache. Unbedingt als Volume einbinden.

**Port:** Der Container lauscht auf Port `22`. Im Beispiel ist er von außen über `2222` erreichbar.

### ⚠️ Bereinigung mit mehreren Rechnern

`PRUNE_DAYS` wirkt auf **alle Archive im Repository gemeinsam**. Sichern mehrere Rechner in dasselbe Repository, bleibt pro Tag nur das letzte Archiv _eines_ Rechners übrig. Lass in diesem Fall `PRUNE_DAYS` weg und führe `borg prune --glob-archives 'Rechner_Name--*'` auf jedem Client aus, oder betreibe pro Rechner einen eigenen Container.

---

## 📜 Backup vom Client

Verbinde dich vorher **einmal manuell** (z. B. mit `borg list`) und bestätige den Host-Key. Vergleiche ihn dabei mit dem Fingerprint im Docker-Log.

```sh
#!/bin/sh

export BORG_REPO="ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo"
export BORG_PASSPHRASE='<REPOKEY>'

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

**Repository-Schlüssel sichern:** Bei `repokey` liegt der Schlüssel im Repository. Exportiere ihn einmalig und bewahre ihn getrennt vom Server auf:

```sh
borg key export ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo borg-key.txt
```

---

## 🔄 Restore

```sh
export BORG_REPO="ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo"
export BORG_PASSPHRASE='<REPOKEY>'

# Archive auflisten
borg list

# Archiv in den aktuellen Ordner entpacken
mkdir ~/restore_test && cd ~/restore_test
borg extract ::'Rechner_Name--2023-10-27T15:30'

# Oder als Laufwerk einbinden (benötigt FUSE auf dem Client)
mkdir ~/borg_mount
borg mount ::'Rechner_Name--2023-10-27T15:30' ~/borg_mount
borg umount ~/borg_mount
```

Für einen Restore von einem zweiten Rechner trägst du dessen Schlüssel als weitere Variable ein, z. B. `SSH_PUBKEY_LAPTOP=...`, und übernimmst die Änderung mit `docker compose up -d`. Ein reines `docker restart` übernimmt geänderte Variablen nicht.

---

## ⬆️ Update

```sh
docker compose pull && docker compose up -d
```

Volume, Repository und Host-Keys bleiben erhalten, der Fingerprint des Servers ändert sich also nicht.

**Hinweise für ältere Versionen (vor Oktober 2026):**
- Clients haben keine Shell mehr, sondern nur noch Borg-Zugriff. Wer die Shell braucht, setzt `SSH_RESTRICT=false`.
- SSH-Schlüssel kommen ausschließlich aus den `SSH_PUBKEY*`-Variablen und werden bei jedem Start neu eingelesen. Die alte `authorized_keys` im Volume wird gelöscht. Trage deine Schlüssel also vor dem Update als Variablen ein.
- Das alte Beispiel `- SSH_PUBKEYS=|` funktioniert jetzt, empfohlen ist aber `SSH_PUBKEY_<NAME>`.

---

Ausführliche Dokumentation: [README auf GitHub](https://github.com/the-unprepared/borg_backup_server#readme) · Lizenz: BSD-3-Clause
