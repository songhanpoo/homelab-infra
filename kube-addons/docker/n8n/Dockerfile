ARG DOCKER_REGISTRY=nexus-docker.local.proxy 
ARG N8N_VERSION=2.13.2
ARG BUILD_PLATFORM=linux/amd64
FROM --platform=$BUILD_PLATFORM ${DOCKER_REGISTRY}/n8nio/runners:${N8N_VERSION}

USER root
RUN wget https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic//v2.12.14/x86_64/apk.static && \
  chmod +x apk.static && \
  ./apk.static -X http://dl-cdn.alpinelinux.org/alpine/latest-stable/main -U --allow-untrusted --initdb add apk-tools-static && \
  ./apk.static update && \
  ./apk.static -X http://dl-cdn.alpinelinux.org/alpine/latest-stable/main -U --allow-untrusted add apk-tools && \
  apk update && apk upgrade && apk add --no-cache python3 py3-pip git jq bash && \
  ln -sf python3 /usr/bin/python && \
  pip3 install --no-cache-dir --break-system-packages fire virtualenv PyYAML && \
  python3 -m virtualenv /opt/runners/task-runner-python/.venv && \
  chown -R node:node /opt/runners/task-runner-python/.venv 

ENV PATH="/opt/runners/task-runner-python/.venv/bin:$PATH"

USER node