# Borg Backup Server

Ein Backup Server zum einfachen Speichern deiner Borg Backups über ssh.  
Besonders gut für NAS mit Docker Support geeignet.  
Der Server funktioniert nur mit der [Borg Backup](https://www.borgbackup.org/) Software.  
![](https://hub.docker.com/r/unprepared/borg_backup_server)

Docker Container: [Docker Hub](https://hub.docker.com/r/unprepared/borg_backup_server).  

![borg_backup_server logot](https://github.com/the-unprepared/borg_backup_server/blob/main/logo.jpg)

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

| Enviroment: | Beschreibung: |
| :--- | :--- |
| **SSH_PUBKEY** | Der Public Key deines Rechners, der den Backup Job durchführt.<br>Bitte bedenke, wenn der Backup Job als Root durchgeführt wird,muss der root Public Key verwendet werden. |
| **REPOKEY** (optional) | Unter diesem Schlüssel wird das Repository verschlüsselt.<br>Ist REPOKEY gesetzt, wird das Repository beim Start automatisch angelegt.<br>Ohne diesen muss das Repository selbst über SSH vom Backup-Rechner erstellt werden (borg init).<br>REPOKEY sollte nur gesetzt werden, wenn der Container auf eigener sicherer Hardware läuft. Dieser Wert ist von jedem, der Zugang zu dem Container hat, einsehbar. |
| **SSH_PUBKEY_2** (optional) | SSH_PUBKEY_2 - SSH_PUBKEY_5 können gesetz werden, wenn mehrere SSH zugänge benötigt werden.<br>Ist nicht gedacht für mehrere Backup Rechner, sonder wenn von einem anderen Rechner Zugang zum Backup Archiv benötigt wird. |
| **TIMEZONE** (optional) | Die Zeitzone für das Ausführen des Prune Jobs. |
| **PRUNE\_DAYS** (optional) | Ist PRUNE\_DAYS gesetzt, werden Backups älter als x Tage automatisch gelöscht.<br>Zeitpunkt ist PRUNE\_TIME. Der REPOKEY sowie PRUNE\_TIME müssen hierfür gesetzt sein. |
| **PRUNE\_TIME** (optional) | Die Uhrzeit wann der Prune Job durchgeführt werden soll.<br>Bei Verwendung von PRUNE\_TIME muss auch PRUNE\_DAYS gesetzt sein. |

## Ein Beispiel eines Backup Scriptes zur Sicherung auf dem Server.

```
#!/bin/sh

export BORG_REPO="ssh://borguser@<IP_CONTAINER>:2222/home/borguser/repo"
export BORG_PASSPHRASE='<REPOKEY>'

borg create                                                                 \
  ::'Rechner_Name--{now:%Y-%m-%dT%H:%M}'                                    \
  /home                                                                     \
                                                                            \
	--verbose                                                               \
	--filter AME                                                            \
	--list                                                                  \
	--stats                                                                 \
	--show-rc                                                               \
	--compression lz4                                                       \
                                                                            \
	--exclude-caches                                                        \
	--exclude '/home/*/.local/share/Trash/*'                                \
	--exclude '/home/*/.cache/*'                                            \
	--exclude '/var/tmp/*'
```
