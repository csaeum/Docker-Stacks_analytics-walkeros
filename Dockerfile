# Dockerfile - walkerOS - START
#
# This file is part of analytics-walkeros.
#
# (c) Christian Säum <Christian.Saeum@Web-SEO-Consulting.eu> - Web-SEO-Consulting.eu
#
# This source file is subject to the GNU Affero General Public License v3
# that is bundled with this source code in the file LICENSE.

ARG WALKEROS_VERSION

# Build stage: the runtime image cannot bundle a flow.json itself.
FROM node:24-alpine AS builder
ARG WALKEROS_VERSION
WORKDIR /build
RUN npm init -y && npm install --save-dev @walkeros/cli@${WALKEROS_VERSION}
COPY flow.json ./
RUN npx walkeros bundle flow.json -o dist/

# Runtime stage: BUNDLE, PORT, CMD and HEALTHCHECK are provided by the image.
FROM walkeros/flow:${WALKEROS_VERSION}
COPY --from=builder /build/dist/ /app/flow/
USER walker
# Dockerfile - walkerOS - ENDE
