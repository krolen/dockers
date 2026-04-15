#!/bin/bash

# Exit on error
set -e

# Check if directory parameter is provided
if [ -z "$1" ]; then
  echo "❌ Error: Please provide the directory containing the Dockerfile as the first argument."
  echo "Usage: $0 <directory_name>"
  exit 1
fi

DIR_NAME="$1"
# Get the absolute path of the directory
TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/$DIR_NAME" && pwd)"

if [ ! -f "$TARGET_DIR/Dockerfile" ]; then
  echo "❌ Error: Dockerfile not found in $TARGET_DIR"
  exit 1
fi

# Variables
# We'll use the directory name as part of the image name for uniqueness
IMAGE_NAME="kkulagin/${DIR_NAME}"
TAG="latest"

echo "🚀 Starting build and push process for ${IMAGE_NAME}:${TAG}..."

# 1. Build the Docker image
echo "📦 Building Docker image from ${TARGET_DIR}..."
docker build -t ${IMAGE_NAME}:${TAG} "${TARGET_DIR}"

# 2. Push the image to Docker Hub
echo "📤 Pushing image to Docker Hub..."
docker push ${IMAGE_NAME}:${TAG}

echo "✅ Successfully pushed ${IMAGE_NAME}:${TAG} to Docker Hub!"
