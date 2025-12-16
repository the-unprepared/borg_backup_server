# 🛡️ Borg Backup Server

Ein schlanker, Docker-basierter **Borg Backup Server**, der SSH-Zugriff für sichere Backups bereitstellt.
Dieses Image eignet sich besonders für den Einsatz auf NAS-Systemen (z. B. Synology, QNAP, Unraid) oder jedem Server mit Docker-Unterstützung. Es dient als Ziel (Target) für die [Borg Backup Software](https://www.borgbackup.org/).

Github Repo: [Hier klicken](https://github.com/the-unprepared/borg_backup_server)

---

## ⚠️ Disclaimer
Dies ist ein Open-Source-Hobbyprojekt. Die Nutzung erfolgt auf eigene Gefahr. Es wird **keine Haftung** für Datenverlust oder **Garantie** für die Funktionalität übernommen. Bitte teste deine Backups regelmäßig!

---

## 🚀 Quick Start (Docker Compose)

Kopiere den folgenden Block in deine `docker-compose.yml` oder Portainer-Stack-Konfiguration.

```yaml
services:
  bbs:
    image: unprepared/borg_backup_server:latest
    container_name: borg_backup_server
    restart: always
    ports:
      - "2222:22" # Host-Port : Container-Port
    environment:
      # Public Key des Clients, der das Backup sendet (z.B. Inhalt von ~/.ssh/id_rsa.pub)
      SSH_PUBKEY: "ssh-rsa AAAAB3NzaC1yc......"
      # Optional: Verschlüsselungspasswort für das Repo
      REPOKEY: "DeinSicheresPasswort"
      TIMEZONE: "Europe/Berlin"
      # Optional: Pruning (Automatisches Aufräumen)
      PRUNE_DAYS: 14
      PRUNE_TIME: "03:00"
    volumes:
      # Persistenter Speicher für die Backups
      - borg_data:/home/borguser

volumes:
  borg_data:
