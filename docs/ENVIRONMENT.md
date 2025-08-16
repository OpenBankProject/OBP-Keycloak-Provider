# Environment Configuration Guide

This document provides comprehensive information about configuring the OBP Keycloak Provider using environment variables.

## Overview

The OBP Keycloak Provider has been migrated from hardcoded configuration values in `persistence.xml` to a flexible environment variable-based configuration system. This allows for:

- **Security**: No sensitive credentials in source code
- **Flexibility**: Easy configuration for different environments (dev, staging, prod)
- **Docker-friendly**: Seamless integration with container orchestration
- **Maintainability**: Centralized configuration management

## Quick Start

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit your configuration:**
   ```bash
   nano .env  # or use your preferred editor
   ```

3. **Validate configuration:**
   ```bash
   ./sh/validate-env.sh
   ```

4. **Run the application:**
   ```bash
   ./sh/run-with-env.sh
   ```

## Environment Variables Reference

### Database Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_URL` | Yes | `jdbc:postgresql://localhost:5432/obp_mapped` | PostgreSQL database URL |
| `DB_USER` | Yes | `obp` | Database username |
| `DB_PASSWORD` | Yes | `changeme` | Database password |
| `DB_DRIVER` | No | `org.postgresql.Driver` | JDBC driver class |
| `DB_DIALECT` | No | `org.hibernate.dialect.PostgreSQLDialect` | Hibernate SQL dialect |

#### Database URL Format
```
jdbc:postgresql://hostname:port/database_name
```

**Examples:**
- Local: `jdbc:postgresql://localhost:5432/obp_mapped`
- Remote: `jdbc:postgresql://192.168.1.23:5432/obp_mapped`
- With parameters: `jdbc:postgresql://host:5432/db?ssl=true&sslmode=require`

### Hibernate ORM Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HIBERNATE_DDL_AUTO` | No | `validate` | Schema management mode |
| `HIBERNATE_SHOW_SQL` | No | `true` | Show SQL queries in logs |
| `HIBERNATE_FORMAT_SQL` | No | `true` | Format SQL queries in logs |

#### Hibernate DDL Auto Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `validate` | Validate schema against entities | **Production** (recommended) |
| `update` | Update schema if needed | **Development** |
| `create` | Create schema on startup | **Testing** (destroys existing data) |
| `create-drop` | Create on startup, drop on shutdown | **Unit tests** |
| `none` | No automatic schema management | **Manual schema management** |

### Keycloak Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `KC_BOOTSTRAP_ADMIN_USERNAME` | Yes | `admin` | Initial admin username |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | Yes | `admin` | Initial admin password |
| `KC_HEALTH_ENABLED` | No | `true` | Enable health check endpoints |
| `KC_METRICS_ENABLED` | No | `true` | Enable metrics endpoints |
| `KC_FEATURES` | No | `token-exchange` | Comma-separated list of features |
| `KC_HOSTNAME_STRICT` | No | `false` | Strict hostname validation |
| `KC_LOG_LEVEL` | No | `INFO` | Keycloak log level |

### Application Logging

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `LOG_LEVEL` | No | `INFO` | Application log level for `io.tesobe` package |

#### Log Levels
- `TRACE`: Most verbose, shows all execution details
- `DEBUG`: Detailed information for debugging
- `INFO`: General information about application flow
- `WARN`: Warning messages about potential issues
- `ERROR`: Error messages only

## Configuration Examples

### Development Environment
```bash
# Database (local PostgreSQL)
DB_URL=jdbc:postgresql://localhost:5432/obp_mapped_dev
DB_USER=obp_dev
DB_PASSWORD=dev_password_123

# Keycloak (development settings)
KC_BOOTSTRAP_ADMIN_USERNAME=admin
KC_BOOTSTRAP_ADMIN_PASSWORD=dev_admin_456
KC_HOSTNAME_STRICT=false
KC_LOG_LEVEL=DEBUG

# Hibernate (development settings)
HIBERNATE_DDL_AUTO=update
HIBERNATE_SHOW_SQL=true
LOG_LEVEL=DEBUG
```

### Production Environment
```bash
# Database (production PostgreSQL with SSL)
DB_URL=jdbc:postgresql://prod-db.company.com:5432/obp_mapped?ssl=true&sslmode=require
DB_USER=obp_prod
DB_PASSWORD=very_strong_production_password_2023!

# Keycloak (production settings)
KC_BOOTSTRAP_ADMIN_USERNAME=keycloak_admin
KC_BOOTSTRAP_ADMIN_PASSWORD=super_secure_admin_password_2023!
KC_HOSTNAME_STRICT=true
KC_LOG_LEVEL=WARN
KC_HEALTH_ENABLED=true
KC_METRICS_ENABLED=true

# Hibernate (production settings)
HIBERNATE_DDL_AUTO=validate
HIBERNATE_SHOW_SQL=false
HIBERNATE_FORMAT_SQL=false
LOG_LEVEL=WARN
```

### Docker Compose Environment
```bash
# Database (Docker network)
DB_URL=jdbc:postgresql://postgres:5432/obp_mapped
DB_USER=obp
DB_PASSWORD=docker_password_123

# Keycloak (Docker settings)
KC_BOOTSTRAP_ADMIN_USERNAME=admin
KC_BOOTSTRAP_ADMIN_PASSWORD=docker_admin_456
KC_HOSTNAME_STRICT=false
```

## Deployment Methods

### 1. Local Development

```bash
# Setup
cp .env.example .env
nano .env

# Validate and run
./sh/validate-env.sh
./sh/run-with-env.sh
```

### 2. Docker Run

