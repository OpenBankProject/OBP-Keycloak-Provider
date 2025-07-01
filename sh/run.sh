#!/bin/bash

set -e  # Exit on error

IMAGE_NAME=kc-obp-provider-image
CONTAINER_NAME=kc-obp-provider-container
EXTERNAL_PORT=8443
INTERNAL_PORT=8443

echo "Building Maven project..."
mvn -T 8C clean install -DskipTests=true || { echo "Maven build failed"; exit 1; }
clear

echo "Cleaning up old Docker containers/images..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true
docker rmi $IMAGE_NAME 2>/dev/null || true

echo "Building Docker image..."
docker build -f docker/Dockerfile -t $IMAGE_NAME .

echo "Running container..."
docker run --name $CONTAINER_NAME -d -p $EXTERNAL_PORT:$INTERNAL_PORT \
    -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin \
    $IMAGE_NAME

echo "Restarting container to apply properties..."
docker restart $CONTAINER_NAME

# Optional: Add mock user
# chmod +x sh/adduser
# sh/adduser

echo "Tailing logs..."
docker logs -f -n 10000 $CONTAINER_NAME

