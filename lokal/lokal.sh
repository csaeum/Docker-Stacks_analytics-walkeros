#!/usr/bin/env bash
# lokal.sh - walkerOS - START
# Startet und stoppt die lokale Umgebung (Stack + Matomo im DDEV).
# Aufruf: lokal/lokal.sh up | down | status | logs
set -euo pipefail

cd "$(dirname "$0")/.."
MATOMO_DDEV="${MATOMO_DDEV:-$HOME/Entwicklungsumgebung/ddev/matomo}"
TOKEN_DATEI=".env.lokal.local"

compose() {
    docker compose -p walkeros-lokal \
        --env-file .env --env-file lokal/env.lokal --env-file "$TOKEN_DATEI" \
        -f docker-compose.yml -f lokal/docker-compose.lokal.yml "$@"
}

case "${1:-}" in
    up)
        [ -f "$TOKEN_DATEI" ] || { echo "Fehlt: $TOKEN_DATEI mit MATOMO_TOKEN_AUTH=<lokaler Token> (siehe docs/lokal.md)" >&2; exit 1; }
        (cd "$MATOMO_DDEV" && ddev start)
        docker network inspect walkeros-lokal >/dev/null 2>&1 || docker network create walkeros-lokal >/dev/null
        compose up -d --build
        echo "walker.js: http://localhost:18081/walker.js, Collector: http://localhost:18080/collect"
        echo "Matomo: https://matomo.ddev.site (Site 12)"
        ;;
    down)
        compose down
        ;;
    status)
        compose ps
        ;;
    logs)
        compose logs --tail=50 -f walkeros
        ;;
    *)
        echo "Aufruf: $0 up | down | status | logs" >&2
        exit 2
        ;;
esac
# lokal.sh - walkerOS - ENDE
