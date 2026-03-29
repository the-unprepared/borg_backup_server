# Basis-Image
FROM alpine:3.22

# Metadaten
LABEL maintainer="Marcus Schmitt"
LABEL description="Borg Backup Server"

# System aktualisieren und benötigte Pakete installieren
RUN apk update && apk add --no-cache \
    openssh \
    borgbackup \
    shadow \
    cronie \
    tzdata \
    dos2unix \
    tini \
    && rm -rf /var/cache/apk/*

# Benutzer erstellen
RUN adduser -D -s /bin/sh borguser

# SSH-Verzeichnis für den Benutzer erstellen und Berechtigungen setzen
RUN mkdir -p /home/borguser/.ssh && chown -R borguser:borguser /home/borguser

# Benutzerkonto für SSH-Anmeldung freischalten, aber das Passwort-Login deaktivieren
RUN usermod -p '*' borguser

# SSH-Konfiguration anpassen (Host-Keys werden dynamisch über startup.sh erzeugt)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#StrictModes yes/StrictModes no/' /etc/ssh/sshd_config \
    && echo "AllowUsers borguser" >> /etc/ssh/sshd_config

# Port, über den Borg kommunizieren wird
EXPOSE 22

# Das Start-Skript in den Container kopieren
COPY startup.sh /usr/local/bin/startup.sh

# Konvertiere Zeilenenden auf Unix-Format und setze Ausführungsrechte in einem Schritt
RUN dos2unix /usr/local/bin/startup.sh && chmod +x /usr/local/bin/startup.sh

ENTRYPOINT ["/sbin/tini", "--"]

# Das Start-Skript aufrufen
CMD ["/usr/local/bin/startup.sh"]
