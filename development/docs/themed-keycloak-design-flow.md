# Design Flow: Running a Themed Keycloak Local Instance

## Overview

This document describes the end-to-end process for building and running a locally themed Keycloak instance with the OBP (Open Bank Project) custom User Storage SPI provider. The themed deployment packages OBP-branded login pages (including a light `obp` theme and a dark `obp-dark` variant) into the Keycloak image alongside the custom provider JAR.

---

## Architecture

```
+-------------------+        +-----------------------------+        +---------------------+
|   Host Machine    |        |   Docker Container          |        |   PostgreSQL (host) |
|                   |        |   (obp-keycloak-local)      |        |                     |
|  .env             |        | +-------------------------+ |        | keycloakdb          |
|  themes/obp/      | -----> | | Keycloak 26.5.3         | | <----> | (realm data,        |
|  themes/obp-dark/ |  build | |   + obp-keycloak-       | |  JDBC  |  clients, tokens)   |
|  src/ + pom.xml   |        | |     provider.jar        | |        +---------------------+
|                   |        | |   + obp theme           | |
|                   |        | |   + obp-dark theme      | |        +---------------------+
|                   |        | +-------------------------+ |        |   OBP API (host)    |
|                   |        |   Ports: 7787 -> 8080       |  HTTP  |                     |
|                   |        |          8443 -> 8443       | <----> | /obp/v6.0.0/...     |
+-------------------+        +-----------------------------+        +---------------------+
```

**Keycloak uses two backends:**

| Backend      | Purpose                                         | Protocol |
|--------------|-------------------------------------------------|----------|
| `keycloakdb` | Keycloak internal data (realms, clients, tokens) | JDBC     |
| OBP API      | User lookup and credential verification          | HTTP     |

---

## Entry Point

```bash
./development/run-local-postgres-cicd.sh --themed
```

The `--themed` (or `-t`) flag activates the themed deployment path. Without it, a standard (theme-less) image is built.

---

## Step-by-Step Pipeline Flow

The deployment script executes an 8-step pipeline:

```
  [1] Validate Environment
         |
         v
  [2] Test Database Connectivity
         |
         v
  [3] Build Maven Project (host)
         |
         v
  [4] Stop Existing Container
         |
         v
  [5] Remove Existing Container
         |
         v
  [6] Build Docker Image (multi-stage)
         |
         v
  [7] Start New Container
         |
         v
  [8] Health Check + Theme Verification
```

### Step 1: Validate Environment

- Checks that `docker`, `mvn` are installed and Docker daemon is running.
- Sources `.env` from the project root.
- Validates the following **required** environment variables:
  - `KC_DB_URL`, `KC_DB_USERNAME`, `KC_DB_PASSWORD` (Keycloak internal DB)
  - `OBP_API_URL`, `OBP_API_USERNAME`, `OBP_API_PASSWORD`, `OBP_API_CONSUMER_KEY` (OBP API)
  - `OBP_AUTHUSER_PROVIDER` (mandatory provider filter)
- **Themed-specific**: runs `validate_theme_files()` which verifies:
  - `themes/obp/` directory exists
  - `themes/obp/login/theme.properties` contains `parent=base` and `styles=`
  - `themes/obp/login/` exists with `login.ftl` and `template.ftl`
  - Optionally checks for CSS, images, and i18n message files

### Step 2: Test OBP API Connectivity

- Tests HTTP reachability of `OBP_API_URL`.
- Non-fatal warning if OBP is not reachable at deploy time (provider will retry at runtime).

### Step 3: Build Maven Project

```bash
mvn clean package -DskipTests -q
```

- Compiles the OBP Keycloak User Storage SPI provider.
- Produces `target/obp-keycloak-provider.jar`.
- A SHA-256 checksum of the JAR is computed for Docker cache invalidation.

### Step 4-5: Container Cleanup

- Stops and removes any existing container named `obp-keycloak-local`.
- Ensures a clean deployment on every run (CI/CD-style idempotency).

### Step 6: Build Docker Image (Multi-Stage)

This is the core of the themed build. The unified Dockerfile at `development/docker/Dockerfile` is used for both standard and themed builds. The `--themed` flag causes the script to pass `--build-arg THEMED=true`.

