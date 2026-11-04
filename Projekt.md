<!-- Projekt.md - walkerOS - START -->
# Docker Stack: walkerOS – Event-Collector & Tag-Management

Selbst gehosteter walkerOS-Stack. Ziel ist **ein einziges Werkzeug**, in dem alle Tracking-Ziele
konfiguriert werden, und **möglichst kein Tracking-Skript von Drittanbietern im Browser**. Bewährt
sich der Stack, löst er
[`analytics-gtm-sstm-projekt`](https://git.web-seo-consulting.eu/Docker-Stacks/analytics-gtm-sstm-projekt)
ab. Bis dahin bleibt der GTM-Stack unverändert in Betrieb.

## Aufbau

```
Browser                                     Server (dieser Stack)
walker.js ── Events an /collect ──► Traefik ──► walkeros/flow (Port 8080)
                                  (Origin-Liste,  ├─► Matomo Tracking API
                                   Rate-Limit)    ├─► GA4 Measurement Protocol
                                                  ├─► Meta Conversions API
Shop-Backend ── Käufe mit Token (Issue #1) ──►    ├─► Pinterest API
                                                  └─► Google Data Manager (Ads)
```

- **Server-Flow:** `flow.json` wird mit `@walkeros/cli` gebaut (Node.js ≥ 22.12). Das Image
  `walkeros/flow` führt nur fertige Bundles aus und lehnt eine `flow.json` ab.
- **Web-Flow:** eigenes Bundle `walker.js`, das statisch ausgeliefert werden muss. Es ist weiterhin
  JavaScript im Browser, sendet aber nur an den eigenen Collector. Die Auslieferung ist noch offen.
- **Betrieb:** Routing und TLS über Traefik, Self-Healing über Autoheal, Health über `/ready`
  (nur intern). Nur eine Instanz betreiben: Der Standard-Store liegt im Speicher des Prozesses.

## Tracking-Ziele

| Ziel | Status | Weg | Stand |
|---|---|---|---|
| Matomo | neu | Tracking-HTTP-API über eigene `push`-Funktion in `flow.json` | Format und IP am Testempfänger geprüft, echte Instanz offen |
| Google Analytics 4 | ersetzt GTM | Measurement Protocol über eigene `push`-Funktion in `flow.json` | Format und IP am Testempfänger geprüft, echte Property offen |
| Google Ads | ersetzt GTM | `@walkeros/server-destination-datamanager` | ungetestet, nur Events mit `transactionId` |
| Meta (Facebook, Instagram) | neu | `@walkeros/server-destination-meta` | ungetestet |
| Pinterest | neu | `@walkeros/server-destination-pinterest` | ungetestet |

Reicht ein Server-Weg im Parallelbetrieb nicht aus, bleibt für das Ziel das Browser-Paket als
Rückfallebene (`@walkeros/web-destination-gtag`, `-matomo`, `-meta`, `-pinterest`).

## Entscheidungen

- **Server vor Browser.** Tracking-Daten laufen möglichst nur über den eigenen Collector, weil keine
  Drittanbieter-Skripte im Browser geladen werden sollen.
- **Matomo und GA4 über eine eigene `push`-Funktion.** Nur sie erhält `context.ingest` mit Client-IP
  und User-Agent. `@walkeros/server-destination-api` reicht das weder an das Mapping noch an
  `settings.transform` weiter (getestet mit 4.8.2).
- **GA4 ist der riskanteste Weg.** Google schreibt zum Measurement Protocol: „The intent of the
  Measurement Protocol is to augment automatic collection through gtag, Tag Manager, and Google
  Analytics for Firebase, not to replace it." Fehlerhafte Daten meldet die API nicht als Fehler.
  Ob die Berichte brauchbar sind, muss der Parallelbetrieb zeigen.
- **Google Ads nur für Conversions über den Server.** Die Data Manager API sendet nur Events mit
  `transactionId`. Remarketing und Zielgruppen sind damit nicht abgedeckt.
- **`/collect` nimmt nur Browser-Anfragen von erlaubten Domains an.** Traefik prüft `Origin` und
  Methode und begrenzt die Anfragen pro IP. Skripte können `Origin` fälschen, deshalb sollen Käufe
  nur vom Shop-Backend kommen (Issue #1).

## Ablösung des GTM-Stacks

Der GTM-Stack wird erst abgeschaltet, wenn alle Punkte erfüllt sind. Die Zahlenwerte sind
Vorschläge und noch nicht bestätigt.

- [ ] Mindestens 4 Wochen Parallelbetrieb ohne Ausfall des Collectors
- [ ] GA4: Seitenaufrufe und Events weichen höchstens 5 % von der GTM-Property ab
- [ ] GA4: Sitzungen, Quellen und Geräte sind in den Berichten brauchbar
- [ ] Google Ads: Conversions kommen an und weichen höchstens 5 % ab
- [ ] Consent: Ohne Einwilligung geht nachweislich kein Event an das jeweilige Ziel

**Im Parallelbetrieb nie dieselbe Property nutzen:** Senden GTM und walkerOS an dieselbe
GA4-Property oder dasselbe Conversion-Label, werden die Daten doppelt gezählt. walkerOS bekommt
dafür eine eigene GA4-Test-Property.

Nach der Ablösung: GTM-Skript aus den Websites entfernen, GTM-Stack stoppen und das Repo archivieren.

## Doku

- walkerOS: <https://www.walkeros.io/docs/>
- Image: <https://hub.docker.com/r/walkeros/flow>
- Releases: <https://github.com/elbwalker/walkerOS/releases>
- GA4 Measurement Protocol: <https://developers.google.com/analytics/devguides/collection/protocol/ga4>
- Matomo Tracking API: <https://developer.matomo.org/api-reference/tracking-api>
<!-- Projekt.md - walkerOS - ENDE -->
