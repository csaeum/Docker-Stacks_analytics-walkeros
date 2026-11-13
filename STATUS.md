<!-- STATUS.md - walkerOS - START -->
# Status

## Aktueller Stand — 2026-11-13

**Aktives Issue:** #10 (Mappings für die Events des Sulu-Bundles): Matomo ist umgesetzt und lokal geprüft, GA4 (gtag im Browser) ist lokal geprüft, Meta und Pinterest sind offen. #11 (Geräte-Kennung als Cookie) ist für die Sulu-Seite umgesetzt und lokal geprüft, der Shop-Teil (Kennung vorgeben) wartet auf Sylius. #1 (Käufe serverseitig mit Token) folgt später.
**Erledigt:** `flow.json` mappt alle Events des Sulu-Bundles `wsc_sulubundle_walkeros` auf Matomo (Tabelle in `Projekt.md`, Abschnitt „Event-Mapping für Matomo“). Geprüft mit dem echten `walker.js` im Browser und einer lokalen Matomo-Attrappe: Jede Zeile kommt mit den erwarteten Feldern an, `user data` und `session start` gehen nicht an Matomo, Besucher ohne `analytics` erreichen Matomo nicht, und die Suche erzeugt keinen zusätzlichen Seitenaufruf. Seit 2026-11-13 läuft das auch lokal gegen ein echtes Matomo (`docs/lokal.md`): Ereignisse (CTA, Accordion, Scroll, Engagement) und Seitenaufrufe aus der Sulu-Testseite im Browser kommen in Matomo an, Events ohne `analytics` oder von fremder Herkunft nicht. Live (`ironman`): ein Test-`page view` kam an, `cta click` nicht, vermutlich läuft dort noch ein älterer `flow.json`.
**Nächster Schritt:** Christian deployt den aktuellen `main` auf `server-erde` (`git pull`, `docker compose --env-file .env --env-file .env.local up -d --build`; neue Variable `MATOMO_ORIGIN` ist optional, Standard ist die Produktions-Website). Danach Matomo live erneut prüfen. Dann Meta und Pinterest im Browser (`@walkeros/web-destination-meta` und `-pinterest` gibt es in 4.9.0; nur die Pixel-IDs, Server-Token später als `$env`, nichts davon im Repo). Sylius-Teil der lokalen Umgebung folgt mit dem Sylius-Bundle.

**Blocker / Offene Fragen:**
- Die Zahlenwerte der Bewährungskriterien in `Projekt.md` sind noch nicht bestätigt.
- **GA4 (entschieden 2026-11-13: über walkerOS im Browser):** Lokal läuft das gtag-Ziel im Echtlauf (Realtime der Test-Property zeigt `page_view`, `cta_click`, Scroll- und Engagement-Events). **Mess-ID je Website (Prototyp lokal geprüft):** Das Sulu-Bundle hängt die ID an die Adresse (`walker.js?ga4=G-…`), nginx setzt sie anstelle des Platzhalters `G-XXXXXXXXXX` ein (nur Werte der Form `G-[A-Z0-9]{4,20}`, sonst bleibt der Platzhalter). Das Ziel ist nur aktiv, wenn der Einwilligungsschlüssel `ga4` gesetzt ist; mehrere Schlüssel einer `consent`-Angabe gelten als „oder“, deshalb setzt der Lader `ga4 = analytics und ID vorhanden`. **Offen:** Der Lader im Sulu-Bundle muss `ga4` setzen und die ID anhängen. In der GA4-Web-Datenquelle „Erweiterte Messung“ die Option „Scrollen“ abschalten, sonst zählt GA4 zusätzlich sein eigenes `scroll` (90 %). Google Ads bleibt im GTM-Stack.
- Die Einwilligungs-Anbindung (`web/test-loader.html` ersetzen) liefert jetzt das Sulu-Bundle `wsc_sulubundle_walkeros` mit seinem Loader. Ersetzen lässt sich die Testseite, sobald die Website das Bundle einsetzt.

**Stolperfallen:**
- **Geräte-Kennung als Cookie (#11):** Die Session-Quelle speichert die Kennung mit `deviceStorage: "cookie"` (Name `elbDeviceId`, 30 Tage über `deviceAge`), damit der Server sie beim Wechsel in den Shop lesen kann. Das Cookie setzt `walker.js` mit `path=/; SameSite=Lax; secure`, ohne `domain` und ohne `HttpOnly` (es entsteht im Browser). Lokal geprüft: ohne Einwilligung kein Cookie, mit Einwilligung ein Cookie, dessen Wert die `_id` in Matomo ergibt, und beim Widerruf entfernt es der Consent-Banner (Cookie-Liste `elbDeviceId`, Kategorie `analytics`). Das Bundle `walker.js` liegt 1 Stunde im Browser-Cache, nach einem Neubau mit `fetch(url, {mode: 'no-cors', cache: 'reload'})` auffrischen.
- Eine Matomo-Anfrage mit `search=` zählt Matomo selbst als Seitenaufruf. Deshalb ist die Suche im Mapping ein Ereignis (Begründung in `Projekt.md`).
- Lokal gibt es eine komplette Umgebung mit echtem Matomo (`docs/lokal.md`, `lokal/lokal.sh up`). Die Herkunft, deren Events an Matomo gehen, kommt aus `MATOMO_ORIGIN` (Standard im Compose: die Produktions-Website, lokal die DDEV-Testseite). Der `before`-Transformer `requestContext` verwirft jede andere Herkunft und gibt `false` zurück. **Ein `$env.…` im `match`-Wert eines Transformers wird nicht aufgelöst** (bleibt als Text im Bundle stehen, alles wird verworfen); deshalb steht die Prüfung in `push` über `process.env`.
- `docker compose up --build` meldet bei einem fehlgeschlagenen Bundle-Schritt den Fehler nur weit oben; ein Skript, das die Ausgabe kürzt, startet dann stillschweigend mit dem alten Image. Nach jedem Build prüfen, dass er durchlief (Fehler in `flow.json`, zum Beispiel unmaskierte Anführungszeichen in `$code:`).
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
- Client-IP und User-Agent kommen über `config.ingest` der Source (`headers.x-real-ip`, `headers.user-agent`). Das Mapping und `settings.transform` des API-Ziels sehen `ingest` nicht, deshalb prüft und kopiert der `before`-Transformer `requestContext` die Werte auf `user.ip` und `user.userAgent`. Die Form ist `"code": { "push": "$code:..." }`, ein Schlüssel `config` in `code` bricht den Build ab.
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
