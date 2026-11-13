# Dockerfile - walkerOS walker.js - START
#
# This file is part of analytics-walkeros.
#
# (c) Christian Säum <Christian.Saeum@Web-SEO-Consulting.eu> - Web-SEO-Consulting.eu
#
# This source file is subject to the GNU Affero General Public License v3
# that is bundled with this source code in the file LICENSE.

# Build stage: one bundle for all domains, nginx fills in the collector host per request.
FROM node:24-alpine AS builder
ARG WALKEROS_VERSION
# GA4 measurement ID comes from the build, the repo only holds the placeholder
ARG GA4_MEASUREMENT_ID=G-XXXXXXXXXX
WORKDIR /build
RUN npm init -y && npm install --save-dev @walkeros/cli@${WALKEROS_VERSION}
COPY flow.web.json ./
RUN sed -i "s/G-XXXXXXXXXX/${GA4_MEASUREMENT_ID}/g" flow.web.json \
  && npx walkeros bundle flow.web.json --flow web -o dist/walker.js \
  && grep -qF 'https://collector-host.invalid/collect' dist/walker.js

# Runtime stage: serves only walker.js and listens on 8080 as a non-root user.
FROM nginxinc/nginx-unprivileged:1.30.6-alpine3.24
# The base image lags behind Alpine security fixes, the scan in CI fails without this.
USER root
RUN apk upgrade --no-cache
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/dist/walker.js /usr/share/nginx/html/walker.js
USER 101
# Dockerfile - walkerOS walker.js - ENDE