```
docker build --no-cache \
    --build-arg BUILD_TIMESTAMP=<epoch> \
    --build-arg JAR_CHECKSUM=<sha256> \
    --build-arg THEMED=true \
    -t obp-keycloak-provider-local-themed \
    -f development/docker/Dockerfile .
```

#### Dockerfile Multi-Stage Build

```
  Stage 1: builder (quay.io/keycloak/keycloak:26.5.3)
  +--------------------------------------------------+
  |  Generate self-signed SSL keystore               |
  |  COPY obp-keycloak-provider.jar -> providers/    |
  |  /opt/keycloak/bin/kc.sh build                   |
  |  (pre-compiles extensions + optimizes)           |
  +--------------------------------------------------+
                        |
                        v
  Stage 2: final (quay.io/keycloak/keycloak:26.5.3)
  +--------------------------------------------------+
  |  COPY --from=builder /opt/keycloak/              |
  |  COPY themes/obp/      -> themes/obp/            |
  |  COPY themes/obp-dark/ -> themes/obp-dark/       |
  |  chown keycloak:keycloak themes/                 |
  |                                                  |
  |  IF THEMED=false: rm -rf themes/*                |
  |  IF THEMED=true:  themes are retained            |
  |                                                  |
  |  ENTRYPOINT: kc.sh start-dev --verbose           |
  +--------------------------------------------------+
```

Key detail: themes are always COPYed into the image, but when `THEMED=false` a final `RUN` layer removes them. When `THEMED=true`, both `obp` and `obp-dark` themes are preserved.

No JDBC drivers are included — user authentication goes through the OBP REST API, not direct database access.

### Step 7: Start New Container

The container is launched with:
- Port mappings: `${KEYCLOAK_HTTP_PORT:-7787}:8080`, `${KEYCLOAK_HTTPS_PORT:-8443}:8443`, and `${KEYCLOAK_MGMT_PORT:-9000}:9000`
- `--add-host=host.docker.internal:host-gateway` (allows container to reach host services)
- `localhost`/`127.0.0.1` in `OBP_API_URL` is rewritten to `host.docker.internal` so the container can reach OBP running on the host
- All OBP API and Keycloak configuration passed as `-e` environment variables

### Step 8: Health Check + Theme Verification

- Polls `https://<host>:<mgmt_port>/health/ready` every 2 seconds, up to 120 seconds.
- **Themed-specific** post-readiness checks:
  - Tests if theme resources are accessible at `/resources/obp/`
  - Verifies theme files exist inside the container at `/opt/keycloak/themes/obp/login/theme.properties`

---

## Theme Structure

```
themes/
  obp/                              <- Light theme
    theme.properties                 <- parent=base, styles=css/styles.css
    login/
      login.ftl                      <- Login page template
      template.ftl                   <- Base page template
      login-update-profile.ftl       <- Profile update template
      error.ftl                      <- Error page template
      messages/
        messages_en.properties       <- English translations
      resources/
        css/
          styles.css                 <- Custom CSS
        img/
          obp_logo.png               <- OBP logo
          logo2x-1.png               <- Retina logo
          favicon.png                <- Favicon

  obp-dark/                          <- Dark theme variant
    login/
      theme.properties               <- parent=keycloak
      messages/
        messages_en.properties
      resources/
        css/
          styles.css
```

The `obp` theme extends `base` (minimal Keycloak theme) providing full template control. The `obp-dark` theme extends `keycloak` (default Keycloak theme) and overrides only the CSS.

---

## Theme Activation (Post-Deployment)

After the container is running, themes must be manually activated in the Keycloak Admin Console:

1. Open Admin Console at `https://localhost:8443/admin`
2. Log in with admin credentials (default: `admin` / `admin`)
3. Navigate to **Realm Settings > Themes**
4. Set **Login Theme** to `obp` (or `obp-dark`)
5. Click **Save**

---

## Container Management

After deployment, the container can be managed using:

**Interactive tool:**
```bash
./development/manage-container.sh
```

**Direct commands:**
```bash
docker logs -f obp-keycloak-local         # Follow logs
docker stop obp-keycloak-local            # Stop
docker start obp-keycloak-local           # Start
docker restart obp-keycloak-local         # Restart
docker exec obp-keycloak-local \
  ls -la /opt/keycloak/themes/obp/        # Inspect themes
```

