<!-- inbetriebnahme.md - walkerOS - START -->
# Checkliste: Inbetriebnahme des Kauf-Pfads

Für den Stack-Betreiber, bevor der Shop echte Käufe sendet (Shop-Bundle `wsc_syliusbundle_walkeros`, Issue #19 dort).
Domains und Werte stehen hier nur als Platzhalter (`collect.example.com`, `<…>`); echte Werte gehören in die `.env.local` auf
dem Server, nie ins Repo. Hintergrund zu jedem Punkt: [`capi.md`](capi.md).

## 1. Vor dem Start

- [ ] **Collector-Domain** (`HOSTRULE`) zeigt per DNS auf den Server, Zertifikat über Traefik (`letsEncrypt`) wird ausgestellt.
- [ ] **`PURCHASE_TOKEN`** in der `.env.local` setzen: langer Zufallswert (z. B. `openssl rand -hex 32`). Derselbe Wert kommt im
      Shop als Umgebungsvariable zu `server.token`. Nie in Chat, Ticket oder Repo schreiben.
- [ ] **Matomo:** `MATOMO_URL`, `MATOMO_TOKEN_AUTH` (Benutzer mit Schreibrecht auf die Site, nötig für `cip`) und `MATOMO_ORIGIN`
      (Adresse der Website, von der die Browser-Events kommen) setzen.
- [ ] **Matomo-Site-ID prüfen:** In `flow.json` steht `idsite` derzeit **fest auf 12**, das ist die Test-Site der lokalen
      Umgebung. Für die Produktion die richtige Site-ID eintragen (oder per Umgebungsvariable lösbar machen, eigenes Issue).
- [ ] **Matomo Ecommerce** für diese Site einschalten (Websites verwalten → Ecommerce). Sonst bleibt der Kauf ohne Wirkung in den
      Ecommerce-Berichten.
- [ ] **Meta:** `META_1_ORIGIN`, `META_1_PIXEL_ID` (dieselbe ID wie im Sulu-Admin), `META_1_ACCESS_TOKEN`.
- [ ] **Pinterest:** `PINTEREST_1_ORIGIN`, `PINTEREST_1_AD_ACCOUNT_ID`, `PINTEREST_1_ACCESS_TOKEN`.
- [ ] Images neu bauen, weil `flow.json` beim Build ins Bundle wandert:
      `docker compose --env-file .env --env-file .env.local up -d --build`. Status muss `healthy` sein.

## 2. Pfad und Router prüfen (ohne Shop)

Der Router `…-purchase` nimmt nur POST auf `/purchase` an, mit Rate-Limit. Die Zugangskontrolle ist das Token.

```bash
# ohne Token: 401 (503, wenn PURCHASE_TOKEN auf dem Server fehlt)
curl -i -X POST https://collect.example.com/purchase -H 'Content-Type: application/json' -d '{}'
# GET darf den Pfad nicht erreichen (kein /purchase-Router): 404
curl -i https://collect.example.com/purchase
# `/collect` des Browsers antwortet weiter wie bisher
```

- [ ] POST ohne Token → **401**, nicht 503 (503 heißt: `PURCHASE_TOKEN` fehlt im Container).
- [ ] GET auf `/purchase` → **404**.
- [ ] Rate-Limit greift (viele Aufrufe in kurzer Zeit → 429).

## 3. Meta und Pinterest im Testmodus

- [ ] **Meta:** Events Manager → Testereignisse → Testcode als `META_1_TEST_EVENT_CODE` setzen, Stack neu starten.
- [ ] **Pinterest:** `PINTEREST_1_TEST=true` setzen (Testendpunkt, nichts wird gespeichert).
- [ ] Testbestellung im Shop (Marketing-Einwilligung **und** „Serverseitig senden“ im Webspace eingeschaltet). Erwartet:
      Meta zeigt `Purchase` mit Quelle „Server“, Pinterest meldet in der Antwort die Prüfung als gültig.
- [ ] **Dubletten:** dieselbe Bestellung ein zweites Mal senden (Shop wiederholt, oder Aufruf mit demselben Body). Meta und
      Pinterest dürfen sie nicht doppelt zählen (`event_id`, `order_id`).
- [ ] Prüfen, dass **IP und User-Agent der Kundin bzw. des Kunden** ankommen, nicht die des Shop-Servers
      (setzt `trusted_proxies` im Shop voraus, siehe Shop-Doku „Proxy und Kunden-IP“).
- [ ] **Danach Testcode und `PINTEREST_1_TEST` wieder leeren** und neu starten, sonst gehen keine echten Käufe durch.

## 4. Matomo

- [ ] Testbestellung nur mit **Analyse-Einwilligung**: Der Kauf erscheint unter Ecommerce → Bestellungen mit Bestell-ID,
      Umsatz, Steuer, Versand und Produkten. Meta und Pinterest bekommen dabei nichts.
- [ ] Besucher-ID entspricht der aus dem Browser (gleiche Geräte-Kennung).
- [ ] Aufrufe ohne User-Agent verwirft Matomo. Fehlt der Kauf in Matomo, zuerst prüfen, ob der Shop `userAgent` mitsendet.

## 5. Ende zu Ende

- [ ] Eine echte Testbestellung vom Sulu-Übergang bis zum Zahlungsstatus „bezahlt“. Das Event kommt **einmal** an; im
      Container-Log steht kein 401/400/500.
- [ ] Browser-`order complete` zählt für Meta, Pinterest und Matomo nicht (kein doppelter Kauf).
- [ ] GA4 meldet den Kauf aus dem Browser (kann der Stack nicht unterdrücken).
- [ ] Bestellung ohne Einwilligung → im Collector kommt nichts an.

## 6. Fehlerbilder

| Antwort / Symptom | Ursache |
|---|---|
| 503 auf `/purchase` | `PURCHASE_TOKEN` fehlt im Container (`.env.local`, Neustart). |
| 401 | Token im Shop und Stack verschieden. |
| 400 | Event ist nicht `order complete` oder hat keine Bestell-ID. |
| 500 | Ein Ziel hat die Zustellung abgelehnt; der Shop wiederholt über Messenger. |
| Kauf fehlt in Matomo | Ecommerce aus, falsche `idsite`, kein `userAgent`, `MATOMO_TOKEN_AUTH` ohne Rechte. |
| Kauf fehlt bei Meta/Pinterest | Kein `metaServer`/`pinterestServer` im Event (Marketing + Schalter fehlen), Token oder ID leer. |
| Alle Käufe mit gleicher IP | `trusted_proxies` im Shop fehlt. |
<!-- inbetriebnahme.md - walkerOS - ENDE -->
