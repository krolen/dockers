#!/usr/bin/env bash
set -euo pipefail

# Resolve Compose paths and .env from this directory, regardless of the caller's cwd.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

docker compose -f docker-compose.yml config --quiet

echo "Pulling the latest merged Chromium MCP image..."
# Pull before recreation so a failed download leaves the current stack running.
docker compose -f docker-compose.yml pull chrome-stealth

echo "Recreating Chromium MCP (active connections will be interrupted)..."
docker compose -f docker-compose.yml up -d --force-recreate --wait --wait-timeout 60
docker compose -f docker-compose.yml ps

cleanup_images() {
    local service=$1 label=$2
    local container_id current_image_id image_ids image_dates entry image_id
    local -a candidate_ids sorted_images

    container_id=$(docker compose -f docker-compose.yml ps -q "$service")
    current_image_id=$(docker container inspect --format '{{.Image}}' "$container_id")
    # Labels identify older images even after their tags move to a new build.
    image_ids=$(docker image ls --all --quiet --no-trunc --filter "label=$label")
    [[ -n "$image_ids" ]] || return 0
    mapfile -t candidate_ids <<< "$(sort -u <<< "$image_ids")"
    image_dates=$(docker image inspect --format '{{.Created}} {{.Id}}' "${candidate_ids[@]}")
    mapfile -t sorted_images <<< "$(LC_ALL=C sort -r <<< "$image_dates")"

    echo "Keeping the two newest $service images; cleaning up older versions..."
    for entry in "${sorted_images[@]:2}"; do
        image_id=${entry##* }
        # Also protect the deployed image in case upstream latest was rolled back.
        [[ "$image_id" == "$current_image_id" ]] && continue
        # No --force: Docker protects images used by containers or multiple tags.
        if ! docker image rm "$image_id"; then
            echo "Retained $image_id: Docker refused removal (it may still be in use)." >&2
        fi
    done
}

cleanup_images chrome-stealth 'io.krolen.dockers.image=chrome'
