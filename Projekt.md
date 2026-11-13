<!-- Projekt.md - walkerOS - START -->
# Docker Stack: walkerOS – Event-Collector & Tag-Management

Selbst gehosteter walkerOS-Stack für **Matomo, Meta und Pinterest**. Die Daten laufen über den eigenen
Collector, im Browser läuft dafür nur `walker.js`. **GA4 und Google Ads bleiben vorerst im Stack**
[`analytics-gtm-sstm-projekt`](https://git.web-seo-consulting.eu/Docker-Stacks/analytics-gtm-sstm-projekt),
der unverändert weiterläuft. Eine vollständige Ablösung ist derzeit nicht geplant.

## Aufbau

```
Browser                                       Server (dieser Stack)
walker.js ── Events an fury.<domain>/collect ──► Traefik ──► walkeros/flow (Port 8080)
                                    (Host, Origin-Liste,      ├─► Matomo Tracking API
                                     Rate-Limit)              ├─► Meta Conversions API
Shop-Backend ── Käufe mit Token (Issue #1) ──►                └─► Pinterest API

GTM-Loader ── GA4 und Google Ads ──► GTM-Stack (getrennt)
```

- **Server-Flow:** `flow.json` wird mit `@walkeros/cli` gebaut (Node.js ≥ 22.12). Das Image
  `walkeros/flow` führt nur fertige Bundles aus und lehnt eine `flow.json` ab.
- **Web-Flow:** Der Dienst `walker` liefert `https://fury.<domain>/walker.js` aus `web/flow.web.json` aus.
  Es gibt ein Bundle für alle Domains, nginx setzt beim Ausliefern den aufgerufenen Host als Collector ein.
  Websites binden nur das Skript ein und kopieren keine Datei. `web/test-loader.html` lädt es zum Testen
  nur mit Test-Cookie.
- **Betrieb:** Routing und TLS über Traefik, Self-Healing über Autoheal, Health über `/ready`
  (nur intern). Nur eine Instanz betreiben: Der Standard-Store liegt im Speicher des Prozesses.

## Domains

| Collector | Website | Stand |
|---|---|---|
| `fury.shop-a.example` | `https://shop-a.example` | zuerst testen |
| `fury.shop-b.example` | `https://shop-b.example` | zuerst testen |
| `fury.shop-c.example` | `https://shop-c.example` | Shop im Wartungsmodus |
| `fury.web-seo-consulting.eu` | `https://web-seo-consulting.eu` | bereit |
| `fury.site-e.example` | `https://site-e.example` | bereit |
| `fury.shop-d.example` | `https://shop-d.example` | bereit |

Die Collector-Hosts stehen in `HOSTRULE`, die Websites in `ALLOWED_ORIGIN_REGEX`.

## Tracking-Ziele

| Ziel | Weg | Stand |
|---|---|---|
| Matomo | `@walkeros/server-destination-api` mit `before`-Transformer | `page view` live mit `idSite=12` geprüft (`web-seo-consulting.eu`); alle Events des Sulu-Bundles gemappt (siehe unten), lokal gegen eine Matomo-Attrappe geprüft, live offen |
| Meta (Facebook, Instagram) | `@walkeros/server-destination-meta` | Auswahl des Pixels je Domain geprüft, echte Konten offen |
| Pinterest | `@walkeros/server-destination-pinterest` | ungetestet, Auswahl je Domain nur mit dem API-Paket geprüft |

### Event-Mapping für Matomo

Die Events kommen aus dem Sulu-Bundle `wsc_sulubundle_walkeros` (verbindlich ist dessen `docs/events.md`).
Das Matomo-Ziel bekommt sie nur mit `consent.analytics`. Alles, was nicht in der Tabelle steht (`user data`,
`session start`, Shop-Events), wird für Matomo verworfen.

| Event | Matomo-Anfrage |
|---|---|
| `page view` | Seitenaufruf mit `action_name` (Titel) |
| `search view` | Ereignis `Search` / `query` / Suchbegriff |
| `file download` | Ereignis `Download` / Dateityp (ohne Typ `file`) / Dateiname |
| `link outbound` | Outlink `link=https://<host>` (nur der Host, Pfad und Query fehlen schon im Event) |
| `contact click` | Ereignis `Contact` / `mail` bzw. `tel` |
| `cta click` | Ereignis `CTA` / `click` / Name |
| `teaser click`, `teaser visible` | Ereignis `Teaser` / `click` bzw. `visible` / Name |
| `accordion toggle` | Ereignis `Accordion` / `toggle` / Name |
| `share click` | Ereignis `Share` / `click` |
| `form submit` | Ereignis `Form` / `submit` (ohne Feldinhalte) |
| `newsletter signup` | Ereignis `Newsletter` / `signup` |
| `video start`, `progress`, `complete` | Ereignis `Video` / `start`, `progress`, `complete` / `<Anbieter>:<ID>`, bei `progress` mit dem Prozentwert als Wert |
| `page scroll_25` bis `scroll_100` | Ereignis `Scroll` / `depth` / Wert 25 bis 100 |
| `page engaged_15`, `engaged_30`, `engaged_60` | Ereignis `Engagement` / `seconds` / Wert 15, 30, 60 |

- **Die Suche ist ein Ereignis und kein Matomo-Site-Search.** Eine Anfrage mit `search=` zählt Matomo selbst als
  Seitenaufruf. Zusammen mit dem `page view` der Ergebnisseite würde jede Suche zwei Aufrufe ergeben und die
  Zahlen um mehr als die erlaubten 5 % verfälschen. Der Bericht „Site Search“ in Matomo bleibt dadurch leer,
  die Suchbegriffe stehen unter „Ereignisse“.
- **Downloads sind Ereignisse und kein Matomo-Download.** Der Download-Bericht braucht die vollständige Adresse der
  Datei, das Event trägt nur Name, Typ und ID.

## Entscheidungen

- **GA4 und Google Ads bleiben im GTM-Stack.** Google schreibt zum Measurement Protocol: „The intent
  of the Measurement Protocol is to augment automatic collection through gtag, Tag Manager, and Google
  Analytics for Firebase, not to replace it." Der walkerOS-Maintainer bestätigt das und nennt auch GA4
  über den Data Manager nur eine Ergänzung zum Tag
  ([Diskussion 757](https://github.com/elbwalker/walkerOS/discussions/757)).
- **Jedes Ziel läuft nur über einen Stack.** Sonst wird doppelt gezählt.
- **Matomo über das API-Paket statt über eine eigene `push`-Funktion.** Ein `before`-Transformer gibt
  IP und User-Agent nur an dieses Ziel weiter (mit 4.9.0 live getestet). Adresse und Token kommen per
  `$env` aus der `.env.local` auf dem Server, weil das Repo öffentlich ist. Eine weitere Matomo-Instanz
  bekommt ein eigenes Ziel mit eigenen Variablen.
- **Ein Stack für alle Domains.** Alle Domains gehören demselben Betreiber. Der Collector wählt IDs und
  Ziele anhand von `Origin` aus und verwirft unbekannte Herkunft (mit 4.9.0 getestet). Dafür fällt bei
  einem Fehler das Tracking aller Domains gemeinsam aus.
- **Eigene Collector-Subdomain je Website.** Die Daten laufen über eine Subdomain der jeweiligen Website.
- **`walker.js` kommt aus dem Stack.** So kann niemand vergessen, eine neue Version auf die Websites zu
  kopieren. Der Preis: Ein Fehler im Stack trifft sofort alle Domains, und ein fester Integritäts-Hash auf
  der Website ist nicht möglich. Die CI prüft deshalb die ausgelieferte Datei.
- **Kein `cors`-Block im Collector.** `walker.js` sendet per Beacon als `text/plain` ohne CORS-Prüfung, der
  Browser schickt dabei `Origin` mit (getestet). Zugriffskontrolle ist allein die `Origin`-Prüfung in Traefik.
- **`/collect` nimmt nur Browser-Anfragen von erlaubten Domains an.** Traefik prüft Host, `Origin` und
  Methode und begrenzt die Anfragen pro IP. `docker-compose.yml` klammert `HOSTRULE`, weil die
  Prüfungen sonst nur für den letzten Host gelten (getestet). Skripte können `Origin` fälschen, deshalb
  sollen Käufe nur vom Shop-Backend kommen (Issue #1).

## Bewährung für Matomo

Das bisherige Matomo-Tracking der Shops wird erst entfernt, wenn alle Punkte erfüllt sind. Die
Zahlenwerte sind Vorschläge und noch nicht bestätigt.

- [ ] Mindestens 4 Wochen Parallelbetrieb ohne Ausfall des Collectors
- [ ] Matomo: Seitenaufrufe und Bestellungen weichen höchstens 5 % von der bisherigen Site ab
- [ ] Consent: Ohne Einwilligung geht nachweislich kein Event an das jeweilige Ziel

**Im Parallelbetrieb nie dieselbe Site nutzen:** Senden das bisherige Tracking und walkerOS an dieselbe
Matomo-Site, werden die Daten doppelt gezählt. walkerOS sendet im Test deshalb nur an `idSite=12`.

## Doku

- walkerOS: <https://www.walkeros.io/docs/>
- Image: <https://hub.docker.com/r/walkeros/flow>
- Releases: <https://github.com/elbwalker/walkerOS/releases>
- Matomo Tracking API: <https://developer.matomo.org/api-reference/tracking-api>
<!-- Projekt.md - walkerOS - ENDE -->
