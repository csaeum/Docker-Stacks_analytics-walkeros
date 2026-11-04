#!/usr/bin/env bash
#
# This file is part of analytics-walkeros.
#
# (c) Christian Säum <Christian.Saeum@Web-SEO-Consulting.eu> - Web-SEO-Consulting.eu
#
# This source file is subject to the GNU Affero General Public License v3
# that is bundled with this source code in the file LICENSE.

# Builds walker.js for one collector host, because the URL is fixed at build time.
# Usage: web/build-walker.sh fury.web-seo-consulting.eu
set -euo pipefail

HOST="${1:?Usage: web/build-walker.sh <collector-host>}"
if ! [[ "${HOST}" =~ ^[a-z0-9.-]+$ ]]; then
  echo "Invalid host: ${HOST}" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(grep -E '^WALKEROS_VERSION=' "${ROOT}/.env" | cut -d= -f2)"
OUT="${ROOT}/dist/web/${HOST}"
mkdir -p "${OUT}"

# Runs in a container so nothing is installed on the host.
docker run --rm --user "$(id -u):$(id -g)" \
  -e HOME=/tmp -e WALKEROS_TELEMETRY_DISABLED=1 -e "COLLECT_URL=https://${HOST}/collect" \
  -v "${ROOT}/web/flow.web.json:/work/flow.web.json:ro" -v "${OUT}:/out" -w /tmp \
  node:24-alpine \
  npx --yes "@walkeros/cli@${VERSION}" bundle /work/flow.web.json --flow web -o /out/walker.js

echo "Built ${OUT}/walker.js"
