<!-- ReadMe-MCP-nutzen.md - walkerOS - START -->
# walkerOS betreiben, testen und mit dem MCP verbessern

Diese Anleitung beschreibt, wie du den Stack produktiv betreibst, daneben gefahrlos in einer
Dev-Instanz experimentierst und Fehler mit dem MCP und Claude Code findest.

## Das Grundprinzip

```
Dein PC                               Server
─────────────────────────             ──────────────────────────────────────
Claude Code                           Traefik
 ├─ MCP walkeros-flow                  ├─ collect.deine-domain.de
 │   prüft und simuliert flow.json     │    └─ walkeros-walkerOS      (main)
 │                                     └─ collect-dev.deine-domain.de
 └─ ssh ── liest Container-Logs ───►        └─ walkeros-dev-walkerOS  (Branch)
```

**Der MCP ist nicht mit dem Server verbunden.** Er läuft nur auf deinem PC und arbeitet mit Dateien.
Den laufenden Collector kann er weder auslesen noch ändern. Die Fehlersuche funktioniert deshalb so:

1. Claude Code liest die Logs des Servers per `ssh`.
2. Der MCP prüft die `flow.json` und spielt den Fehler lokal nach.
3. Die Korrektur läuft über Dev, Pull Request und CI in die Produktion.

## ⚠️ Zwei Regeln, die vor allem anderen gelten

**1. `flow_push` sendet echte Daten** an die Ziele aus der `flow.json`. Nutze es nur gegen Test-Ziele.

**2. `flow_simulate` ist nicht immer eine Simulation.** Das wurde mit 4.9.0 getestet:

| Ziel | Verhalten von `flow_simulate` |
|---|---|
| Fertiges Paket, z. B. `@walkeros/server-destination-api` | Sendet nichts und zeigt mit `verbose: true` die Daten, die es senden würde |
| Eigene `push`-Funktion mit `fetch` | **Sendet wirklich** und meldet trotzdem `0/1 destinations received` |

Eigene `push`-Funktionen, wie sie für Matomo und GA4 geplant sind, müssen ihr Ziel deshalb immer aus
einer Umgebungsvariable lesen und ohne diese Variable abbrechen:

```json
"matomo": {
  "code": {
    "push": "$code:async (event, context) => { const url = context.config.settings.url; if (!url) { context.logger.warn('no target url, event not sent'); return; } await fetch(url, { method: 'POST', body: JSON.stringify({ name: event.name }) }); }"
  },
  "config": { "settings": { "url": "$env.MATOMO_URL:" } }
}
```

Ist `MATOMO_URL` auf deinem PC nicht gesetzt, geht bei der Simulation nichts raus. Setze echte Ziel-URLs
und Secrets deshalb **nie** in deiner lokalen Shell. Auf dem Server müssen sie im Abschnitt
`environment:` der `docker-compose.yml` an den Container übergeben werden. Das ist noch nicht eingebaut
und kommt mit dem ersten echten Ziel.

## MCP einrichten

Voraussetzung ist Node.js 20 oder neuer. Die Konfiguration liegt bereits in `.mcp.json`, die Version ist
festgelegt und die Telemetrie abgeschaltet.

1. Claude Code im Projektverzeichnis starten:
   ```bash
   cd ~/Entwicklungsumgebung/Forgejo/Docker-Stacks/analytics-walkeros
   claude
   ```
2. Die Nachfrage zum Server `walkeros-flow` bestätigen.
3. In Claude Code `/mcp` eingeben. `walkeros-flow` muss als verbunden erscheinen.

Du startest den Server nicht selbst, das erledigt Claude Code bei Bedarf. Beim ersten Start lädt `npx`
das Paket herunter, das dauert kurz.

**Bei einem Update von walkerOS** die Version in `.mcp.json` zusammen mit `.env` und `flow.json` ändern.

### Was der MCP kann

| Tool | Zweck | Sendet Daten? |
|---|---|---|
| `flow_validate` | Flows, Events, Mappings und Contracts prüfen, mit `strict: true` auch Warnungen als Fehler | Nein, lädt aber Paket-Schemas |
| `flow_load` | Flow laden oder neu anlegen | Nein |
| `flow_examples` | Beispiele der Flow-Schritte auflisten | Nein |
| `package_search`, `package_get` | Pakete und ihre Einstellungen nachschlagen | Nein, liest von npm |
| `flow_bundle` | Flow bauen, legt eine Datei an | Nein, lädt aber Pakete |
| `flow_simulate` | Event durch einen Flow-Schritt schicken | **Bei eigener `push`-Funktion: ja** |
| `flow_push` | Event an die echten Ziele senden | **Ja** |

## Produktion betreiben

Die Produktion läuft immer auf dem Stand von `main`.

**Einrichten:**

