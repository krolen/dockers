FROM node:22-bookworm-slim
RUN npm install --global chrome-devtools-mcp@latest supergateway@latest \
    && npm cache clean --force
USER node
ENTRYPOINT ["supergateway"]
CMD ["--stdio", "chrome-devtools-mcp --browser-url=http://127.0.0.1:9222 --no-usage-statistics", "--outputTransport", "streamableHttp", "--stateful", "--port", "8933", "--healthEndpoint", "/healthz"]
LABEL io.krolen.dockers.image="chrome-devtools-mcp"
