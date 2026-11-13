# Geräte-Kennung: Cookie und Übernahme im Shop (#11)

Ein Besucher behält beim Wechsel von der Sulu-Website in den Shop dieselbe walkerOS-Geräte-Kennung
(`user.device`), auch über verschiedene Registrierbar-Domains hinweg.

## Website: Cookie `elbDeviceId`

Die Session-Quelle (`@walkeros/web-source-session` 4.9.0) speichert die Kennung mit `deviceStorage: "cookie"`.

| Eigenschaft | Wert |
|---|---|
| Name | `elbDeviceId` |
| Laufzeit | 30 Tage (`deviceAge`) |
| Attribute | `path=/`, `SameSite=Lax`, `secure`, ohne `domain`, ohne `HttpOnly` (es entsteht im Browser) |
| Kategorie | `analytics` (die Quelle läuft nur mit `analytics` oder `marketing`) |
| Widerruf | Der Consent-Banner entfernt das Cookie (Cookie-Liste `elbDeviceId`) |

Ohne `domain` gilt das Cookie nur für die Domain der Website. Der Server der Website kann es lesen und für
den Wechsel in den Shop in einen signierten Token schreiben (Sulu-Bundle `wsc_sulubundle_walkeros` #24).

## Shop: vorgegebene Kennung übernehmen

**Ergebnis (aus dem Quelltext von 4.9.0 gelesen und im Browser geprüft):** Die Session-Quelle liest `elbDeviceId`
aus dem Speicher und erzeugt nur dann eine neue Kennung, wenn dort nichts steht. Die gelesene Kennung gewinnt
auch gegen eine im Session-Eintrag (`elbSessionId`) gespeicherte. Danach ruft die Quelle `walker user` mit
dieser Kennung auf.

Der Shop setzt deshalb das Cookie **vor** dem ersten Aufruf von `walker.js`, also beim Annehmen des Tokens:

```
elbDeviceId=<Kennung>; path=/; max-age=2592000; SameSite=Lax; secure
```

- Nur setzen, wenn der Token eine Kennung enthält (Einwilligung `analytics` oder `marketing` lag auf der Website vor).
- Format vor dem Setzen prüfen: 16 Zeichen aus `A–Z`, `a–z`, `0–9`. Alles andere verwerfen.
- Der Weg über `elb('walker user', { device: '…' })` ist nicht nötig. Die Session-Quelle überschreibt ihn ohnehin mit
  dem Wert aus dem Speicher.
- Ein bereits vorhandenes Cookie im Shop wird überschrieben, damit Website und Shop dieselbe Kennung führen.

**Geprüft (2026-11-13, lokal):** Cookie `elbDeviceId` vor dem Laden der Seite gesetzt, Einwilligung vorhanden.
Alle Events der Seite tragen diese Kennung in `user.device`, das Cookie bleibt unverändert erhalten.

## Widerruf

Laut Doku entfernt ein Widerruf die Kennung nicht aus dem Speicher. Das Cookie löscht deshalb der Consent-Banner
(Website: `wsc_sulubundle_orestbidacookieconsent`, Shop: `wsc_syliusbundle_consentanalytics` #17).