---

## Environment Variable Reference

| Variable                 | Required | Default              | Purpose                                      |
|--------------------------|----------|----------------------|----------------------------------------------|
| `KC_DB_URL`              | Yes      | -                    | Keycloak internal DB JDBC URL                |
| `KC_DB_USERNAME`         | Yes      | -                    | Keycloak DB user                             |
| `KC_DB_PASSWORD`         | Yes      | -                    | Keycloak DB password                         |
| `OBP_API_URL`            | Yes      | -                    | Base URL of OBP API instance                 |
| `OBP_API_USERNAME`       | Yes      | -                    | OBP admin user (requires CanGetAnyUser etc.) |
| `OBP_API_PASSWORD`       | Yes      | -                    | OBP admin password                           |
| `OBP_API_CONSUMER_KEY`   | Yes      | -                    | Consumer key for OBP Direct Login            |
| `OBP_AUTHUSER_PROVIDER`  | Yes      | -                    | Provider filter — mandatory for security     |
| `KEYCLOAK_ADMIN`         | No       | `admin`              | Admin console username                       |
| `KEYCLOAK_ADMIN_PASSWORD`| No       | `admin`              | Admin console password                       |
| `KEYCLOAK_HTTP_PORT`     | No       | `7787`               | Host HTTP port                               |
| `KEYCLOAK_HTTPS_PORT`    | No       | `8443`               | Host HTTPS port                              |
| `KEYCLOAK_MGMT_PORT`     | No       | `9000`               | Host management/health port                  |
| `FORGOT_PASSWORD_URL`    | No       | `` (built-in flow)   | Custom forgot-password redirect URL          |

---

## Sequence Diagram

```
  Developer              Script                    Docker                   Keycloak Container      PostgreSQL
     |                      |                         |                          |                      |
     |-- run --themed ----->|                         |                          |                      |
     |                      |-- validate .env ------->|                          |                      |
     |                      |-- validate themes/ ---->|                          |                      |
     |                      |-- mvn clean package --->|                          |                      |
     |                      |                         |                          |                      |
     |                      |-- docker stop/rm ------>|                          |                      |
     |                      |                         |                          |                      |
     |                      |-- docker build -------->|                          |                      |
     |                      |   (THEMED=true)         |-- Stage 1: mvn build     |                      |
     |                      |                         |-- Stage 2: kc.sh build   |                      |
     |                      |                         |-- Stage 3: copy themes   |                      |
     |                      |                         |<-- image ready           |                      |
     |                      |                         |                          |                      |
     |                      |-- docker run ---------->|-- start-dev ------------>|                      |
     |                      |                         |                          |--- connect --------->|
     |                      |                         |                          |<-- keycloakdb ready--|
     |                      |                         |                          |                      |
     |                      |-- health check -------->|                          |                      |
     |                      |   GET /admin/           |<-- 200 OK -------------- |                      |
     |                      |-- verify themes ------->|                          |                      |
     |                      |   ls themes/obp/        |<-- files present --------|                      |
     |                      |                         |                          |                      |
     |<-- deployment done --|                         |                          |                      |
     |                      |                         |                          |                      |
     |-- open browser ----->|                         |                          |                      |
     |   Admin Console      |                         |  Realm Settings > Themes |                      |
     |   set theme = obp    |                         |  -> theme activated      |                      |
```

---

## Troubleshooting Themed Builds

| Symptom                           | Likely Cause                    | Fix                                            |
|-----------------------------------|---------------------------------|------------------------------------------------|
| Theme validation fails            | Missing `themes/obp/` files     | Check `themes/obp/login/login.ftl` exists      |
| Docker build fails on COPY themes | `themes/` not in build context  | Run from project root, not `development/`      |
| Theme not visible in Admin Console| `THEMED=false` or themes removed| Rebuild with `--themed` flag                   |
| Theme resources 404               | Theme not activated in realm    | Set login theme to `obp` in Realm Settings     |
| Container can't reach OBP API     | Network/host resolution issue   | Verify `host.docker.internal` resolves correctly|