1. Die echten Website-Domains in der `flow.json` unter `cors.origin` eintragen und über einen Pull Request
   nach `main` bringen. Domains sind nicht geheim. Lokale Änderungen auf dem Server würden dagegen bei
   `git pull` Konflikte erzeugen.
2. Repo auf dem Server klonen:
   ```bash
   git clone https://git.web-seo-consulting.eu/Docker-Stacks/analytics-walkeros.git
   cd analytics-walkeros
   ```
3. Datei `.env.local` anlegen. Sie liegt nicht im Git und überschreibt die Platzhalter aus `.env`:
   ```dotenv
   HOSTRULE=Host(`collect.deine-domain.de`)
   ALLOWED_ORIGIN_REGEX='^https://www\.deine-domain\.de$'
   ```
4. Stack starten. Diesen Befehl nutzt du auch für jedes spätere Update:
   ```bash
   docker compose --env-file .env --env-file .env.local up -d --build
   ```

**Prüfen:**

```bash
docker inspect --format '{{.State.Health.Status}}' walkeros-walkerOS   # muss "healthy" sein
curl -X POST https://collect.deine-domain.de/collect \
  -H 'Origin: https://www.deine-domain.de' \
  -H 'Content-Type: application/json' \
  -d '{"name":"page view","data":{"title":"Test"}}'                    # {"success":true,...}
```

**Aktualisieren:** `git pull`, dann denselben `up`-Befehl.

**Zurückrollen:** Mit `git log` den letzten guten Stand suchen, mit `git checkout <commit>` wechseln und
denselben `up`-Befehl ausführen. Danach den Fehler auf `main` beheben und wieder zu `main` wechseln.

> **Noch nicht produktiv nutzbar:** Aktuell schreibt der Stack Events nur ins Log. Solange das so ist,
> landen echte Besucherdaten im Container-Log. Binde produktive Websites erst an, wenn echte Ziele und
> Consent eingerichtet sind.

## Dev-Instanz daneben betreiben

Die Dev-Instanz läuft auf demselben Server hinter demselben Traefik, aber mit eigenem Verzeichnis, eigener
Domain, eigenem Container und eigenem Branch. Dass beide sich nicht gegenseitig beeinflussen, wurde lokal mit
zwei Instanzen hinter einem Traefik v3.6 getestet.

**Einmalig einrichten:**

1. DNS-Eintrag `collect-dev.deine-domain.de` auf den Server legen.
2. Eigenes Verzeichnis anlegen:
   ```bash
   git clone https://git.web-seo-consulting.eu/Docker-Stacks/analytics-walkeros.git analytics-walkeros-dev
   cd analytics-walkeros-dev
   ```
3. Datei `.env.dev.local` anlegen. Sie liegt nicht im Git und überschreibt nur diese Werte:
   ```dotenv
   COMPOSE_PROJECT_NAME=walkeros-dev
   HOSTRULE=Host(`collect-dev.deine-domain.de`)
   ALLOWED_ORIGIN_REGEX='^https://(staging\.deine-domain\.de|sw6-plugin\.ddev\.site)$'
   ```

**Starten und wechseln:**

```bash
git fetch && git checkout feature/mein-experiment && git pull
docker compose --env-file .env --env-file .env.dev.local up -d --build
```

Gib `--env-file` bei **jedem** `docker compose`-Befehl in diesem Verzeichnis an. Ohne diese Angabe nutzt
Compose den Projektnamen `walkeros` aus `.env` und greift damit **die Produktion** an.

**Stoppen:**

```bash
docker compose --env-file .env --env-file .env.dev.local down
```

**Regeln für Dev:**

- Nur Test-Ziele verwenden: eigene GA4-Test-Property, eigene Matomo-Site und die Testmodi von Meta und
  Pinterest. Sonst verfälscht Dev deine echten Zahlen.
- Für Tests im Browser muss die Dev-Domain auch in der `flow.json` des Branches unter `cors.origin` stehen.
  `curl`-Tests funktionieren auch ohne diesen Eintrag. Diese Änderung gehört nicht nach `main`.
- Für mehr Details `"logger": { "level": "DEBUG" }` unter `collector` in der `flow.json` des Branches setzen.
  Das gehört ebenfalls nicht nach `main`, weil das Log dadurch mehr Daten enthält.

## Der Arbeitsablauf für jede Änderung

| Schritt | Wo | Was | Wer prüft |
|---|---|---|---|
| 1 | PC | Branch anlegen, `flow.json` ändern | du oder Claude Code |
| 2 | PC | `flow_validate` mit `strict: true` | MCP |
| 3 | PC | `flow_simulate` für den geänderten Schritt | MCP |
| 4 | Server | Branch in der Dev-Instanz starten, Test-Event senden | Logs |
| 5 | Forgejo | Pull Request, CI muss grün sein | CI |
| 6 | Server | Nach dem Merge in der Produktion `git pull` und `up` | Health und Logs |

