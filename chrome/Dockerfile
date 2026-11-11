ARG NODE_IMAGE=node:22-bookworm-slim@sha256:5ec23b7c622b00547753bc6ffd78085dd868a68aeb41c8e0a1418f033e13d96d
ARG CHROMIUM_IMAGE=lscr.io/linuxserver/chromium@sha256:59d1bfa98a6ab759fce078e5a714de3920f4c618b8939a0df6e1dec7d25c7aba

FROM ${NODE_IMAGE} AS node-runtime

ARG CHROME_DEVTOOLS_MCP_VERSION=1.13.0
ARG SUPERGATEWAY_VERSION=4.2.2
RUN npm install --global \
      "chrome-devtools-mcp@${CHROME_DEVTOOLS_MCP_VERSION}" \
      "supergateway@${SUPERGATEWAY_VERSION}" \
    && npm cache clean --force

FROM ${CHROMIUM_IMAGE}

COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/lib/node_modules/chrome-devtools-mcp /usr/local/lib/node_modules/chrome-devtools-mcp
COPY --from=node-runtime /usr/local/lib/node_modules/supergateway /usr/local/lib/node_modules/supergateway

COPY health-proxy.mjs supervise-chromium.sh /opt/chrome-mcp/
COPY install-supervisor.sh /custom-cont-init.d/90-install-chromium-supervisor
COPY run-mcp.sh /etc/s6-overlay/s6-rc.d/svc-chrome-mcp/run

RUN ln -s ../lib/node_modules/chrome-devtools-mcp/out/Default/gen/src/bin/chrome-devtools-mcp.js /usr/local/bin/chrome-devtools-mcp \
    && ln -s ../lib/node_modules/supergateway/dist/index.js /usr/local/bin/supergateway \
    && chmod 755 \
      /opt/chrome-mcp/health-proxy.mjs \
      /opt/chrome-mcp/supervise-chromium.sh \
      /custom-cont-init.d/90-install-chromium-supervisor \
      /etc/s6-overlay/s6-rc.d/svc-chrome-mcp/run \
    && mkdir -p /etc/s6-overlay/s6-rc.d/svc-chrome-mcp/dependencies.d \
    && touch /etc/s6-overlay/s6-rc.d/svc-chrome-mcp/dependencies.d/init-services \
    && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/svc-chrome-mcp/type \
    && touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-chrome-mcp

EXPOSE 3001 8933

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:8933/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

LABEL org.opencontainers.image.source="https://github.com/krolen/dockers" \
      org.opencontainers.image.description="Chromium desktop with authenticated Chrome DevTools MCP and bounded crash recovery" \
      io.krolen.dockers.image="chrome"
