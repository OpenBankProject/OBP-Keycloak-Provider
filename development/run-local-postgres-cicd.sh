#!/bin/bash

# CI/CD-Style OBP Keycloak Provider Deployment Script
# This script always builds, always replaces containers - designed for automated environments
#
# Requirements:
# - PostgreSQL running for Keycloak's internal database (KC_DB_URL)
# - OBP API instance reachable at OBP_API_URL
#
# Usage: ./development/run-local-postgres-cicd.sh

set -e

# Signal handler for Ctrl+C
cleanup_and_exit() {
    echo ""
    echo -e "${YELLOW}=== Deployment Interrupted ===${NC}"
    echo -e "${GREEN}Container may still be running in background${NC}"
    echo "Check with: docker ps --filter name=obp-keycloak-local"
    exit 0
}

trap cleanup_and_exit SIGINT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
IMAGE_TAG="obp-keycloak-provider-local"
CONTAINER_NAME="obp-keycloak-local"
DOCKERFILE_PATH="development/docker/Dockerfile"

echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  CI/CD OBP Keycloak Provider Deployment       ${NC}"
echo -e "${CYAN}================================================${NC}"
echo -e "${BLUE}Mode: Always Build & Replace${NC}"
echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# Step 1: Environment validation
echo -e "${CYAN}[1/8] Validating Environment${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker not running${NC}"
    exit 1
fi

# Check Maven
if ! command -v mvn &> /dev/null; then
    echo -e "${RED}✗ Maven not found${NC}"
    exit 1
fi

# Load environment variables
if [ ! -f ".env" ]; then
    echo -e "${RED}✗ .env file not found${NC}"
    echo "Create .env with database configuration (see .env.docker.example)"
    exit 1
fi

source .env

# Set default values for Keycloak service connection
KEYCLOAK_HOST="${KEYCLOAK_HOST:-localhost}"

# Validate required vars
required_vars=("KC_DB_URL" "KC_DB_USERNAME" "KC_DB_PASSWORD" "OBP_API_URL" "OBP_API_USERNAME" "OBP_API_PASSWORD" "OBP_API_CONSUMER_KEY" "OBP_AUTHUSER_PROVIDER" "KEYCLOAK_VERSION")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}✗ Missing environment variable: $var${NC}"
        if [ "$var" = "OBP_AUTHUSER_PROVIDER" ]; then
            echo -e "${RED}CRITICAL: OBP_AUTHUSER_PROVIDER is MANDATORY for security${NC}"
            echo "Add to .env file: OBP_AUTHUSER_PROVIDER=your_provider_name"
        elif [ "$var" = "OBP_API_URL" ]; then
            echo "Add to .env file: OBP_API_URL=http://localhost:8080"
        elif [ "$var" = "OBP_API_USERNAME" ] || [ "$var" = "OBP_API_PASSWORD" ] || [ "$var" = "OBP_API_CONSUMER_KEY" ]; then
            echo "Add to .env file: $var=your_value"
        fi
        exit 1
    fi
done

echo -e "${GREEN}✓ Environment validated (including mandatory security variables)${NC}"

# Step 2: Connectivity tests
echo -e "${CYAN}[2/8] Testing Connectivity${NC}"

# Extract host and port from a JDBC URL
parse_jdbc_url() {
    local url="$1"
    echo "$url" | sed -n 's|.*://\([^/;]*\).*|\1|p'
}

test_db_connection() {
    local label="$1"
    local jdbc_url="$2"
    local host_port
    host_port=$(parse_jdbc_url "$jdbc_url")
    local host="${host_port%%:*}"
    local port="${host_port##*:}"

    # Default port if not specified
    if [ "$host" = "$port" ]; then
        port=5432
    fi

    # host.docker.internal is a Docker-only alias; resolve to localhost for host-side checks
    local test_host="$host"
    if [ "$host" = "host.docker.internal" ]; then
        test_host="localhost"
    fi

    echo -n "  Testing $label ($host:$port)... "

    if command -v pg_isready &> /dev/null; then
        if pg_isready -h "$test_host" -p "$port" -t 5 > /dev/null 2>&1; then
            echo -e "${GREEN}✓ reachable${NC}"
            return 0
        fi
    elif command -v nc &> /dev/null; then
        if nc -z -w 5 "$test_host" "$port" 2>/dev/null; then
            echo -e "${GREEN}✓ reachable${NC}"
            return 0
        fi
    else
        if (echo > /dev/tcp/"$test_host"/"$port") 2>/dev/null; then
            echo -e "${GREEN}✓ reachable${NC}"
            return 0
        fi
    fi

    echo -e "${RED}✗ unreachable${NC}"
    return 1
}

