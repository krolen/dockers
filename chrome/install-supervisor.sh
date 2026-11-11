#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${PIXELFLUX_WAYLAND,,}" == "true" ]]; then
    autostart_file=/config/.config/labwc/autostart
else
    autostart_file=/config/.config/openbox/autostart
fi

install -d -o abc -g abc -m 755 "$(dirname -- "$autostart_file")"
install -o abc -g abc -m 644 /opt/chrome-mcp/supervise-chromium.sh "$autostart_file"
rm -f /config/.chromium-supervisor-status.json

echo "[chrome-mcp] Installed bounded Chromium supervisor at $autostart_file"
