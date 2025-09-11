# Borg Backup Server

Ein Backup Server zum einfachen Speichern deiner Borg Backups über ssh.  
Besonders gut für NAS mit Docker Support geeignet.  
Der Server funktioniert nur mit der [Borg Backup](https://www.borgbackup.org/) Software.

❗ Dies ist ein Hobby Projekt !!!  
❗ Keine Haftung, keine Garantie.

```yaml
services:
    bbs:
      image: unprepared/borg_backup_server:latest
      container_name: borg_backup_server
      ports:
        - 2222:22
      environment:
        SSH_PUBKEY: "ssh-rsa AAAAB3NzaC1yc......"
        REPOKEY: "REPOKEY"
        TIMEZONE: Europe/Berlin
        PRUNE_DAYS: 14
        PRUNE_TIME: "03:00"
      volumes:
        - bbs_volumen:/home/borguser
      restart: always


volumes:
  bbs_volumen:
```

## 📔 Erklärung:

- SSH_PUBKEY:
    - Der Public Key deines Rechners, der den Backup Job durchführt.
    - Bitte bedenke, wenn der Backup Job als Root durchgeführt wird, muss der root Public Key verwendet werden.
- REPOKEY (optional):
    - Unter diesem Schlüssel wird das Repository verschlüsselt.
        - Ist REPOKEY gesetzt, wird ras repository beim start automatisch angelegt.
        - Ohne diesen muss das repository selbst über ssh vom Backup Rechner erstellt werden (borg init)
        - REPOKEY sollte nur gesetzt werden, wenn der Container auf eigener sicherer Hardwar läuft.
        - Dieser Wert von jedem der Zugang zu dem Contaiern hat einsehbar.
- TIMEZONE (optional):
    - Die Zeitzone für das Ausführen des Prune Jobs.
- PRUNE_DAYS (optional):
    - Ist das enviroment gesetzt, werden Backups nach PRUNE_DAYS Tage automatisch gelöscht.
    - Der REPOKEY muss hierfür natürlich gesetzt sein.
    - Bei Verwendung von PRUNE_DAYS muss auch PRUNE_TIME und REPOKEY angegeben werden.
- PRUNE_TIME (optional):
    - Die Uhrzeit wann der Prune Job durchgeführt werden soll.
    - Bei Verwendung von PRUNE_TIME muss auch PRUNE_DAYS und REPOKEY angegeben werden.





## Ein Beispiel eines Backup Scriptes zur Sicherung auf dem Server.

```
#!/bin/sh

export BORG_REPO="ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo"
export BORG_PASSPHRASE='<REPOKEY>'

borg create                                                                 \
  ::'Rechner_Name--{now:%Y-%m-%dT%H:%M}'                                    \
  /home                                                                     \
                                                                            \
	--verbose                                                           \
	--filter AME                                                        \
	--list                                                              \
	--stats                                                             \
	--show-rc                                                           \
	--compression lz4                                                   \
                                                                            \
	--exclude-caches                                                    \
	--exclude '/home/*/.local/share/Trash/*'                            \
	--exclude '/home/*/.cache/*'                                        \
	--exclude '/var/tmp/*'
```
