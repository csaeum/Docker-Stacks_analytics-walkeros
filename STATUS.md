<!-- STATUS.md - walkerOS - START -->
# Status

## Aktueller Stand — 2026-11-13

**Aktives Issue:** #10 (Mappings für die Events des Sulu-Bundles): Matomo ist umgesetzt und lokal geprüft, Meta und Pinterest sind offen. Danach #11 (Geräte-Kennung als Cookie). #1 (Käufe serverseitig mit Token) folgt später.
**Erledigt:** `flow.json` mappt alle Events des Sulu-Bundles `wsc_sulubundle_walkeros` auf Matomo (Tabelle in `Projekt.md`, Abschnitt „Event-Mapping für Matomo“). Geprüft mit dem echten `walker.js` im Browser und einer lokalen Matomo-Attrappe: Jede Zeile kommt mit den erwarteten Feldern an, `user data` und `session start` gehen nicht an Matomo, Besucher ohne `analytics` erreichen Matomo nicht, und die Suche erzeugt keinen zusätzlichen Seitenaufruf. Matomo live ist nicht geprüft.
**Nächster Schritt:** Nach dem Deploy durch Christian Matomo live prüfen (Site 12: Ereignisse und Outlinks erscheinen, Seitenaufrufe werden nicht doppelt gezählt). Dann Meta und Pinterest (Pixel, Token und Konten kommen als `$env` aus der `.env.local`, nichts davon im Repo).

**Blocker / Offene Fragen:**
- Die Zahlenwerte der Bewährungskriterien in `Projekt.md` sind noch nicht bestätigt.
- **GA4 und Google Ads:** `Projekt.md` lässt sie im GTM-Stack, das Issue #10 nennt „GA4 über gtag“ als Ziel. Das muss Christian entscheiden, bevor dafür etwas gebaut wird. Bis dahin passiert dazu nichts.
- Die Einwilligungs-Anbindung (`web/test-loader.html` ersetzen) liefert jetzt das Sulu-Bundle `wsc_sulubundle_walkeros` mit seinem Loader. Ersetzen lässt sich die Testseite, sobald die Website das Bundle einsetzt.

**Stolperfallen:**
- Eine Matomo-Anfrage mit `search=` zählt Matomo selbst als Seitenaufruf. Deshalb ist die Suche im Mapping ein Ereignis (Begründung in `Projekt.md`).
- Das Mapping lässt sich lokal ohne Matomo prüfen: Als `MATOMO_URL` eine lokale Attrappe setzen, die die Anfragen nur ausgibt. Der `before`-Transformer verwirft jede Herkunft außer der eingetragenen, ein lokaler Test braucht also denselben `Origin` (zum Beispiel über einen kleinen Vorschalter, der ihn setzt).
- Im Mapping braucht ein Wert mit Rückfall die Form `{ "key": "data.type", "value": "file" }`, ein fester Wert `{ "value": 25 }`. Zahlen kommen bei Matomo als Text an (`"25"`), das genügt für `e_v`.
- Matomo lehnt eine Anfrage mit `cip` mit HTTP 400 ab („Tracker API 'cip' was used, requires valid token_auth“), wenn der Benutzer des Tokens auf der Site nur „Ansehen“ darf. Er braucht mindestens „Schreiben“.
- Matomo verlangt für `_id` genau 16 Hex-Zeichen. Die Funktion in `flow.json` kürzt bzw. füllt deshalb auf.
- Ohne `MATOMO_URL` meldet das Matomo-Ziel bei jedem Event „Config settings url missing“. Das ist harmlos, es wird dann nichts gesendet.
- Auf `server-erde` ist der SSH-Benutzer `root`, das Repo gehört `dockeradmin`: `git` dort mit `runuser -u dockeradmin -- git …` ausführen.
- Nach `up -d` liefert `walker.js` etwa 30 Sekunden lang 404, bis der Healthcheck grün ist und Traefik weiterleitet.
- Das Demo-Ziel loggt nur `name`, `data.title` und `timestamp`. Ob Matomo eine Anfrage angenommen hat, steht nicht im Log, nur Fehler.
- Das Image baut nichts: Neben `flow.mjs` müssen auch `package.json` und `node_modules/` mitgeliefert werden. Das erledigt der `Dockerfile`.
- `@walkeros/collector` muss in `flow.json` gepinnt sein. Sonst holt der Bundler die neueste Version, und der Container stürzt beim Start ab, sobald sie nicht zu `@walkeros/core` passt (am 2026-11-04 mit 4.9.0 passiert). Die CI prüft den Pin.
- `$code:`-Mappings im API-Ziel und `context.ingest` in `push` sind für 4.9.0 getestet. Nach Versions-Updates erneut prüfen.
- Seit 4.9.0 gewähren notwendige Cookies nicht mehr `functional`, und einige CMP-Kategorien wurden neu zugeordnet. Das beim Anbinden des Consent-Tools beachten.
- `walker.js` enthält einen Tag-Mode-Loader, in den Schemas der genutzten Pakete steht keine Einstellung zum Abschalten. `?elbMoin` allein lädt nichts (im Browser getestet). Erst eine Nachricht von `https://app.walkeros.io` lädt ein Skript von `cdn.walkeros.io`, geprüft per Hash aus derselben Nachricht. Dagegen hilft nur eine CSP auf der Website, die den Host nicht erlaubt.
- `$env.NAME` in einer Server-Flow-URL wird erst zur Laufzeit gelesen (getestet): Das Secret steht nicht im Bundle.
- Client-IP und User-Agent kommen über `config.ingest` der Source (`headers.x-real-ip`, `headers.user-agent`). Das Mapping und `settings.transform` des API-Ziels sehen `ingest` nicht, deshalb kopiert der `before`-Transformer `requestContext` die Werte auf `user.ip` und `user.userAgent`. Die Form ist `"code": { "push": "$code:..." }`, ein Schlüssel `config` in `code` bricht den Build ab.
- Eine eigene `push`-Funktion muss Fehler und Wiederholungen selbst behandeln. Das Verhalten bei Ausfällen des Ziels ist noch ungetestet.
- Traefik überschreibt gefälschte `X-Real-Ip`-Header (getestet). Das gilt nur, solange der Client nicht aus `forwardedHeaders.trustedIPs` kommt; dort steht aktuell nur `127.0.0.1/32`.
- Der Build-Hinweis `InvalidDefaultArgInFrom` ist harmlos: Er entsteht, weil `WALKEROS_VERSION` keinen Standardwert hat und aus `.env` kommt.
- `docker compose config` zeigt das Regex-Ende als `$$`. Das ist nur die Escape-Darstellung, die Regel greift korrekt.
- Die `ci.yml` der anderen Docker-Stacks nicht kopieren: Sie spiegelt noch nach Codeberg und enthält weder Historien-Scan noch Trivy und Semgrep. Maßgeblich ist die globale `git.md`.

