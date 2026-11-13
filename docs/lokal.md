# Lokale Umgebung

Alles, was für einen Echtlauf nötig ist, läuft auf dem eigenen Rechner: der Stack, ein echtes Matomo
und die Sulu-Testseite. Keine Domains, keine Secrets, kein Eingriff in die Produktion.

```
Browser ── https://sulu-bundles.ddev.site (DDEV, Sulu mit dem walkerOS-Bundle)
   │  lädt walker.js von http://localhost:18081
   └─ POST http://localhost:18080/collect ──► Stack (Docker, ohne Traefik)
                                                  └─► http://ddev-matomo-web/matomo.php (DDEV-Projekt "matomo", Site 12)
```

## Bausteine

| Baustein | Ort | Zweck |
|---|---|---|
| Stack (`walkeros`, `walker`) | dieses Repo, `lokal/` | Collector und `walker.js`, Ports nur auf `127.0.0.1` |
| Matomo | DDEV-Projekt `matomo` (`~/Entwicklungsumgebung/ddev/matomo`), `https://matomo.ddev.site` | echtes Ziel, Site 12 |
| Sulu | DDEV-Projekt `sulu-bundles`, Bundle `wsc_sulubundle_walkeros` | liefert die Seiten und den Loader |

## Einmalig einrichten

1. **Matomo:** DDEV-Projekt anlegen (`ddev config --project-type=php --php-version=8.4 --database=mariadb:11.8
   --docroot=matomo --create-docroot`), das aktuelle Matomo entpacken (`matomo-latest.zip` von
   `builds.matomo.org` im Projektverzeichnis, `unzip` im Container). Im Browser die Installation durchlaufen.
   Datenbank: Host `db`, Benutzer, Passwort und Name jeweils `db`. **Vor dem Anlegen der ersten Website**
   `ALTER TABLE matomo_site AUTO_INCREMENT=12` ausführen (`ddev mysql`), damit die Website die ID 12 bekommt, die
   `flow.json` fest verwendet. Website-URL: `https://sulu-bundles.ddev.site`.
2. **Token:** In Matomo einen API-Token für den Superuser anlegen (Persönlich → Sicherheit). Er gehört nur in die
   gitignorierte Datei `.env.lokal.local` im Repo-Wurzelverzeichnis: `MATOMO_TOKEN_AUTH=<Token>`. Der Superuser
   hat auf Site 12 mindestens Schreibrechte, die für `cip` nötig sind.
3. **Sulu:** Im Admin-Tab „WalkerOS“ des Webspace oder per `walker_url` die Adresse
   `http://localhost:18081/walker.js` eintragen. Die Seite lädt sie von `https://` aus; `localhost` ist von der
   Mixed-Content-Sperre ausgenommen.

## Starten und stoppen

```bash
lokal/lokal.sh up      # DDEV-Matomo starten, Stack bauen und starten
lokal/lokal.sh status
lokal/lokal.sh logs    # Collector-Log
lokal/lokal.sh down
```

`MATOMO_ORIGIN` steht in `lokal/env.lokal` auf `https://sulu-bundles.ddev.site`. Events von anderen Herkünften
und ohne `analytics`-Einwilligung erreichen Matomo nicht.

## Prüfen

- **Ohne Browser:** Event per `curl` an `http://localhost:18080/collect` mit `Origin: https://sulu-bundles.ddev.site`
  schicken (Beispiel-Event siehe `ReadMe-MCP-nutzen.md`), dann Matomo per API lesen:
  `Live.getLastVisitsDetails` mit `token_auth` per **POST** (Matomo 5 lehnt den Token in der Adresse ab).
- **Im Browser:** Die Testseite des Bundles öffnen, im Cookie-Banner „Analyse“ zulassen, klicken, scrollen. In Matomo
  unter Besucher → Besucher-Log erscheinen die Events.
- Der Build der `flow.json` kann scheitern, ohne dass `lokal.sh` das deutlich zeigt: bei Fehlern
  `docker compose … build walkeros` einzeln ausführen.

## Meta und Pinterest serverseitig (Attrappe)

`lokal/lokal.sh up` setzt in `lokal/env.lokal` Origin, Pixel-ID, Ad-Account und Fake-Tokens und lenkt die Aufrufe auf `http://capi-mock:9000`.
Die Attrappe `lokal/capi-mock.js` einmal starten und ihre Ausgabe lesen:

```bash
docker run -d --name capi-mock --network walkeros-lokal -v "$PWD/lokal/capi-mock.js:/m.js:ro" node:22-alpine node /m.js
docker logs capi-mock      # eine JSON-Zeile je Anfrage an Meta (/meta/…) und Pinterest (/pinterest/…)
```

Echte Aufrufe lokal: in `.env.lokal.local` `META_1_URL=`/`PINTEREST_1_URL=` auf die Standardadressen setzen (Zeile ohne Wert reicht nicht, die
echten Adressen eintragen), echte Token und `META_1_TEST_EVENT_CODE` bzw. `PINTEREST_1_TEST=true` ergänzen, siehe `docs/capi.md`.

## Später: Sylius

Der Shop-Teil (Bundle `wsc_syliusbundle_walkeros`, Shop-Übergang #24/#6 mit der Geräte-Kennung aus Stack #11) kommt
als zweites DDEV-Projekt `sylius-shop` auf eigener Domain dazu. Es hängt am selben Collector
(`http://localhost:18080/collect`); `MATOMO_ORIGIN` erlaubt dann eine zweite Herkunft (Liste statt einzelnem Wert).
Voraussetzung ist ein Sylius-Projekt und das Sylius-Bundle, beides gibt es noch nicht.
