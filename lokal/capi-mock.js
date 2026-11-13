// capi-mock.js - walkerOS - START
// Attrappe fuer die Conversions APIs von Meta und Pinterest (nur lokal). Schreibt jede Anfrage als eine JSON-Zeile
// nach stdout und antwortet wie die echten APIs mit Erfolg. Aufruf: node lokal/capi-mock.js (Port 9000)
const http = require('http');

http.createServer((req, res) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
        let parsed = body;
        try { parsed = JSON.parse(body); } catch (e) { /* keep text */ }
        console.log(JSON.stringify({ method: req.method, url: req.url, auth: req.headers.authorization ? 'Bearer …' : null, body: parsed }));
        res.setHeader('Content-Type', 'application/json');
        res.end(req.url.startsWith('/pinterest')
            ? JSON.stringify({ num_events_received: 1, num_events_processed: 1, events: [{ status: 'processed' }] })
            : JSON.stringify({ events_received: 1, messages: [], fbtrace_id: 'mock' }));
    });
}).listen(9000);
// capi-mock.js - walkerOS - ENDE
