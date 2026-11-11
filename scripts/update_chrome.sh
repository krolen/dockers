#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
chrome_dir=$(cd -- "$script_dir/../chrome" && pwd)
cd -- "$chrome_dir"

compose=(docker compose -f docker-compose.yml)
service=chrome-stealth
image_label=io.krolen.dockers.image=chrome

"${compose[@]}" config --quiet

# Include stopped and unhealthy containers. When one already uses the target
# image, leave it untouched so this script cannot clear a deliberate stop or a
# latched Chromium failure merely because the published image is unchanged.
container_id=$("${compose[@]}" ps --all -q "$service")
current_image_id=""
if [[ -n "$container_id" ]]; then
    current_image_id=$(docker container inspect --format '{{.Image}}' "$container_id")
fi

image_ref=$("${compose[@]}" config --images | head -n 1)
[[ -n "$image_ref" ]] || {
    echo "Could not resolve the image for $service." >&2
    exit 1
}

echo "Checking $image_ref for an updated image..."
# Pull before recreation so a failed download leaves the current container in
# place. Docker reuses unchanged layers automatically.
"${compose[@]}" pull "$service"
target_image_id=$(docker image inspect --format '{{.Id}}' "$image_ref")

if [[ -n "$current_image_id" && "$current_image_id" == "$target_image_id" ]]; then
    echo "$service already uses $image_ref ($target_image_id); nothing to do."
    exit 0
fi

if [[ -n "$current_image_id" ]]; then
    echo "Updating $service from $current_image_id to $target_image_id..."
else
    echo "Creating $service with $target_image_id..."
fi

"${compose[@]}" up -d --no-build --pull never --force-recreate --wait --wait-timeout 60 "$service"
"${compose[@]}" ps "$service"

cleanup_images() {
    local deployed_image_id image_ids image_dates entry image_id
    local -a candidate_ids sorted_images

    deployed_image_id=$(docker container inspect --format '{{.Image}}' "$("${compose[@]}" ps -q "$service")")
    # Labels identify older custom images even after the latest tag moves.
    image_ids=$(docker image ls --all --quiet --no-trunc --filter "label=$image_label")
    [[ -n "$image_ids" ]] || return 0
    mapfile -t candidate_ids <<< "$(sort -u <<< "$image_ids")"
    image_dates=$(docker image inspect --format '{{.Created}} {{.Id}}' "${candidate_ids[@]}")
    mapfile -t sorted_images <<< "$(LC_ALL=C sort -r <<< "$image_dates")"

    echo "Keeping the two newest custom Chrome images; cleaning up older versions..."
    for entry in "${sorted_images[@]:2}"; do
        image_id=${entry##* }
        [[ "$image_id" == "$deployed_image_id" ]] && continue
        # No --force: Docker protects images used by containers or extra tags.
        if ! docker image rm "$image_id"; then
            echo "Retained $image_id: Docker refused removal (it may still be in use)." >&2
        fi
    done
}

cleanup_images
