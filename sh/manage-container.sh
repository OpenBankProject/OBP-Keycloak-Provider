#!/bin/bash

# Container Management Script for OBP Keycloak Provider
# This script helps manage the Keycloak container after interrupting run-with-env.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER_NAME="obp-keycloak"

echo -e "${BLUE}OBP Keycloak Provider - Container Management${NC}"
echo "============================================"

# Check container status
check_container_status() {
    if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo -e "${GREEN}Container '$CONTAINER_NAME' is running${NC}"
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        return 0
    elif docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo -e "${YELLOW}Container '$CONTAINER_NAME' exists but is not running${NC}"
        docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        return 1
    else
        echo -e "${RED}Container '$CONTAINER_NAME' not found${NC}"
        return 2
    fi
}

# Show menu
show_menu() {
    echo ""
    echo "Available actions:"
    echo "  1) View container status"
    echo "  2) View logs (follow)"
    echo "  3) View logs (last 50 lines)"
    echo "  4) Stop container"
    echo "  5) Start container"
    echo "  6) Restart container"
    echo "  7) Remove container"
    echo "  8) Stop and remove container"
    echo "  9) Access URLs"
    echo "  0) Exit"
    echo ""
}

# View logs
view_logs() {
    local mode="$1"
    if check_container_status > /dev/null; then
        echo ""
        if [ "$mode" = "follow" ]; then
            echo -e "${BLUE}Following logs (Press Ctrl+C to return to menu)...${NC}"
            echo ""
            docker logs -f "$CONTAINER_NAME"
        else
            echo -e "${BLUE}Last 50 log lines:${NC}"
            echo ""
            docker logs --tail 50 "$CONTAINER_NAME"
        fi
    else
        echo -e "${RED}Cannot view logs: container is not running${NC}"
    fi
}

# Stop container
stop_container() {
    if check_container_status > /dev/null; then
        echo ""
        echo "Stopping container..."
        docker stop "$CONTAINER_NAME"
        echo -e "${GREEN}Container stopped successfully${NC}"
    else
        echo -e "${YELLOW}Container is not running${NC}"
    fi
}

# Start container
start_container() {
    local status
    check_container_status > /dev/null
    status=$?

    if [ $status -eq 0 ]; then
        echo -e "${YELLOW}Container is already running${NC}"
    elif [ $status -eq 1 ]; then
        echo ""
        echo "Starting existing container..."
        docker start "$CONTAINER_NAME"
        echo -e "${GREEN}Container started successfully${NC}"
    else
        echo -e "${RED}Container does not exist. Run ./run-with-env.sh to create it.${NC}"
    fi
}

# Restart container
restart_container() {
    local status
    check_container_status > /dev/null
    status=$?

    if [ $status -eq 2 ]; then
        echo -e "${RED}Container does not exist. Run ./run-with-env.sh to create it.${NC}"
        return
    fi

    echo ""
    echo "Restarting container..."
    docker restart "$CONTAINER_NAME"
    echo -e "${GREEN}Container restarted successfully${NC}"
}

# Remove container
remove_container() {
    local status
    check_container_status > /dev/null
    status=$?

    if [ $status -eq 2 ]; then
        echo -e "${YELLOW}Container does not exist${NC}"
        return
    fi

    echo ""
    read -p "Are you sure you want to remove the container? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [ $status -eq 0 ]; then
            echo "Stopping and removing container..."
            docker stop "$CONTAINER_NAME"
        else
            echo "Removing container..."
        fi
        docker rm "$CONTAINER_NAME"
        echo -e "${GREEN}Container removed successfully${NC}"
    else
        echo "Operation cancelled"
    fi
}

# Stop and remove container
stop_and_remove() {
    if check_container_status > /dev/null; then
        echo ""
        read -p "Are you sure you want to stop and remove the container? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "Stopping and removing container..."
            docker stop "$CONTAINER_NAME"
            docker rm "$CONTAINER_NAME"
            echo -e "${GREEN}Container stopped and removed successfully${NC}"
        else
            echo "Operation cancelled"
        fi
    else
        echo -e "${YELLOW}Container is not running${NC}"
    fi
}

# Show access URLs
show_urls() {
    if check_container_status > /dev/null; then
        echo ""
        echo -e "${GREEN}Keycloak Access URLs:${NC}"
        echo "  HTTP:  http://localhost:8080"
        echo "  HTTPS: https://localhost:8443"
        echo ""
        echo "Admin Console:"
        echo "  HTTP:  http://localhost:8080/admin"
        echo "  HTTPS: https://localhost:8443/admin"
        echo ""
        echo "Default Admin Credentials:"
        echo "  Username: admin"
        echo "  Password: admin (change after first login)"
    else
        echo -e "${RED}Container is not running. URLs not accessible.${NC}"
    fi
}

# Main loop
main() {
    echo ""
    check_container_status

    while true; do
        show_menu
        read -p "Select an action (0-9): " choice

        case $choice in
            1)
                echo ""
                check_container_status
                ;;
            2)
                view_logs "follow"
                ;;
            3)
                view_logs "tail"
                ;;
            4)
                stop_container
                ;;
            5)
                start_container
                ;;
            6)
                restart_container
                ;;
            7)
                remove_container
                ;;
            8)
                stop_and_remove
                ;;
            9)
                show_urls
                ;;
            0)
                echo ""
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select 0-9.${NC}"
                ;;
        esac

        echo ""
        echo "Press Enter to continue..."
        read
    done
}

# Run main function
main
