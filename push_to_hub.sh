#!/usr/bin/env bash

# Exit on error
set -euo pipefail

# Check if directory parameter is provided
if [ "$#" -lt 1 ]; then
  echo "❌ Error: Please provide the directory containing the Dockerfile as the first argument."
  echo "Usage: $0 <directory_name> [tag]"
  exit 1
fi

# Get the absolute path of the directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$1" = /* ]]; then
  INPUT_DIR="$1"
else
  INPUT_DIR="$SCRIPT_DIR/$1"
fi
if ! TARGET_DIR="$(cd -- "$INPUT_DIR" 2>/dev/null && pwd)"; then
  echo "❌ Error: Directory not found: $1"
  exit 1
fi

if [ ! -f "$TARGET_DIR/Dockerfile" ]; then
  echo "❌ Error: Dockerfile not found in $TARGET_DIR"
  exit 1
fi

# Variables
# Docker Hub repository names cannot contain path separators.  Use the resolved
# directory's basename so `crawl4ai`, `./crawl4ai`, and an absolute path work alike.
IMAGE_NAME="kkulagin/$(basename -- "$TARGET_DIR")"
TAG="${2:-0.9.3}"

echo "🚀 Starting build and push process for ${IMAGE_NAME}:${TAG}..."

# 1. Build the Docker image
echo "📦 Building Docker image from ${TARGET_DIR}..."
docker build --tag "${IMAGE_NAME}:${TAG}" "${TARGET_DIR}"

# 2. Push the image to Docker Hub
echo "📤 Pushing image to Docker Hub..."
docker push "${IMAGE_NAME}:${TAG}"

echo "✅ Successfully pushed ${IMAGE_NAME}:${TAG} to Docker Hub!"
