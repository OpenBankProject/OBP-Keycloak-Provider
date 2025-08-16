#!/bin/bash

# Script to run Keycloak with environment variables
# This script loads environment variables from .env file and runs the application
# Supports both standard and themed deployment options

set -e

# Signal handler for Ctrl+C
cleanup_and_exit() {
    echo ""
    echo ""
    echo -e "${YELLOW}=== Script Interrupted ===${NC}"
    echo -e "${GREEN}The Keycloak container is still running in the background.${NC}"
    echo ""
    echo "Container status:"
    docker ps --filter "name=obp-keycloak" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  Container may not be running"
    echo ""
    echo "To manage the container:"
    echo "  View logs:    docker logs -f obp-keycloak"
    echo "  Stop:         docker stop obp-keycloak"
    echo "  Remove:       docker rm obp-keycloak"
    echo "  Stop & Remove: docker stop obp-keycloak && docker rm obp-keycloak"
    echo "  Manage:       ./sh/manage-container.sh"
    echo ""
    echo "Access URLs (if container is running):"
    echo "  HTTP:  http://localhost:8080"
    echo "  HTTPS: https://localhost:8443"
    echo ""
    exit 0
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --themed, -t    Build with custom themes support"
    echo "  --standard, -s  Build standard deployment (default)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Standard deployment"
    echo "  $0 --standard   # Standard deployment"
    echo "  $0 --themed     # Themed deployment with custom UI"
    echo ""
}

# Trap Ctrl+C (SIGINT) and call cleanup function
trap cleanup_and_exit SIGINT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default deployment type
DEPLOYMENT_TYPE="standard"
DOCKERFILE_PATH="docker/Dockerfile"
IMAGE_TAG="obp-keycloak-provider"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --themed|-t)
            DEPLOYMENT_TYPE="themed"
            DOCKERFILE_PATH=".github/Dockerfile_themed"
            IMAGE_TAG="obp-keycloak-provider-themed"
            shift
            ;;
        --standard|-s)
            DEPLOYMENT_TYPE="standard"
            DOCKERFILE_PATH="docker/Dockerfile"
            IMAGE_TAG="obp-keycloak-provider"
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

echo -e "${GREEN}OBP Keycloak Provider - Development Setup${NC}"
echo "============================================"
echo -e "${BLUE}Deployment Type: ${DEPLOYMENT_TYPE}${NC}"
if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo -e "${BLUE}Custom theming: Enabled (Dark theme with custom styling)${NC}"
fi
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file not found.${NC}"
    echo "Creating .env file from .env.example..."

    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env file from .env.example${NC}"
        echo -e "${YELLOW}Please edit .env file with your database configuration before continuing.${NC}"
        read -p "Press Enter to continue after editing .env file..."
    else
        echo -e "${RED}Error: .env.example file not found!${NC}"
        exit 1
    fi
fi

# Load environment variables from .env file
echo "Loading environment variables from .env file..."
export $(grep -v '^#' .env | xargs)

# Validate required environment variables
echo "Validating environment variables..."
required_vars=("DB_URL" "DB_USER" "DB_PASSWORD")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    for var in "${missing_vars[@]}"; do
        echo -e "${RED}  - $var${NC}"
    done
    echo -e "${YELLOW}Please set these variables in your .env file.${NC}"
    exit 1
fi

echo -e "${GREEN}Environment variables validated${NC}"

# Display current configuration (without password)
echo ""
echo "Current Configuration:"
echo "  Deployment Type: $DEPLOYMENT_TYPE"
echo "  Dockerfile: $DOCKERFILE_PATH"
echo "  Image Tag: $IMAGE_TAG"
echo "  Database URL: $DB_URL"
echo "  Database User: $DB_USER"
echo "  Database Password: [HIDDEN]"
echo "  Hibernate DDL Auto: ${HIBERNATE_DDL_AUTO:-validate}"

if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo ""
    echo "Theme Configuration:"
    echo "  Theme Name: obp"
    echo "  Base Theme: keycloak"
    echo "  Custom Styling: Dark theme with modern UI"
    echo "  Internationalization: English (customizable)"
fi
echo ""

