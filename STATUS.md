<!-- STATUS.md - walkerOS - START -->
# Status

## Aktueller Stand — 2026-11-04

**Aktives Issue:** keines in Arbeit; #1 (Käufe serverseitig mit Token) ist angelegt und folgt später
**Erledigt diese Sitzung:** Grundgerüst, Stack, Origin-Schutz, CI und lokaler MCP auf Branch `feature/initial-stack` angelegt. Die CI ist auf dem Forgejo-Runner grün, Pull Request #2 ist offen.
**Nächster Schritt:** Gegenprobe der CI auf einem Wegwerf-Branch, dann Pull Request #2 mergen. Danach Schritt 4 (GitHub-Mirror, Release-Workflow, Dependabot) und die Matomo-`push`-Funktion gegen eine echte Instanz.

**Blocker / Offene Fragen:**
- Erlaubte Website-Domains, Collector-Domain, Consent-Tool (CMP) und URL der Matomo-Instanz fehlen noch.
- Wie wird `walker.js` statisch ausgeliefert, und sendet sie im echten Browser wie erwartet per POST mit `Origin`?
- Die Zahlenwerte der Ablösekriterien in `Projekt.md` sind noch nicht bestätigt.

**Stolperfallen:**
- Das Image baut nichts: Neben `flow.mjs` müssen auch `package.json` und `node_modules/` mitgeliefert werden. Das erledigt der `Dockerfile`.
- `@walkeros/collector` muss in `flow.json` gepinnt sein. Sonst holt der Bundler die neueste Version, und der Container stürzt beim Start ab, sobald sie nicht zu `@walkeros/core` passt (am 2026-11-04 mit 4.9.0 passiert). Die CI prüft den Pin.
- `cors` als Objekt mit `origin`-Liste, `$code:`-Mappings im API-Ziel und `context.ingest` in `push` sind für 4.9.0 getestet, die `origin`-Liste ist aber nicht dokumentiert. Nach Versions-Updates erneut prüfen.
- Seit 4.9.0 gewähren notwendige Cookies nicht mehr `functional`, und einige CMP-Kategorien wurden neu zugeordnet. Das beim Anbinden des Consent-Tools beachten.
- `walker.js` enthält seit 4.8.1 einen Tag-Mode-Loader, der mit `?elbMoin` ein Skript von `cdn.walkeros.io` lädt, sofern die CSP diesen Host erlaubt. Beim Web-Flow die CSP entsprechend prüfen.
- `$env.NAME` in einer Server-Flow-URL wird erst zur Laufzeit gelesen (getestet): Das Secret steht nicht im Bundle.
- Client-IP und User-Agent gibt es nur in einer eigenen `push`-Funktion über `context.ingest`, dafür braucht die Source `config.ingest` mit `headers.x-real-ip`. Das Mapping und `settings.transform` des API-Ziels sehen sie nicht. Die Form ist `"code": { "push": "$code:..." }`, ein Schlüssel `config` in `code` bricht den Build ab.
- Eine eigene `push`-Funktion muss Fehler und Wiederholungen selbst behandeln. Das Verhalten bei Ausfällen des Ziels ist noch ungetestet.
- Traefik überschreibt gefälschte `X-Real-Ip`-Header (getestet). Das gilt nur, solange der Client nicht aus `forwardedHeaders.trustedIPs` kommt; dort steht aktuell nur `127.0.0.1/32`.
- Der Build-Hinweis `InvalidDefaultArgInFrom` ist harmlos: Er entsteht, weil `WALKEROS_VERSION` keinen Standardwert hat und aus `.env` kommt.
- `docker compose config` zeigt das Regex-Ende als `$$`. Das ist nur die Escape-Darstellung, die Regel greift korrekt.
- Die `ci.yml` der anderen Docker-Stacks nicht kopieren: Sie spiegelt noch nach Codeberg und enthält weder Historien-Scan noch Trivy und Semgrep. Maßgeblich ist die globale `git.md`.

## Streng beachten (prüft kein Test)

- `flow_simulate` sendet bei eigenen `push`-Funktionen wirklich und meldet trotzdem `0/1 destinations received`. Ziel-URLs deshalb nur über `$env` mit leerem Standardwert und Abbruch ohne URL, siehe `ReadMe-MCP-nutzen.md`.
- `{"success":true}` von `/collect` heißt nur „angenommen". Fällt ein Ziel aus, steht das nur im Log.
- In der Dev-Instanz `--env-file .env --env-file .env.dev.local` bei jedem `docker compose`-Befehl angeben, sonst trifft der Befehl die Produktion.
- GTM und walkerOS im Parallelbetrieb nie an dieselbe GA4-Property oder dasselbe Conversion-Label senden, sonst wird doppelt gezählt.
- Der Origin-Schutz stoppt fremde Websites, aber keine Skripte: `Origin` lässt sich außerhalb des Browsers fälschen. Browser-Events sind nie sicher echt.
- Erlaubte Domains an zwei Stellen pflegen: `ALLOWED_ORIGIN_REGEX` in `.env` und `cors.origin` in `flow.json`.
- Client-IP nie aus dem linken Teil von `X-Forwarded-For` übernehmen: Dieser Wert ist fälschbar.
- Die Client-IP nur an Ziele weitergeben, für die das datenschutzrechtlich geklärt ist. Das betrifft besonders Google und Meta. Bei GA4 ist `ip_override` optional.
- API-Secrets und Matomo-Token nur serverseitig per `$env` nutzen, nie in `flow.json` oder im Web-Flow.
- Serverseitiges Tracking ersetzt keine Einwilligung: Vor jedem Live-Gang die Consent-Zuordnung jedes Ziels prüfen (`analytics` bzw. `marketing`).
<!-- STATUS.md - walkerOS - ENDE -->
