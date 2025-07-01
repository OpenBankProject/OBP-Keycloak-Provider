#!/bin/bash

set -euo pipefail

# Config
IMAGE_NAME="kc-obp-provider-image"
CONTAINER_NAME="kc-obp-provider-container"
EXTERNAL_PORT=8443
INTERNAL_PORT=8443
DOCKERFILE="docker/Dockerfile"
ENV_FILE=".env" # Move secrets here for production

# --- Environment Setup ---
# Check if the .env file exists before proceeding
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Missing environment file: $ENV_FILE"
  exit 1
fi

# Export variables from .env to environment
set -o allexport
source "$ENV_FILE"
set +o allexport

# Validate that critical environment variables are set
: "${KC_BOOTSTRAP_ADMIN_USERNAME:?Must be set in .env}"
: "${KC_BOOTSTRAP_ADMIN_PASSWORD:?Must be set in .env}"

# --- Maven Build Step ---
echo "[$(date)] Building Maven project..."
# Run Maven clean install with 8 CPU threads and skip tests
mvn -T 8C clean install -DskipTests=true || {
  echo "[ERROR] Maven build failed"
  exit 1
}

# --- Docker Cleanup ---
echo "[$(date)] Cleaning up old Docker resources..."
# Stop and remove any previously running container with the same name
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Remove dangling Docker images
docker image prune -f

# --- Docker Build ---
echo "[$(date)] Building Docker image..."
# Build a Docker image using the specified Dockerfile
docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" .

# --- Docker Run ---
echo "[$(date)] Running Docker container..."
docker run --name "$CONTAINER_NAME" -d \
  --env-file "$ENV_FILE" \
  -p "$EXTERNAL_PORT:$INTERNAL_PORT" \
  --health-cmd="curl -k --fail https://127.0.0.1:$INTERNAL_PORT/health/ready || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=5 \
  "$IMAGE_NAME"

# --- Log Tail ---
echo "[$(date)] Showing logs..."
# Tail and follow the container logs
docker logs -f --tail=100 "$CONTAINER_NAME"