test_obp_api() {
    local url="$1"
    echo -n "  Testing OBP API ($url)... "
    if command -v curl &> /dev/null; then
        if curl -s -o /dev/null -m 10 "$url"; then
            echo -e "${GREEN}✓ reachable${NC}"
            return 0
        fi
    fi
    echo -e "${RED}✗ unreachable${NC}"
    return 1
}

test_db_connection "Keycloak DB" "$KC_DB_URL" || {
    echo -e "${RED}✗ Keycloak DB is unreachable — cannot continue${NC}"
    echo "Ensure PostgreSQL is running and KC_DB_URL in .env is correct."
    exit 1
}

test_obp_api "$OBP_API_URL" || {
    echo -e "${YELLOW}⚠ OBP API unreachable at $OBP_API_URL — continuing anyway${NC}"
    echo "  Keycloak will start but logins will fail until OBP API is reachable."
}

echo -e "${GREEN}✓ Connectivity check done${NC}"


# Step 3: Clean build
echo -e "${CYAN}[3/8] Building Maven Project${NC}"

mvn clean package -DskipTests -q

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Maven build failed${NC}"
    exit 1
fi

# Generate build timestamp for cache invalidation
BUILD_TIMESTAMP=$(date +%s)
JAR_CHECKSUM=$(sha256sum target/obp-keycloak-provider.jar | cut -d' ' -f1)

echo -e "${GREEN}✓ Maven project built (checksum: ${JAR_CHECKSUM:0:8})${NC}"

# Step 4: Stop existing container
echo -e "${CYAN}[4/8] Stopping Existing Container${NC}"

if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1
    echo -e "${GREEN}✓ Container stopped${NC}"
else
    echo -e "${GREEN}✓ No existing container${NC}"
fi

# Step 5: Remove existing container
echo -e "${CYAN}[5/8] Removing Existing Container${NC}"

if docker ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1
    echo -e "${GREEN}✓ Container removed${NC}"
else
    echo -e "${GREEN}✓ No container to remove${NC}"
fi

# Step 6: Build Docker image
echo -e "${CYAN}[6/8] Building Docker Image${NC}"

echo "Building with:"
echo "  Dockerfile: $DOCKERFILE_PATH"
echo "  Image tag: $IMAGE_TAG"
echo "  Keycloak version: $KEYCLOAK_VERSION"

# Force rebuild with cache invalidation; capture output for diagnostics
DOCKER_BUILD_LOG=$(mktemp)
docker build \
    --no-cache \
    --build-arg KEYCLOAK_VERSION="$KEYCLOAK_VERSION" \
    --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
    --build-arg JAR_CHECKSUM="$JAR_CHECKSUM" \
    -t "$IMAGE_TAG" \
    -f "$DOCKERFILE_PATH" \
    . > "$DOCKER_BUILD_LOG" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Docker image build failed${NC}"
    echo ""
    echo -e "${YELLOW}--- Docker build output ---${NC}"
    cat "$DOCKER_BUILD_LOG"
    echo -e "${YELLOW}--- End of build output ---${NC}"
    rm -f "$DOCKER_BUILD_LOG"
    exit 1
fi

rm -f "$DOCKER_BUILD_LOG"
echo -e "${GREEN}✓ Docker image built${NC}"

# Step 7: Start new container
echo -e "${CYAN}[7/8] Starting New Container${NC}"

# Use --network host so the container shares the host's network namespace.
# This means 127.0.0.1 inside the container IS the host's loopback — OBP is
# directly reachable without any address translation.
#
# KC_DB_URL may contain host.docker.internal (written for bridge-mode Docker).
# Rewrite it to localhost so Postgres is reachable via the host's loopback.
CONTAINER_KC_DB_URL="${KC_DB_URL//host.docker.internal/localhost}"
if [ "$CONTAINER_KC_DB_URL" != "$KC_DB_URL" ]; then
    echo -e "${BLUE}  KC_DB_URL rewritten for host network mode:${NC}"
    echo "    .env:      $KC_DB_URL"
    echo "    container: $CONTAINER_KC_DB_URL"
fi

