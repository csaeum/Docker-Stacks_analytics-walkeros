<!-- AGENTS.md - walkerOS - START -->
@CICD-Actions.md
@Projekt.md
@STATUS.md

## Projektregeln

- Keine DDEV-Umgebung: Dieser Stack wird lokal direkt mit `docker compose` geprüft.
- Den Stack `analytics-gtm-sstm-projekt` nicht verändern: Er bleibt für GA4 und Google Ads in Betrieb.
- MCP `walkeros-flow`: `flow_push` nur nach ausdrücklicher Freigabe. `flow_simulate` sendet bei eigenen `push`-Funktionen wirklich, Details in `ReadMe-MCP-nutzen.md`.
- Echte Ziel-URLs und Secrets nie in der lokalen Shell setzen.
<!-- AGENTS.md - walkerOS - ENDE -->
