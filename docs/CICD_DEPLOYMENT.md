# development/run-local-postgres-cicd.sh Deployment Guide

This guide covers the CI/CD-style deployment script that provides predictable, automated deployment for local development environments.

## Overview

The deployment script (`development/run-local-postgres-cicd.sh`) is designed for local development environments where you want:

- **Always build**: No conditional logic — always rebuild everything
- **Always replace**: Stop and remove existing containers every time
- **Cache invalidation**: Docker layers rebuild when JAR file changes
- **Fast feedback**: Clear success/failure indicators
- **Deterministic**: Same inputs always produce same outputs

## Usage

### Basic Deployment
```bash
./development/run-local-postgres-cicd.sh
```

### Themed Deployment
```bash
./development/run-local-postgres-cicd.sh --themed
```

## Prerequisites

1. **OBP API** running and reachable from the host
2. **OBP admin account** with roles: `CanGetAnyUser`, `CanVerifyUserCredentials`, `CanGetOidcClient`
3. **Keycloak PostgreSQL database** accessible from Docker containers
4. **Environment file**: `.env` with proper configuration

## Script Pipeline

The script follows an 8-step pipeline:

### [1/8] Environment Validation
- Checks Docker installation and daemon
- Validates Maven installation
- Loads and validates `.env` configuration
- Verifies all required environment variables
- **Themed deployments**: Validates theme files and structure

### [2/8] OBP API Connectivity
- Tests HTTP reachability of `OBP_API_URL`
- Logs a warning (non-fatal) if OBP API is not reachable at deploy time

### [3/8] Maven Build
- Runs `mvn clean package -DskipTests`
- Generates JAR checksum for Docker cache invalidation
- Creates build timestamp

### [4/8] Container Cleanup — Stop
- Stops existing container if running
- Non-blocking if container doesn't exist

### [5/8] Container Cleanup — Remove
- Removes existing container if exists
- Ensures clean slate for new deployment

### [6/8] Docker Image Build
- Builds image with `--no-cache` flag
- Passes build timestamp and JAR checksum as build args
- Forces cache invalidation when JAR changes

### [7/8] Container Start
- Creates new container with fresh configuration
- Translates `localhost`/`127.0.0.1` in `OBP_API_URL` to `host.docker.internal`
  so the container can reach OBP running on the host
- Maps standard ports (7787 HTTP, 8443 HTTPS, 9000 management)

### [8/8] Health Check
- Waits up to 2 minutes for service readiness
- Uses Keycloak's `/health/ready` endpoint on management port (9000)
- Provides clear success/failure indication

## Theme Validation (--themed flag)

**Themed Deployment Requirements**:
- ✅ `themes/obp/login/theme.properties` with valid content
- ✅ `themes/obp/login/` directory structure
- ✅ Required templates: `login.ftl`, `template.ftl`
- ✅ Optional: CSS files, images, message files

## Environment Configuration

### Required .env Variables
```bash
# Keycloak Admin
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin

# Keycloak Internal Database
KC_DB_URL=jdbc:postgresql://host.docker.internal:5432/keycloakdb
KC_DB_USERNAME=keycloak
KC_DB_PASSWORD=your_keycloak_db_password

# OBP API — authentication delegates to these endpoints
OBP_API_URL=http://localhost:8080
OBP_API_USERNAME=obp_admin_user
OBP_API_PASSWORD=obp_admin_password
OBP_API_CONSUMER_KEY=your_consumer_key

# MANDATORY: only users whose OBP provider field matches this value are authenticated
OBP_AUTHUSER_PROVIDER=http://127.0.0.1:8080
```

### Optional .env Variables (with defaults)
```bash
# Keycloak Runtime
KC_HTTP_ENABLED=true
KC_HOSTNAME_STRICT=false
KC_HEALTH_ENABLED=true
KC_METRICS_ENABLED=true
KC_FEATURES=token-exchange

# Custom forgot-password link (leave empty for Keycloak's built-in flow)
FORGOT_PASSWORD_URL=

# Local Development Ports
KEYCLOAK_HTTP_PORT=7787
KEYCLOAK_HTTPS_PORT=8443
KEYCLOAK_MGMT_PORT=9000
```

## Monitoring and Troubleshooting

### Script Output
The script provides clear status indicators:
- ✓ Green checkmarks for successful steps
- ✗ Red X marks for failures
- Step-by-step progress tracking

### Container Management
```bash
# View logs
docker logs -f obp-keycloak-local

# Check status
docker ps --filter name=obp-keycloak-local

# Stop and remove
docker stop obp-keycloak-local && docker rm obp-keycloak-local
```

### Common Issues

#### OBP API unreachable from container
Inside Docker, `127.0.0.1` resolves to the container itself, not the host. The script
automatically rewrites `localhost` / `127.0.0.1` to `host.docker.internal`. If OBP runs
on a different host, set `OBP_API_URL` to its actual hostname or IP.

#### Token fetch returns 401
Check `OBP_API_USERNAME`, `OBP_API_PASSWORD`, and `OBP_API_CONSUMER_KEY`. The consumer
key must be registered in OBP for Direct Login.

#### User not found at login
Confirm `OBP_AUTHUSER_PROVIDER` exactly matches the `provider` field stored in OBP for
that user (e.g. `http://127.0.0.1:8080`).

#### Docker Build Failures
```bash
# Check Docker space
docker system df

# Clean up if needed
docker system prune -f
```

#### Container Start Issues
```bash
# Check port conflicts
netstat -tulpn | grep -E ':(7787|8443|9000)'

# Review container logs
docker logs obp-keycloak-local
```

#### Theme Issues (--themed deployment)
```bash
# Check theme files
find themes/obp -type f

# Test with standard deployment first
./development/run-local-postgres-cicd.sh
```

## Access Information

After successful deployment:

### Service URLs
- **HTTP**: http://localhost:7787
- **HTTPS**: https://localhost:8443
- **Admin Console**: https://localhost:8443/admin

### Default Credentials
- **Username**: admin
- **Password**: admin

### Theme Configuration (--themed deployments)
1. Access Admin Console: https://localhost:8443/admin
2. Login with admin credentials
3. Go to: Realm Settings > Themes
4. Select "obp" theme for Login theme
5. Save configuration

## Best Practices

1. **Use secure passwords**: Never use default passwords in production
2. **Validate configuration**: Run script to check all required variables
3. **Monitor logs**: Check `docker logs obp-keycloak-local` for issues
4. **Clean environment**: Script ensures clean state on each run
5. **Theme testing**: Test standard deployment before themed if issues occur

## Support

For issues with the deployment script:

1. Check the troubleshooting section above
2. Review container logs: `docker logs obp-keycloak-local`
3. Ensure `.env` file contains all required variables
4. Check Docker system resources and cleanup if needed

The script is designed to fail fast and provide clear error messages to facilitate quick problem resolution in local development environments.
