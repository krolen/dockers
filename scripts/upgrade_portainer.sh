#!/usr/bin/env bash
set -euo pipefail

# Upgrade the standalone Portainer container to the latest portainer-ce:lts.
# Works from any cwd. Data lives in the host bind mount, so the upgrade is a
# pull + container recreation with a few seconds of downtime.

IMAGE="portainer/portainer-ce:lts"
CONTAINER="portainer"
API_URL="http://localhost:9000/api/status"

# 1. Pull before recreating so a failed download leaves the current container running.
echo "📦 Pulling the latest ${IMAGE}..."
docker pull "$IMAGE"

current_image_id=$(docker container inspect --format '{{.Image}}' "$CONTAINER")
new_image_id=$(docker image inspect --format '{{.Id}}' "$IMAGE")

if [[ "$current_image_id" == "$new_image_id" ]]; then
    echo "✅ ${CONTAINER} already runs the newest ${IMAGE}; nothing to do."
    exit 0
fi

# 2. Recreate with the exact current flags (verified via docker inspect).
echo "🔁 Recreating ${CONTAINER} (brief downtime, data in /home/kot/docker-data/portainer_data is preserved)..."
docker stop "$CONTAINER"
docker rm "$CONTAINER"
docker run -d --name "$CONTAINER" --restart always \
    -p 8000:8000 -p 9443:9443 -p 9000:9000 \
    -v /home/kot/docker-data/portainer_data:/data \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMAGE"

# 3. Wait for the Web UI API to answer before reporting success.
echo "⏳ Waiting for Portainer to come up at http://localhost:9000 ..."
for _ in $(seq 1 30); do
    if curl -fsS -o /dev/null "$API_URL"; then
        echo "✅ Portainer is up on the new image."
        docker ps --filter "name=^${CONTAINER}$" --format '  {{.Names}}: {{.Image}} ({{.Status}})'
        exit 0
    fi
    sleep 2
done

echo "❌ Portainer did not become healthy within 60s. Check: docker logs ${CONTAINER}" >&2
exit 1
