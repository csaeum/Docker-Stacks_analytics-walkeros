<!-- README.md - walkerOS - START -->
# walkerOS Stack

Selbst gehosteter [walkerOS](https://www.walkeros.io/docs/)-Collector als Docker-Stack hinter
Traefik. Er ist für Matomo, Meta und Pinterest vorgesehen. GA4 und Google Ads bleiben im Stack
`analytics-gtm-sstm-projekt`.

> **Stand:** Im Aufbau. Der Collector läuft, gibt Events aber nur ins Container-Log aus. Echte
> Tracking-Ziele sind noch nicht angebunden.

## Dokumentation

- [`Projekt.md`](Projekt.md): Aufbau, Tracking-Ziele, Entscheidungen und Ablösekriterien
- [`STATUS.md`](STATUS.md): aktueller Stand und nächster Schritt
- [`CICD-Actions.md`](CICD-Actions.md): Pipeline, Scanner und lokale Prüfung
- [`ReadMe-MCP-nutzen.md`](ReadMe-MCP-nutzen.md): Betrieb, Dev-Instanz und Fehlersuche mit dem MCP

## Voraussetzungen

- Docker und Docker Compose
- Laufender Traefik-Stack (`docker-traefik-proxy`) mit dem externen Netzwerk `traefik_proxy_network`
- Laufender Autoheal-Stack (`docker-autoheal-neustart`)
- DNS-Eintrag für die Collector-Domain

## Einrichtung

1. In `.env.local` die Host-Regel `HOSTRULE` auf die Collector-Domains setzen, mehrere per `||` trennen.
2. Die eigenen Website-Domains in `ALLOWED_ORIGIN_REGEX` in `.env.local` eintragen.
3. Stack bauen und starten:

```bash
docker compose --env-file .env --env-file .env.local up -d --build
```

Der Stack liefert auch `https://collect.<domain>/walker.js` aus. Neue Versionen erreichen die Websites
damit über denselben Befehl, sie speichern die Datei bis zu einer Stunde im Cache.

Nach jeder Änderung an `flow.json` oder `web/flow.web.json` müssen die Images neu gebaut werden, weil
die Flow-Konfiguration beim Build in das Bundle wandert. Bei einem Versions-Update `WALKEROS_VERSION` in `.env` und die
Paketversionen in `flow.json` gemeinsam anpassen.

## Prüfen

```bash
# Container-Status, muss "healthy" sein
docker inspect --format '{{.State.Health.Status}}' walkeros-walkerOS

curl -X POST https://collect.shop-a.example/collect \
  -H 'Origin: https://shop-a.example' \
  -H 'Content-Type: application/json' \
  -d '{"name":"page view","data":{"title":"Home"}}'

# Das Event erscheint im Log
docker compose --env-file .env --env-file .env.local logs -f walkeros
```

`/collect` antwortet mit `{"success":true,...}`.

## Zugriffsschutz

Von außen ist nur `POST` und `OPTIONS` auf `/collect` erreichbar, und nur mit einem `Origin` aus
`ALLOWED_ORIGIN_REGEX`. Alles andere beantwortet Traefik mit 404, auch `/ready` und den GET-Pixel.
Zu viele Anfragen pro IP beantwortet Traefik mit 429. Das stoppt fremde Websites, aber keine
Skripte, die den `Origin`-Header fälschen.

## Lizenz

Copyright (C) 2026 Christian Säum – web-seo-consulting.eu

Dieses Projekt steht unter der GNU Affero General Public License, Version 3
oder (nach deiner Wahl) einer späteren Version (`AGPL-3.0-or-later`). Der
vollständige Lizenztext steht in der Datei [`LICENSE`](LICENSE).

Diese Angabe betrifft nur die in diesem Repository enthaltenen eigenen
Dateien (Konfiguration, Skripte, Anpassungen). Eingebundene Fremdsoftware und
Container-Images unterliegen weiterhin ihren eigenen Lizenzen.
<!-- README.md - walkerOS - ENDE -->