# Container environment variables
CONTAINER_ENV_VARS=(
    "-e" "KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-admin}"
    "-e" "KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}"
    "-e" "KC_DB=postgres"
    "-e" "KC_DB_URL=$CONTAINER_KC_DB_URL"
    "-e" "KC_DB_USERNAME=$KC_DB_USERNAME"
    "-e" "KC_DB_PASSWORD=$KC_DB_PASSWORD"
    "-e" "OBP_API_URL=$OBP_API_URL"
    "-e" "OBP_API_USERNAME=$OBP_API_USERNAME"
    "-e" "OBP_API_PASSWORD=$OBP_API_PASSWORD"
    "-e" "OBP_API_CONSUMER_KEY=$OBP_API_CONSUMER_KEY"
    "-e" "OBP_AUTHUSER_PROVIDER=$OBP_AUTHUSER_PROVIDER"
    # Move Keycloak off port 8080 to avoid conflicting with OBP on the shared host network
    "-e" "KC_HTTP_PORT=${KEYCLOAK_HTTP_PORT:-7787}"
    "-e" "KC_HOSTNAME_STRICT=${KC_HOSTNAME_STRICT:-false}"
    "-e" "KC_HTTP_ENABLED=${KC_HTTP_ENABLED:-true}"
    "-e" "KC_HEALTH_ENABLED=${KC_HEALTH_ENABLED:-true}"
    "-e" "KC_METRICS_ENABLED=${KC_METRICS_ENABLED:-true}"
    "-e" "KC_FEATURES=${KC_FEATURES:-token-exchange}"
    "-e" "FORGOT_PASSWORD_URL=${FORGOT_PASSWORD_URL:-}"
)

# Start container with host networking — no port mapping needed, Keycloak binds
# directly to host ports (HTTP: ${KEYCLOAK_HTTP_PORT:-7787}, HTTPS: 8443, mgmt: 9000)
docker run -d \
    --name "$CONTAINER_NAME" \
    --network host \
    "${CONTAINER_ENV_VARS[@]}" \
    "$IMAGE_TAG" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Container start failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Container started${NC}"

# Step 8: Health check
echo -e "${CYAN}[8/8] Waiting for Service Readiness${NC}"

READY=false
WAIT_COUNT=0
MAX_WAIT=120

while [ $WAIT_COUNT -lt $MAX_WAIT ] && [ "$READY" = false ]; do
    if curl -sk -f -m 5 "https://$KEYCLOAK_HOST:${KEYCLOAK_MGMT_PORT:-9000}/health/ready" > /dev/null 2>&1; then
        READY=true
        echo -e "${GREEN}✓ Service is ready${NC}"

        echo -n "Verifying theme installation... "
        if docker exec "$CONTAINER_NAME" ls /opt/keycloak/themes/obp/theme.properties > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Theme files installed${NC}"
        else
            echo -e "${RED}✗ Theme files missing in container${NC}"
        fi
    else
        echo -n "."
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 2))
    fi
done

if [ "$READY" = false ]; then
    echo ""
    echo -e "${RED}✗ Service failed to become ready within $MAX_WAIT seconds${NC}"
    echo "Check logs: docker logs $CONTAINER_NAME"
    exit 1
fi

# Deployment summary
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}       Deployment Complete - Service Ready      ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

echo "Build Information:"
echo "  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  JAR Checksum: $JAR_CHECKSUM"
echo "  Container: $CONTAINER_NAME"
echo "  Image: $IMAGE_TAG"
echo "  OBP API: $OBP_API_URL"
echo "  Provider: $OBP_AUTHUSER_PROVIDER"
echo ""

echo "Service Access:"
echo "  HTTP:  http://$KEYCLOAK_HOST:${KEYCLOAK_HTTP_PORT:-7787}"
echo "  HTTPS: https://$KEYCLOAK_HOST:${KEYCLOAK_HTTPS_PORT:-8443}"
echo "  Admin: https://$KEYCLOAK_HOST:${KEYCLOAK_HTTPS_PORT:-8443}/admin"
echo "         (${KEYCLOAK_ADMIN:-admin} / ${KEYCLOAK_ADMIN_PASSWORD:-admin})"
echo ""

echo -e "${BLUE}Theme Configuration:${NC}"
echo "  Custom Theme: obp"
echo "  Theme Location: /opt/keycloak/themes/obp/"
echo ""
echo -e "${BLUE}Theme Activation (first-time setup):${NC}"
echo "  1. Access Admin Console: https://$KEYCLOAK_HOST:${KEYCLOAK_HTTPS_PORT:-8443}/admin"
echo "  2. Login with admin credentials (${KEYCLOAK_ADMIN:-admin})"
echo "  3. Go to: Realm Settings > Themes"
echo "  4. Set Login Theme: obp"
echo "  5. Click Save to apply changes"
echo ""

echo "Management:"
echo "  Logs:    docker logs -f $CONTAINER_NAME"
echo "  Stop:    docker stop $CONTAINER_NAME"
echo "  Restart: docker restart $CONTAINER_NAME"
echo "  Remove:  docker rm $CONTAINER_NAME"
echo ""

echo -e "${GREEN}Deployment pipeline completed successfully!${NC}"
