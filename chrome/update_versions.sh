#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile="$script_dir/Dockerfile"

node_image=node:22-bookworm-slim
chromium_image=lscr.io/linuxserver/chromium:latest

resolve_digest() {
    local image=$1 repository digest
    repository=${image%:*}
    digest=$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$image" \
        | awk -F@ -v repository="$repository" '$1 == repository { print $2; exit }')
    [[ -n "$digest" ]] || {
        echo "Could not resolve a repository digest for $image." >&2
        exit 1
    }
    printf '%s' "$digest"
}

resolve_npm_version() {
    local package=$1 version
    version=$(docker run --rm "$node_image" npm view "$package" version)
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.+-]+)?$ ]] || {
        echo "Unexpected version returned for $package: $version" >&2
        exit 1
    }
    printf '%s' "$version"
}

echo "Pulling current upstream base images..."
docker pull "$node_image"
docker pull "$chromium_image"

node_digest=$(resolve_digest "$node_image")
chromium_digest=$(resolve_digest "$chromium_image")
chrome_devtools_mcp_version=$(resolve_npm_version chrome-devtools-mcp)
supergateway_version=$(resolve_npm_version supergateway)

sed -i \
    -e "s|^ARG NODE_IMAGE=.*$|ARG NODE_IMAGE=${node_image}@${node_digest}|" \
    -e "s|^ARG CHROMIUM_IMAGE=.*$|ARG CHROMIUM_IMAGE=${chromium_image}@${chromium_digest}|" \
    -e "s|^ARG CHROME_DEVTOOLS_MCP_VERSION=.*$|ARG CHROME_DEVTOOLS_MCP_VERSION=${chrome_devtools_mcp_version}|" \
    -e "s|^ARG SUPERGATEWAY_VERSION=.*$|ARG SUPERGATEWAY_VERSION=${supergateway_version}|" \
    "$dockerfile"

echo "Updated $dockerfile:"
echo "  Node: $node_image@$node_digest"
echo "  Chromium: $chromium_image@$chromium_digest"
echo "  chrome-devtools-mcp: $chrome_devtools_mcp_version"
echo "  supergateway: $supergateway_version"
