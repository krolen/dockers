#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ -z "${SUPERGATEWAY_API_KEY:-}" ]]; then
    echo "[chrome-mcp] SUPERGATEWAY_API_KEY is required" >&2
    exit 1
fi

exec s6-setuidgid abc \
    node /opt/chrome-mcp/health-proxy.mjs \
    --stdio "chrome-devtools-mcp --browser-url=http://127.0.0.1:9222 --no-usage-statistics" \
    --outputTransport streamableHttp \
    --stateful \
    --port 8934 \
    --healthEndpoint /healthz
