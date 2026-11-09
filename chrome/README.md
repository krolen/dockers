# chrome-stealth

Local Chromium in a container, rendered on the AMD iGPU (via `/dev/dri`) instead of a
dedicated GPU, with a persistent profile and remote DevTools access.

## Run

```bash
docker compose up -d
```

- Session web UI (Selkies): https://localhost:3001 (self-signed cert; bound to
  127.0.0.1 only because the UI includes a passwordless terminal)
- MCP (Streamable HTTP): http://localhost:8933/mcp (bearer token required)
- DevTools Protocol (CDP): internal only; no host port published

## Update

Run the update script from any directory:

```bash
/home/kot/IdeaProjects/dockers/chrome/update.sh
```

The script pulls the latest Chromium image and rebuilds the MCP companion with
`build --pull --no-cache` to refresh its Node base image and install the latest
`chrome-devtools-mcp` and `supergateway` packages, then recreates both Chromium and
the MCP companion so they share the new network namespace. This interrupts
active browser and MCP connections; the profile in `~/docker-data/chrome/`
is preserved. If the pull or build fails, the running containers are left in place.
After the services are running, cleanup keeps the two newest images for each
service separately, by image creation date, and removes older versions, including
untagged ones identified by their image labels. MCP images built before the cleanup
label was added are left untouched. It never prunes other images or
forces removal. Images used by containers or protected by multiple tags remain;
the deployed image is always preserved, even if upstream `latest` was rolled back.
Run it as your normal user with Docker access so the home-directory mount
continues to point to your profile.

### Roll back MCP

The previous MCP image is retained locally. Before updating, record its ID:

```bash
docker inspect --format '{{.Image}}' chrome-devtools-mcp
```

To restore it, run these commands from the `chrome/` directory, replacing
`PREVIOUS_IMAGE_ID` with that ID:

```bash
mcp_image=$(docker inspect --format '{{.Config.Image}}' chrome-devtools-mcp)
docker image tag PREVIOUS_IMAGE_ID "$mcp_image"
docker compose up -d --no-deps --no-build --pull never --force-recreate chrome-devtools-mcp
```

This restores the packages bundled in that image. Avoid running the update script
again until ready to retry the latest packages. Retention keeps only two versions,
so a particular older image is not guaranteed to survive repeated updates or manual
image pruning. Image rollback does not restore browser profile data.

## Notes

- `lscr.io/linuxserver/chromium:latest` is now based on Selkies: it streams a full
  Chromium desktop session over the web (port 3001), not a raw browser on 3000.
- Flags go through `CHROME_CLI`, not `CHROMIUM_FLAGS` (the old env var is ignored).
  The wrapper always adds `--no-sandbox --password-store=basic --test-type`
  and uses a non-default `--user-data-dir`, which is required for
  `--remote-debugging-port` to work on Chrome 136+.
- This host has two GPUs, so only the AMD one is mounted (see the `devices:`
  block in the compose file): card2 / renderD129 (PCI 12:00.0, vendor 0x1002).
  The NVIDIA card (card1 / renderD128, PCI 01:00.0) is deliberately not passed
  to the container. The image's `init-video` then auto-enables `AUTO_GPU` and
  uses the (single) render node for zero-copy rendering and VA-API encoding.
- If GPU numbering changes (e.g. after a driver or kernel update), re-detect:
  `for r in /sys/class/drm/renderD*; do echo "$r $(cat $r/device/vendor)"; done`
  (`0x1002` = AMD, `0x10de` = NVIDIA) and update the two `devices:` lines.
- Chrome 136+ binds the debug port to 127.0.0.1 inside the container; the
  Docker port publishing cannot reach that loopback listener. Use the MCP
  companion below for LAN access.

## Verify GPU rendering

While the container is running:

```bash
docker exec chrome-stealth /usr/bin/chromium --version
```

- In the session web UI, open `chrome://gpu`: GPU must be enabled, and the
  renderer should list the AMD GPU (Radeon, PCI 12:00.0) for compositing and
  video decode — not the NVIDIA card.
- Startup log lines to check: `docker logs chrome-stealth 2>&1 | grep -iE 'gpu|video|render'`
  should show `permissions for /dev/dri/... are good` and `AUTO_GPU` enabled.

## MCP: Chrome DevTools over the LAN

`docker compose up -d --build` starts the browser and a companion container with
the latest chrome-devtools-mcp and Supergateway packages at build time. The companion shares Chrome's
network namespace and connects to its internal `127.0.0.1:9222` listener.
Supergateway exposes a stateful Streamable HTTP endpoint on port 8933.

Endpoint on this host: `http://192.168.0.188:8933/mcp` (update if DHCP changes).
The gateway requires a bearer token stored as `SUPERGATEWAY_API_KEY` in `chrome/.env`.
That file is ignored by Git. Copy the token securely to the client machine.
For a fresh checkout, create `.env` in this directory with that variable before starting.

Codex client configuration on the other machine:

```toml
[mcp_servers.chrome-devtools]
url = "http://192.168.0.188:8933/mcp"
bearer_token_env_var = "CHROME_MCP_TOKEN"
```

Set `CHROME_MCP_TOKEN` in the client's environment to the token from `.env`.
Other Streamable HTTP clients can use the same URL and an
`Authorization: Bearer <token>` header.

The endpoint controls the existing browser session, including logged-in tabs.
Use on a trusted LAN only: HTTP does not encrypt the token or browser data.
Do not forward port 8933 from the Internet. `/healthz` is unauthenticated.
The web UI is available only on localhost port 3001. CDP port 9222 is internal only and is not
published to the host; the MCP companion accesses it through shared loopback.
After recreating Chrome, use `docker compose up -d` for the whole stack so the
companion joins its current network namespace.

References: [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp),
[Supergateway](https://github.com/supercorp-ai/supergateway),
[Codex MCP configuration](https://developers.openai.com/codex/mcp).

## Profile

`~/docker-data/chrome/` is mounted at `/config` (the container user's home), so
bookmarks, history, cookies and the debugging profile persist across container
updates. All container data for this service lives under `~/docker-data/`,
outside the repo.
