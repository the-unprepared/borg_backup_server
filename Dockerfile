# Basis-Image
FROM alpine:3.22

# Metadaten
LABEL org.opencontainers.image.title="Borg Backup Server" \
      org.opencontainers.image.description="Minimalistischer Borg Backup Server über SSH" \
      org.opencontainers.image.authors="Marcus Schmitt" \
      org.opencontainers.image.source="https://github.com/the-unprepared/borg_backup_server" \
      org.opencontainers.image.licenses="BSD-3-Clause"

# Benötigte Pakete installieren (--no-cache macht apk update und das Löschen des Caches überflüssig)
RUN apk add --no-cache \
    openssh \
    borgbackup \
    cronie \
    tzdata \
    tini

# Benutzer erstellen und für die SSH-Anmeldung freischalten ("*" statt "!"), Passwort-Login bleibt unmöglich
RUN adduser -D -s /bin/sh borguser \
    && sed -i 's/^borguser:!:/borguser:*:/' /etc/shadow

# SSH-Konfiguration (Host-Keys und authorized_keys werden dynamisch über startup.sh erzeugt)
COPY sshd_borg.conf /etc/ssh/sshd_config.d/10-borg.conf

# Skripte in den Container kopieren, Zeilenenden auf Unix-Format konvertieren und ausführbar machen
COPY startup.sh borg-prune.sh /usr/local/bin/
RUN sed -i 's/\r$//' /usr/local/bin/startup.sh /usr/local/bin/borg-prune.sh /etc/ssh/sshd_config.d/10-borg.conf \
    && chmod 755 /usr/local/bin/startup.sh /usr/local/bin/borg-prune.sh

# Repository, Host-Keys und Borg-Cache liegen hier
VOLUME /home/borguser

# Port, über den Borg kommunizieren wird
EXPOSE 22

ENTRYPOINT ["/sbin/tini", "--"]

# Das Start-Skript aufrufen
CMD ["/usr/local/bin/startup.sh"]