```bash
docker run \
  -e DB_URL="jdbc:postgresql://host:5432/db" \
  -e DB_USER="user" \
  -e DB_PASSWORD="password" \
  -e KC_BOOTSTRAP_ADMIN_USERNAME="admin" \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD="admin" \
  -p 8080:8080 \
  -p 8443:8443 \
  obp-keycloak-provider
```

### 3. Docker Compose

```yaml
version: '3.8'
services:
  keycloak:
    build: .
    environment:
      - DB_URL=jdbc:postgresql://postgres:5432/obp_mapped
      - DB_USER=obp
      - DB_PASSWORD=${DB_PASSWORD}
      - KC_BOOTSTRAP_ADMIN_USERNAME=${ADMIN_USER}
      - KC_BOOTSTRAP_ADMIN_PASSWORD=${ADMIN_PASSWORD}
    env_file:
      - .env
```

### 4. Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: obp-keycloak
spec:
  template:
    spec:
      containers:
      - name: keycloak
        image: obp-keycloak-provider
        env:
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
```

## Security Best Practices

### Password Security
- **Minimum 12 characters** for production passwords
- **Use special characters, numbers, and mixed case**
- **Avoid common passwords** like "password", "admin", "123456"
- **Rotate credentials regularly** (every 90 days recommended)

### Database Security
- **Enable SSL/TLS** for database connections
- **Use least privilege principle** for database user permissions
- **Regular security updates** for PostgreSQL
- **Network isolation** between services

### Keycloak Security
- **Change default admin credentials** immediately after first login
- **Enable HTTPS** in production (`KC_HOSTNAME_STRICT=true`)
- **Use strong realm passwords** and policies
- **Regular security updates** for Keycloak

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed
```
Error: Connection refused to 192.168.1.23:5432
```

**Solutions:**
- Verify database server is running
- Check firewall rules and network connectivity
- Validate `DB_URL` format
- Test connection: `pg_isready -h 192.168.1.23 -p 5432`

#### 2. Authentication Failed
```
Error: FATAL: password authentication failed for user "obp"
```

**Solutions:**
- Verify `DB_USER` and `DB_PASSWORD` are correct
- Check PostgreSQL user permissions
- Ensure user has access to the specified database

#### 3. Schema Validation Failed
```
Error: Schema-validation: missing table [authuser]
```

**Solutions:**
- Set `HIBERNATE_DDL_AUTO=update` for development
- Run database schema creation scripts
- Verify database user has DDL permissions

#### 4. Keycloak Won't Start
```
Error: Failed to start quarkus
```

**Solutions:**
- Check all required environment variables are set
- Run `./sh/validate-env.sh` for detailed validation
- Check Keycloak logs for specific error messages
- Verify no port conflicts (8080, 8443)

### Debugging Steps

1. **Validate configuration:**
   ```bash
   ./sh/validate-env.sh
   ```

2. **Compare with example:**
   ```bash
   ./sh/compare-env.sh
   ```

3. **Test database connectivity:**
   ```bash
   docker run --rm postgres:15 pg_isready -h YOUR_DB_HOST -p 5432
   ```

4. **Check Keycloak logs:**
   ```bash
   docker logs -f obp-keycloak
   ```

5. **Verify environment variables in container:**
   ```bash
   docker exec obp-keycloak env | grep -E "(DB_|KC_|HIBERNATE_)"
   ```

## Migration from Hardcoded Configuration

If you're migrating from the previous hardcoded configuration:

### Before (hardcoded in persistence.xml)
```xml
<property name="javax.persistence.jdbc.url" value="jdbc:postgresql://192.168.1.23:5432/obp_mapped"/>
<property name="javax.persistence.jdbc.user" value="obp"/>
<property name="javax.persistence.jdbc.password" value="f"/>
```

### After (environment variables)
```bash
# In .env file
DB_URL=jdbc:postgresql://192.168.1.23:5432/obp_mapped
DB_USER=obp
DB_PASSWORD=f
```

### Migration Steps
1. Note your current database connection details from `persistence.xml`
2. Create `.env` file: `cp .env.example .env`
3. Update `.env` with your actual values
4. Test with: `./sh/validate-env.sh`
5. Deploy with: `./sh/run-with-env.sh`

## Advanced Configuration

### Custom Features
Enable additional Keycloak features:
```bash
KC_FEATURES=token-exchange,admin-fine-grained-authz,declarative-user-profile
```

### Performance Tuning
For production environments:
```bash
# Reduce logging for performance
HIBERNATE_SHOW_SQL=false
HIBERNATE_FORMAT_SQL=false
KC_LOG_LEVEL=WARN
LOG_LEVEL=WARN

# Strict hostname validation
KC_HOSTNAME_STRICT=true
```

### Development Debugging
For troubleshooting:
```bash
# Maximum logging
KC_LOG_LEVEL=DEBUG
LOG_LEVEL=TRACE
HIBERNATE_SHOW_SQL=true
HIBERNATE_FORMAT_SQL=true

# Schema auto-update
HIBERNATE_DDL_AUTO=update
```

## Support and Documentation

- **Environment validation**: `./sh/validate-env.sh`
- **Configuration comparison**: `./sh/compare-env.sh`
- **Complete example**: `.env.example`
- **Keycloak documentation**: [https://www.keycloak.org/documentation](https://www.keycloak.org/documentation)
- **Quarkus configuration**: [https://quarkus.io/guides/config-reference](https://quarkus.io/guides/config-reference)

---

**Last Updated**: August 2025  
**Version**: 1.0  
**Compatibility**: Keycloak 26.0.5, Java 17+