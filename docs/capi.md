<!-- capi.md - walkerOS - START -->
# Meta Conversions API und Pinterest API (serverseitig)

Zusätzlich zu den Browser-Zielen (`flow.web.json`) schickt der Collector (`flow.json`) dieselben Shop-Events
serverseitig an Meta und Pinterest. Die Event-ID ist die von `walker.js` vergebene und damit **dieselbe wie im Browser**,
so führen Meta und Pinterest Browser- und Server-Ereignis zu einem zusammen. Das hilft bei Werbeblockern und
Safari-Einschränkungen.

## Was gesendet wird

| walkerOS-Event | Meta (`event_name`) | Pinterest (`event_name`) |
|---|---|---|
| `page view` | `PageView` | nicht gesendet (der Browser-Tag macht es) |
| `product view` | `ViewContent` | `page_visit` |
| `product add` | `AddToCart` | `add_to_cart` |
| `list view` | nicht gesendet | `view_category` |
| `order start` | `InitiateCheckout` | nicht gesendet |
| `checkout step` (Schritt `payment`) | `AddPaymentInfo` | nicht gesendet |
| `order complete` | `Purchase` (`order_id` = Bestellnummer) | `checkout` (`order_id`) |

Alles andere wird verworfen. Beträge als Zahl (Meta) bzw. Text mit zwei Nachkommastellen (Pinterest), Währung `EUR`,
Positionen als `contents`. Es gehen keine Formularinhalte und keine Klartext-Kontaktdaten raus.

`user_data`: Client-IP und User-Agent (Pflicht für die Zuordnung), dazu die Klick-Kennungen aus den Cookies
`_fbp` und `_fbc` (Meta) bzw. `_epik` (Pinterest). Aus dem Cookie-Header liest der Collector **nur diese Namen**, der Rest wird
verworfen. Die gehashte E-Mail für den erweiterten Abgleich ist noch nicht angebunden.
**Datenschutz:** IP und User-Agent gehen an Meta bzw. Pinterest. Wer das nicht will, setzt in den `settings` des Ziels
`"ip": false` und `"userAgent": false` (Meta verlangt den User-Agent für Website-Ereignisse, die Zuordnung leidet dann).

## Wann ein Event rausgeht

Alle Bedingungen müssen stimmen:

1. Die `Origin` der Anfrage steht in `META_1_ORIGIN` bzw. `PINTEREST_1_ORIGIN` (Liste, mit Komma getrennt).
2. Der Einwilligungsschlüssel `meta` bzw. `pinterest` ist im Event `true`. Den setzt das Sulu-Bundle nur mit
   Marketing-Einwilligung **und** gepflegter Pixel-/Tag-ID des Webspaces. Ohne Marketing-Einwilligung geht nichts raus.
3. Token und ID sind in der `.env.local` gesetzt. Sind sie leer (Standard), läuft der Collector normal weiter und
   sendet nichts an das Ziel.

## Konfiguration (`.env.local` auf dem Server, nie im Repo)

```
META_1_ORIGIN=https://example.com
META_1_PIXEL_ID=1234567890
META_1_ACCESS_TOKEN=<Token aus dem Events Manager>
META_1_TEST_EVENT_CODE=            # nur zum Testen, siehe unten
PINTEREST_1_ORIGIN=https://example.com
PINTEREST_1_AD_ACCOUNT_ID=1234567890123
PINTEREST_1_ACCESS_TOKEN=<Conversion-Token>
PINTEREST_1_TEST=                  # true = Testendpunkt, nichts wird gespeichert
```

`META_1_PIXEL_ID` muss die Pixel-ID sein, die im Sulu-Admin für diesen Webspace steht, sonst landen Browser- und Server-Event
in verschiedenen Pixeln und werden nicht zusammengeführt. Dasselbe gilt für Pinterest (Tag-ID und Ad-Account gehören zum selben Konto).

**Mehrere Konten** (eine Website mit anderem Pixel oder Pinterest-Konto): In `flow.json` die Blöcke
`meta1Context`/`meta1` bzw. `pinterest1Context`/`pinterest1` kopieren, `1` durch `2` ersetzen (auch in den
`$env`-Namen und `process.env`), die Variablen in `docker-compose.yml` und `.env.local` ergänzen. Je Konto eigene `ORIGIN`-Liste.

## Testen

- **Meta:** In Events Manager → Testereignisse den Testcode kopieren und als `META_1_TEST_EVENT_CODE` setzen.
  Die Server-Ereignisse erscheinen dort mit Quelle „Server“. Danach wieder leeren.
- **Pinterest:** `PINTEREST_1_TEST=true` setzen, die Antwort der API zeigt die Prüfung, es wird nichts gespeichert.
- **Lokal ohne Konten:** `lokal/lokal.sh up` startet nach `docs/lokal.md` eine Attrappe (`lokal/capi-mock.js`), die jede Anfrage protokolliert.
<!-- capi.md - walkerOS - ENDE -->
