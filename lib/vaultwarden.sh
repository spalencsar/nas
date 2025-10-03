#!/usr/bin/env bash
#
# lib/vaultwarden.sh
#
# Korrigierte Vaultwarden-Installationsbibliothek für das NAS-Setup-Skript.
# Änderungen:
# - Kein Top-Level-Aufruf von install_vaultwarden beim Sourcen (verhindert sofortiges exit).
# - Fehler führen zu `return`-Codes statt `exit`, damit der Aufrufer (setup.sh) entscheiden kann.
# - Prüft, ob Docker vorhanden ist; gibt passenden Rückgabewert bei Fehlen zurück.
# - Vorsichtiger Umgang mit existierenden Containern/Verzeichnissen.
#
# Diese Datei ist dafür gedacht, mit `source` in setup.sh geladen zu werden.

install_vaultwarden() {
    # Erwartet: log_info, log_error, log_success Funktionen sind verfügbar (aus lib/logging.sh)
    # Erwartet: VAULTWARDEN_DATA_DIR gesetzt (aus config/defaults.sh)
    local container_name="vaultwarden"
    local image="vaultwarden/server:latest"
    local host_port="${VAULTWARDEN_PORT:-8080}"
    local data_dir="${VAULTWARDEN_DATA_DIR:-/opt/vaultwarden}"

    log_info "Installing Vaultwarden..."

    # Prüfen: Docker vorhanden?
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker ist nicht installiert."
        log_error "Bitte Docker zuerst installieren oder im Setup erlauben, Docker zu installieren."
        return 1
    fi

    # Sicherstellen, dass das Datenverzeichnis vorhanden ist
    if ! mkdir -p "${data_dir}" >/dev/null 2>&1; then
        log_error "Konnte Datenverzeichnis '${data_dir}' nicht anlegen."
        return 2
    fi

    # Prüfen, ob ein Container mit dem gewünschten Namen bereits existiert
    if docker ps -a --format '{{.Names}}' | grep -xq "${container_name}"; then
        log_info "Ein Container mit Namen '${container_name}' existiert bereits."
        # Wenn der Container gestoppt ist, starten wir ihn; wenn er läuft, nichts tun.
        if docker ps --format '{{.Names}}' | grep -xq "${container_name}"; then
            log_info "Container '${container_name}' läuft bereits. Überspringe Erstellung."
            log_success "Vaultwarden ist (vermutlich) bereits installiert und läuft."
            return 0
        else
            log_info "Starte vorhandenen Container '${container_name}'..."
            if docker start "${container_name}" >/dev/null 2>&1; then
                log_success "Container '${container_name}' erfolgreich gestartet."
                return 0
            else
                log_error "Fehler beim Starten des Containers '${container_name}'."
                return 3
            fi
        fi
    fi

    # Pull the image first (optional, improves reliability)
    log_info "Lade Vaultwarden-Image '${image}' herunter..."
    if ! docker pull "${image}"; then
        log_error "Fehler beim Herunterladen des Images '${image}'."
        return 4
    fi

    # Start the container (grundlegendes Beispiel)
    # Anpassungen möglich: Ports, Umgebungsvariablen (z.B. ADMIN_TOKEN), Volumes, Netzwerke.
    log_info "Erstelle und starte Container '${container_name}' (Port ${host_port})..."
    if docker run -d \
        --name "${container_name}" \
        --restart unless-stopped \
        -v "${data_dir}:/data" \
        -p "${host_port}:80" \
        "${image}" >/dev/null 2>&1; then

        log_success "Vaultwarden-Container '${container_name}' erfolgreich erstellt und gestartet."
        log_info "Vaultwarden erreichbar auf Port ${host_port} (http)."
        return 0
    else
        log_error "Fehler beim Erstellen/Starten des Vaultwarden-Containers."
        return 5
    fi
}

# Optional: Helfer, der prüft ob Vaultwarden bereits installiert ist (Exit-Code 0 = installiert)
is_vaultwarden_installed() {
    if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' | grep -xq '^vaultwarden$'; then
        return 0
    fi
    return 1
}

# Nur ausführen, wenn diese Datei direkt ausgeführt wird (nicht beim `source` in setup.sh).
# Das erlaubt unabhängiges Testen, ohne dass Sourcing das Haupt-Skript beendet.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Falls direkt ausgeführt: versuchen wir die Funktion und geben das Ergebnis als Exit-Code zurück.
    install_vaultwarden "$@"
    exit $?
fi
