# Chromium MCP

One container providing a persistent Chromium desktop, Selkies web UI, and an
authenticated Chrome DevTools MCP endpoint. Chromium renders on the host's AMD
iGPU and is supervised with a bounded restart policy.

The published image is `kkulagin/chrome`. It derives from LinuxServer Chromium
and embeds Node.js, Chrome DevTools MCP, Supergateway, health reporting, and the
Chromium supervisor; no source-code bind mounts or companion container are
required at runtime.

## Run

Create `chrome/.env` with the bearer token used by MCP clients:

```dotenv
SUPERGATEWAY_API_KEY=replace-with-a-long-random-token
```

Then pull and start the container:

```bash
cd chrome  # from the repository root
docker compose pull
docker compose up -d --wait
```

- Session web UI: https://localhost:3001 (self-signed certificate, localhost
  only because the UI includes a passwordless terminal)
- MCP: http://localhost:8933/mcp (bearer token required)
- Health: http://localhost:8933/healthz (unauthenticated)
- CDP: internal loopback port 9222; not published to the host

The only runtime data mount is `~/docker-data/chrome:/config`.

## Image contents and build

The Dockerfile pins the validated base-image digests and npm package versions.
To build a local development image:

```bash
docker build --pull --tag kkulagin/chrome:dev .
CHROME_IMAGE=kkulagin/chrome:dev docker compose up -d --force-recreate --wait
```

To publish a release, replace `1.0.0` with the intended immutable version:

```bash
docker build --pull \
  --tag kkulagin/chrome:1.0.0 \
  --tag kkulagin/chrome:latest \
  .
docker push kkulagin/chrome:1.0.0
docker push kkulagin/chrome:latest
```

Never add `.env`, the MCP token, or browser-profile data to the image. The
`.dockerignore` excludes `.env` from the build context.

## Update

Run the update script from any directory:

```bash
chrome/update.sh
```

It validates Compose, pulls `kkulagin/chrome:latest`, and recreates the single
container only after a successful pull. This interrupts active browser and MCP
connections, but preserves the profile under `~/docker-data/chrome/`. Cleanup
keeps the two newest locally available custom images and never performs a broad
image prune.

### Roll back

Before updating, record the deployed image ID:

```bash
docker inspect --format '{{.Image}}' chrome-stealth
```

To restore it, replace `PREVIOUS_IMAGE_ID` below:

```bash
docker image tag PREVIOUS_IMAGE_ID kkulagin/chrome:rollback
CHROME_IMAGE=kkulagin/chrome:rollback docker compose up -d \
  --no-build --pull never --force-recreate --wait
```

Image rollback does not roll back browser-profile data. Locally retained images
are not guaranteed to survive manual pruning.

## Chromium recovery and health

Labwc starts the embedded Chromium supervisor. If Chromium exits, it is
restarted up to three times with delays of 5, 10, and 15 seconds. Running for at
least five minutes resets the recovery budget. If all three restarted processes
also exit quickly, the supervisor latches in `failed` state and makes no further
attempts until the container is deliberately restarted:

```bash
docker compose restart chrome-stealth
```

Keeping the container alive after the latch preserves the desktop and diagnostic
endpoint. Docker restart policies do not react to health-check failures; they
only react when the container's main process exits.

`/healthz` returns HTTP 200 only when both the MCP gateway and Chromium CDP are
available. Otherwise it returns HTTP 503. Its JSON body reports `gateway`,
`chrome_cdp`, supervisor counters, the last exit code, and a human-readable
`error`. Docker uses this same endpoint for the container health status.

Example latched response:

```json
{
  "status": "unhealthy",
  "error": "Chromium exited after 3 automatic restart attempts; recovery is latched until the container is restarted",
  "gateway": "available",
  "chrome_cdp": "unavailable",
  "supervisor": {
    "state": "failed",
    "restart_attempts": 3,
    "max_restart_attempts": 3,
    "last_exit_code": 1
  }
}
```

## MCP client configuration

LAN endpoint on this host: `http://192.168.0.188:8933/mcp` (update if DHCP
changes). Codex client configuration on another machine:

```toml
[mcp_servers.chrome-devtools]
url = "http://192.168.0.188:8933/mcp"
bearer_token_env_var = "CHROME_MCP_TOKEN"
```

Set `CHROME_MCP_TOKEN` in the client environment to the value from `chrome/.env`.
Other Streamable HTTP clients can use an `Authorization: Bearer <token>` header.

The endpoint controls the existing browser session, including logged-in tabs.
Use it only on a trusted LAN: plain HTTP does not encrypt the token or browser
data. Do not forward port 8933 from the Internet.

## GPU and browser configuration

- `CHROME_CLI`, not `CHROMIUM_FLAGS`, supplies Chromium flags. The wrapper adds
  `--no-sandbox --password-store=basic --test-type`.
- Chrome 136+ requires the non-default `--user-data-dir` for the remote-debugging
  port. The configured profile path is persistent under `/config`.
- Only the AMD card is mounted: card2/renderD129 (PCI 12:00.0, vendor 0x1002).
  The NVIDIA card at card1/renderD128 is deliberately unavailable to Chromium.
- If GPU numbering changes, re-detect it with:

  ```bash
  for r in /sys/class/drm/renderD*; do echo "$r $(cat "$r/device/vendor")"; done
  ```

  `0x1002` is AMD and `0x10de` is NVIDIA. Update both `devices` mappings in
  `docker-compose.yml` when necessary.

Verify the browser version with:

```bash
docker exec chrome-stealth /usr/bin/chromium --version
```

In the web UI, `chrome://gpu` should identify the AMD renderer and show hardware
acceleration for compositing and video decode. Relevant startup messages are
available with:

```bash
docker logs chrome-stealth 2>&1 | grep -iE 'gpu|video|render'
```

## Profile

`~/docker-data/chrome/` is mounted at `/config`, so bookmarks, history, cookies,
extensions, and the debugging profile survive image and container updates. All
runtime data lives outside the repository.

References: [LinuxServer Chromium](https://docs.linuxserver.io/images/docker-chromium/),
[Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp),
[Supergateway](https://github.com/supercorp-ai/supergateway), and
[Codex MCP configuration](https://developers.openai.com/codex/mcp).