## Streng beachten (prüft kein Test)

- `ironman.*` ist die laufende Matomo-Instanz auf `server-erde`. Der Collector darf diese Hosts nie belegen, er läuft unter `fury.*`.
- Das Repo ist öffentlich. Interne Angaben und Secrets gehören nur in die `.env.local` auf dem Server.
- Die Shops haben bereits GTM und Matomo eingebunden. walkerOS im Test deshalb nur an Site 12 senden und `walker.js` nur mit Test-Cookie laden.
- `flow_simulate` sendet bei eigenen `push`-Funktionen wirklich und meldet trotzdem `0/1 destinations received`. Ziel-URLs deshalb nur über `$env` mit leerem Standardwert und Abbruch ohne URL, siehe `ReadMe-MCP-nutzen.md`.
- `{"success":true}` von `/collect` heißt nur „angenommen". Fällt ein Ziel aus, steht das nur im Log.
- In der Dev-Instanz `--env-file .env --env-file .env.dev.local` bei jedem `docker compose`-Befehl angeben, sonst trifft der Befehl die Produktion.
- GTM und walkerOS im Parallelbetrieb nie an dieselbe GA4-Property oder dasselbe Conversion-Label senden, sonst wird doppelt gezählt.
- Der Origin-Schutz stoppt fremde Websites, aber keine Skripte: `Origin` lässt sich außerhalb des Browsers fälschen. Browser-Events sind nie sicher echt.
- `web/test-loader.html` ist nur zum Testen: Wer das Cookie setzt, erteilt seine eigene Einwilligung. Vor dem öffentlichen Einsatz muss cookieconsent angebunden sein.
- `walker.js` sendet die komplette Seitenadresse samt Query-Parametern an den Collector. Vor dem Anbinden der Ziele prüfen, ob dort personenbezogene Parameter vorkommen.
- Client-IP nie aus dem linken Teil von `X-Forwarded-For` übernehmen: Dieser Wert ist fälschbar.
- Die Client-IP nur an Ziele weitergeben, für die das datenschutzrechtlich geklärt ist. Das betrifft besonders Google und Meta. Bei GA4 ist `ip_override` optional.
- API-Secrets und Matomo-Token nur serverseitig per `$env` nutzen, nie in `flow.json` oder im Web-Flow.
- Serverseitiges Tracking ersetzt keine Einwilligung: Vor jedem Live-Gang die Consent-Zuordnung jedes Ziels prüfen (`analytics` bzw. `marketing`).
<!-- STATUS.md - walkerOS - ENDE -->