Die CI prüft den Build, einen Rauchtest und die Sicherheits-Scans. Ob ein Ziel die Daten **fachlich richtig**
bekommt, prüft sie nicht. Das zeigen nur Schritt 4 und der Bericht im Zielsystem.

## Fehler finden mit MCP und Logs

### Claude Code den Serverzugriff geben

Claude Code liest die Logs per `ssh`. Das setzt einen SSH-Zugang von deinem PC zum Server voraus, am besten
mit einem Eintrag `walkeros-server` in `~/.ssh/config`. Der Zugriff über den Containernamen wirkt nur auf die
gewählte Instanz:

```bash
ssh walkeros-server docker logs --since 1h walkeros-dev-walkerOS 2>&1   # Dev
ssh walkeros-server docker logs --since 1h walkeros-walkerOS 2>&1       # Produktion
```

Claude Code fragt vor `ssh`-Befehlen nach, solange du das nicht freigibst. Prüfe, was es ausführen will:
Lesen ist unkritisch, Änderungen auf dem Server sollten nur mit deiner Zustimmung passieren.

### Was im Log steht

| Meldung | Bedeutung | Vorgehen |
|---|---|---|
| `Push failed ... "step":"destination.x","code":"transport"` | Ziel `x` nicht erreichbar | URL, DNS und Erreichbarkeit vom Server prüfen |
| `Event not processed after ack {"failed":["x"]}` | Event wurde angenommen, kam bei `x` aber nicht an | Meldung davor lesen |
| `Readiness failed: ...` | Flow startet nicht, der Container wird `unhealthy` | Versionen in `flow.json` und `.env` prüfen |
| `does not provide an export named` | Paketversionen passen nicht zusammen | `@walkeros/collector` pinnen, neu bauen |

> **Wichtig: `{"success":true}` heißt nur „angenommen".** Der Browser bekommt die Antwort, auch wenn ein Ziel
> ausfällt. Ob Daten wirklich ankamen, zeigen nur das Log und der Bericht im Zielsystem. Sieh dir daher
> regelmäßig die Logs an.

### Beispiel-Prompts für Claude Code

**Fehler untersuchen:**
> Lies die Logs von `walkeros-dev-walkerOS` der letzten Stunde per ssh und fasse die Fehler nach Ziel zusammen.
> Prüfe danach `flow.json` mit `flow_validate` im Strict-Modus und simuliere das betroffene Ziel. Ändere noch nichts.

**Ein Ziel prüfen:**
> Simuliere mit `flow_simulate` und `verbose: true` ein `order complete`-Event für `destination.meta` und erkläre,
> welche Felder Meta bekommt und welche fehlen. Sende nichts.

**Konfiguration verbessern:**
> Prüfe `flow.json` auf Verbesserungen: Nutze `package_get` für jedes verwendete Paket, vergleiche seine
> Einstellungen und Hinweise mit meiner Konfiguration und liste Consent-Lücken auf. Schlage pro Punkt eine Lösung vor.

**Neues Ziel vorbereiten:**
> Suche mit `package_search` das Pinterest-Ziel für den Server, erkläre die Einstellungen und ergänze es auf einem
> neuen Branch. Validiere und simuliere es, nutze aber nicht `flow_push`.

Daten aus der Produktion können personenbezogen sein. Frage deshalb in Produktionslogs möglichst nur nach
Fehlern und nicht nach kompletten Events.

## Stand dieser Anleitung

**Getestet (lokal, walkerOS 4.9.0, Traefik v3.6):**

- MCP-Start und Tools `flow_validate` und `flow_simulate`, auch mit absichtlich fehlerhafter Konfiguration
- Sendeverhalten von `flow_simulate` und Schutz über `$env`
- Produktiv- und Dev-Instanz nebeneinander, Routing und getrennte Logs
- Log-Meldung bei einem nicht erreichbaren Ziel (mit Log-Level `DEBUG`)

**Nicht getestet:**

- Betrieb auf dem echten Server, mit echten Domains und Zertifikaten
- Zugriff auf die Logs per `ssh`
- `flow_push`, `flow_bundle` und die `package`-Tools
- Log-Meldungen bei einem Ziel-Ausfall im normalen Log-Level; laut walkerOS-Doku erscheint pro Ursache und Minute eine ERROR-Zeile
- Zurückrollen auf einen früheren Stand
- Echte Ziele und `walker.js` im Browser
- Beispiel-Prompts: Sie zeigen die Arbeitsweise und wurden nicht einzeln ausprobiert
<!-- ReadMe-MCP-nutzen.md - walkerOS - ENDE -->
