# Workflow Guide

This document explains the typical workflow when developing and running the OBP Keycloak Provider, including container behavior and management.

## Development Workflow

### 1. Initial Setup

```bash
# Clone and setup the project
git clone <repository-url>
cd OBP-Keycloak-Provider

# Setup environment configuration
cp .env.example .env
nano .env  # Edit with your database credentials

# Validate configuration
./sh/validate-env.sh
```

### 2. Running the Application

```bash
# Build and run with environment variables
./sh/run-with-env.sh
```

This script will:
1. Load environment variables from `.env` file
2. Validate required configurations
3. Build the Maven project with environment substitution
4. Build Docker image with your provider
5. Stop any existing container
6. Start new container with your configuration
7. Follow container logs in real-time

### 3. Container Behavior After Ctrl+C

**Important**: When you press `Ctrl+C` during log following:

- **Script terminates**: The `run-with-env.sh` script stops
- **Container continues**: The Docker container keeps running in the background
- **Services remain accessible**: Keycloak stays available at http://localhost:8080 and https://localhost:8443

### 4. Managing the Running Container

After pressing `Ctrl+C`, you have several options:

#### Option A: Interactive Management
```bash
./sh/manage-container.sh
```

This provides an interactive menu to:
- Check container status
- View logs (follow or tail)
- Start/stop/restart container
- Remove container
- Show access URLs

#### Option B: Direct Commands
```bash
# View logs
docker logs -f obp-keycloak

# Stop container
docker stop obp-keycloak

# Start stopped container
docker start obp-keycloak

# Remove container
docker rm obp-keycloak

# Stop and remove in one command
docker stop obp-keycloak && docker rm obp-keycloak
```

## Common Scenarios

### Scenario 1: Development Cycle

```bash
# Make code changes
nano src/main/java/io/tesobe/providers/KcUserStorageProvider.java

# Rebuild and restart
./sh/run-with-env.sh  # This automatically stops old container

# Press Ctrl+C when done viewing logs
# Container continues running for testing
```

### Scenario 2: Configuration Changes

```bash
# Update environment variables
nano .env

# Validate changes
./sh/validate-env.sh

# Rebuild with new configuration
./sh/run-with-env.sh
```

### Scenario 3: Debugging

```bash
# Start with logs
./sh/run-with-env.sh

# Press Ctrl+C to stop log following
# Use management script for specific log viewing
./sh/manage-container.sh
# Select option 2 for live logs or option 3 for recent logs
```

### Scenario 4: Clean Shutdown

```bash
# Stop and remove container
./sh/manage-container.sh
# Select option 8 (Stop and remove container)

# Or use direct command
docker stop obp-keycloak && docker rm obp-keycloak
```

## Container Lifecycle

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ ./run-with-env.sh │───→│ Container Running │───→│ Press Ctrl+C   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                         │
                                │                         ▼
                                │                ┌─────────────────┐
                                │                │ Script Exits    │
                                │                │ Container Runs  │
                                │                └─────────────────┘
                                │                         │
                                ▼                         ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │ Access Keycloak  │    │ Manage Container│
                       │ http://localhost │    │ ./manage.sh     │
                       └──────────────────┘    └─────────────────┘
```

## Port Usage

The container exposes these ports:

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | HTTP | Keycloak web interface |
| 8443 | HTTPS | Keycloak web interface (SSL) |
| 9000 | HTTP | Internal health/metrics |

## Environment Files

| File | Purpose |
|------|---------|
| `.env.example` | Template with documentation and default values |
| `.env` | Your actual configuration (never commit this) |

## Script Reference

| Script | Purpose | Container Impact |
|--------|---------|------------------|
| `./sh/run-with-env.sh` | Build and run container with logs | Stops old, starts new |
| `./sh/manage-container.sh` | Interactive container management | Manages existing |
| `./sh/validate-env.sh` | Validate environment configuration | No impact |
| `./sh/compare-env.sh` | Compare .env with .env.example | No impact |

## Best Practices

### During Development
1. **Use the management script** after Ctrl+C for container operations
2. **Keep container running** between code changes when possible
3. **Monitor logs** for debugging and error tracking
4. **Validate configuration** before rebuilding

### Production Deployment
1. **Use docker-compose** or Kubernetes for orchestration
2. **Set strong passwords** and change defaults
3. **Enable HTTPS** with proper certificates
4. **Monitor container health** and logs
5. **Use secrets management** instead of .env files

### Container Cleanup
- **During development**: Leave container running for faster iteration
- **End of session**: Stop and remove container to free resources
- **Disk space issues**: Remove old images with `docker system prune`

## Troubleshooting Container Issues

### Container Won't Start
```bash
# Check what went wrong
docker logs obp-keycloak

# Validate environment
./sh/validate-env.sh

# Check port conflicts
netstat -tulpn | grep -E ":8080|:8443"
```

### Container Stops Unexpectedly
```bash
# Check exit code and logs
docker ps -a --filter "name=obp-keycloak"
docker logs obp-keycloak

# Check system resources
docker stats --no-stream
```

### Cannot Access Keycloak
```bash
# Verify container is running
docker ps --filter "name=obp-keycloak"

# Check port mapping
docker port obp-keycloak

# Test connectivity
curl -k https://localhost:8443/health/ready
```

This workflow ensures smooth development while providing clear guidance on container management after script interruption.