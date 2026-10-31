# Node for editors/vscode (Q161), plus what @vscode/test-electron needs to run VS Code headless.
FROM node:26.13.0-trixie-slim

ARG NPM_VERSION=12.2.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git xauth xvfb \
      libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libcups2t64 libdbus-1-3 libdrm2 libgbm1 \
      libgtk-3-0t64 libnss3 libsecret-1-0 libxkbfile1 libxshmfence1 libxss1 \
 && rm -rf /var/lib/apt/lists/* \
 && npm install --global npm@${NPM_VERSION} \
 && npm cache clean --force

WORKDIR /work
