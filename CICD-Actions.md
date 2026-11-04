<!-- CICD-Actions.md - walkerOS - START -->
# CI/CD

Die Pipeline `.forgejo/workflows/ci.yml` läuft bei jedem Push, bei Pull Requests auf `main` und bei
Tags `v*` auf dem eigenen Forgejo-Runner. Sie nutzt keine externen Actions. Es gibt keinen
Codeberg-Mirror-Job wie in älteren Stacks; das Spiegeln nach GitHub übernimmt der Push-Mirror von
Forgejo.

| Job | Prüfung |
|---|---|
| `lint` | `yamllint`, verbotene Compose-Optionen, gleiche Version in `.env` und `flow.json` |
| `sicherheit` | Gitleaks (komplette Historie), Trivy (Fehlkonfiguration), Semgrep |
| `docker` | `docker compose config`, Image-Build, Rauchtest, Trivy (Schwachstellen im Image) |

Der Rauchtest startet das Image und prüft `/ready`, ein Event an `/collect` und dass der Container
nicht als root läuft. Die Traefik-Regeln prüft die Pipeline nicht.

## Regeln

- Scanner-Versionen stehen fest im Workflow und sind beim Eintragen mindestens zwei Wochen alt.
- Prüfsummen von Gitleaks und Trivy stehen fest im Workflow. Beim Update die Prüfsummen-Datei des
  Releases einmalig nutzen.
- Fehlalarme nur gezielt und mit Begründung ausnehmen: Trivy über `.trivyignore`, Semgrep über
  `# nosemgrep: <regel-id>`. Keine Werkzeuge oder Verzeichnisse pauschal abschalten.

## Bekannte Grenzen der Scanner

- **Semgrep `p/docker-compose`** meldet einen Dienst mit `privileged: true` und Docker-Socket nicht
  (getestet mit 1.182.0 ohne Semgrep-Login). **Trivy** scannt die Compose-Datei nicht. Deshalb
  verbietet der Job `lint` diese Optionen selbst.
- **Eigene `push`-Funktionen** stehen als Text in `flow.json`. Semgrep prüft sie nicht als JavaScript.

## Lokal nachstellen

```bash
docker compose config -q
yamllint -d "{extends: default, rules: {line-length: disable, document-start: disable, comments-indentation: disable, truthy: {check-keys: false}}}" docker-compose.yml .forgejo/workflows
gitleaks git --redact --no-banner .
trivy fs --quiet --scanners misconfig --severity HIGH,CRITICAL --exit-code 1 --skip-dirs .git .
semgrep scan --metrics off --error --config p/dockerfile --config p/docker-compose --config p/security-audit .
```
<!-- CICD-Actions.md - walkerOS - ENDE -->