# For themed deployment, we need to ensure theme files exist
if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo "Validating theme files..."
    theme_files=("themes/obp/theme.properties" "themes/obp/login/resources/css/styles.css" "themes/obp/login/messages/messages_en.properties")
    missing_theme_files=()

    for file in "${theme_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_theme_files+=("$file")
        fi
    done

    if [ ${#missing_theme_files[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required theme files:${NC}"
        for file in "${missing_theme_files[@]}"; do
            echo -e "${RED}  - $file${NC}"
        done
        echo -e "${YELLOW}Theme files are required for themed deployment.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Theme files validated${NC}"
fi

# Build the project with environment variables
echo "Building the project with environment variables..."
mvn clean package -DskipTests \
    -DDB_URL="$DB_URL" \
    -DDB_USER="$DB_USER" \
    -DDB_PASSWORD="$DB_PASSWORD" \
    -DDB_DRIVER="${DB_DRIVER:-org.postgresql.Driver}" \
    -DDB_DIALECT="${DB_DIALECT:-org.hibernate.dialect.PostgreSQLDialect}" \
    -DHIBERNATE_DDL_AUTO="${HIBERNATE_DDL_AUTO:-validate}" \
    -DHIBERNATE_SHOW_SQL="${HIBERNATE_SHOW_SQL:-true}" \
    -DHIBERNATE_FORMAT_SQL="${HIBERNATE_FORMAT_SQL:-true}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Maven build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Project built successfully${NC}"

# Build Docker image
if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo "Building Docker image with custom themes..."
else
    echo "Building Docker image (standard)..."
fi

# Build Docker image with appropriate arguments
if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    docker build -t "$IMAGE_TAG" -f "$DOCKERFILE_PATH" \
        --build-arg DB_URL="$DB_URL" \
        --build-arg DB_USER="$DB_USER" \
        --build-arg DB_PASSWORD="$DB_PASSWORD" \
        --build-arg DB_DRIVER="${DB_DRIVER:-org.postgresql.Driver}" \
        --build-arg DB_DIALECT="${DB_DIALECT:-org.hibernate.dialect.PostgreSQLDialect}" \
        --build-arg HIBERNATE_DDL_AUTO="${HIBERNATE_DDL_AUTO:-validate}" \
        --build-arg HIBERNATE_SHOW_SQL="${HIBERNATE_SHOW_SQL:-true}" \
        --build-arg HIBERNATE_FORMAT_SQL="${HIBERNATE_FORMAT_SQL:-true}" \
        .
else
    docker build -t "$IMAGE_TAG" -f "$DOCKERFILE_PATH" .
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Docker image built successfully${NC}"

# Stop existing container if running
echo "Stopping existing containers..."
docker stop obp-keycloak 2>/dev/null || true
docker rm obp-keycloak 2>/dev/null || true

# Prepare environment variables for container
CONTAINER_ENV_VARS=(
    "-e" "KEYCLOAK_ADMIN=admin"
    "-e" "KEYCLOAK_ADMIN_PASSWORD=admin"
    "-e" "DB_URL=$DB_URL"
    "-e" "DB_USER=$DB_USER"
    "-e" "DB_PASSWORD=$DB_PASSWORD"
    "-e" "DB_DRIVER=${DB_DRIVER:-org.postgresql.Driver}"
    "-e" "DB_DIALECT=${DB_DIALECT:-org.hibernate.dialect.PostgreSQLDialect}"
    "-e" "HIBERNATE_DDL_AUTO=${HIBERNATE_DDL_AUTO:-validate}"
    "-e" "HIBERNATE_SHOW_SQL=${HIBERNATE_SHOW_SQL:-true}"
    "-e" "HIBERNATE_FORMAT_SQL=${HIBERNATE_FORMAT_SQL:-true}"
)

# Theme files are automatically available in themed deployment
# Users can select the 'obp' theme in Keycloak Admin Console > Realm Settings > Themes

# Run the container with environment variables
if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo "Starting Keycloak container with custom themes..."
else
    echo "Starting Keycloak container..."
fi

docker run -d \
    --name obp-keycloak \
    -p 8080:8080 \
    -p 8443:8443 \
    "${CONTAINER_ENV_VARS[@]}" \
    "$IMAGE_TAG"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start Docker container!${NC}"
    exit 1
fi

echo -e "${GREEN}Keycloak container started successfully${NC}"
echo ""
echo "Container Information:"
echo "  Container Name: obp-keycloak"
echo "  Image: $IMAGE_TAG"
echo "  Deployment Type: $DEPLOYMENT_TYPE"
echo "  HTTP Port: 8080"
echo "  HTTPS Port: 8443"
echo "  Admin Username: admin"
echo "  Admin Password: admin"

if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo ""
    echo "Theme Information:"
    echo "  Custom Theme Available: obp"
    echo "  Styling: Dark theme with modern UI"
    echo "  Login Theme: Custom OBP branding"
    echo "  To activate: Admin Console > Realm Settings > Themes > Login Theme > obp"
fi

echo ""
echo "Access URLs:"
echo "  HTTP:  http://localhost:8080"
echo "  HTTPS: https://localhost:8443"
echo "  Admin Console: https://localhost:8443/admin"
echo ""
echo "Useful Commands:"
echo "  View logs:    docker logs -f obp-keycloak"
echo "  Stop:         docker stop obp-keycloak"
echo "  Remove:       docker rm obp-keycloak"
echo "  Manage:       ./sh/manage-container.sh"
echo ""

if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo -e "${BLUE}Theme Usage Tips:${NC}"
    echo "  - Custom theme 'obp' is available in the theme selector"
    echo "  - To activate: Admin Console > Realm Settings > Themes > Login Theme > obp"
    echo "  - Theme files location in container: /opt/keycloak/themes/obp/"
    echo "  - Customize further by editing files in themes/ directory and rebuilding"
    echo ""
fi

# Follow container logs continuously
echo ""
echo -e "${GREEN}Setup complete! Keycloak is starting up...${NC}"
if [ "$DEPLOYMENT_TYPE" = "themed" ]; then
    echo -e "${BLUE}Custom themes are being loaded...${NC}"
fi
echo -e "${YELLOW}Following container logs (Press Ctrl+C to exit and return to shell)...${NC}"
echo -e "${RED}Note: The container will continue running in the background after Ctrl+C${NC}"
echo ""

# Follow logs continuously
docker logs -f obp-keycloak
