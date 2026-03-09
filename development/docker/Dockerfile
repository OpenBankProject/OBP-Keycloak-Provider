# Development Dockerfile for OBP Keycloak Provider
#
# Usage:
#   docker build --build-arg KEYCLOAK_VERSION=26.5.1 -t obp-keycloak:latest .
#
# Notes:
#  - The provider JAR must be pre-built on the host before running docker build
#    (see run-local-postgres-cicd.sh). No JDBC drivers are needed — authentication
#    goes through the OBP REST API, not direct database access.
#  - Keycloak version is parameterized with a build arg.
#  - OBP themes are always included. Activate the 'obp' login theme via the
#    Admin Console: Realm Settings > Themes > Login Theme.
#
# Keycloak version — must be passed explicitly. The canonical version is defined in
# KEYCLOAK_VERSION in .github/workflows/build_container_main_branch_themed.yml.
# Pass with: --build-arg KEYCLOAK_VERSION=<version>
ARG KEYCLOAK_VERSION

ARG BUILD_TIMESTAMP
ARG JAR_CHECKSUM

# === Keycloak Builder Stage ===
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} as builder

# Bring build args into this stage for cache invalidation metadata
ARG BUILD_TIMESTAMP
ARG JAR_CHECKSUM

# Enable useful Keycloak features
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_FEATURES=token-exchange
ENV KC_DB=postgres

WORKDIR /opt/keycloak

# Need root temporarily for keystore generation and provider additions
USER root

# Generate a self-signed SSL certificate for development/testing (keystore path consistent with older Dockerfiles)
RUN keytool -genkeypair -storepass password -storetype PKCS12 \
    -keyalg RSA -keysize 2048 -dname "CN=server" -alias server \
    -ext "SAN:c=DNS:localhost,IP:127.0.0.1" \
    -keystore conf/server.keystore

# Write build metadata (previously generated inside the maven stage)
RUN echo "Build timestamp: ${BUILD_TIMESTAMP}" > /tmp/build-info.txt && \
    echo "JAR checksum: ${JAR_CHECKSUM}" >> /tmp/build-info.txt

# Copy the compiled provider jar from the host build
COPY --chown=keycloak:keycloak target/obp-keycloak-provider.jar /opt/keycloak/providers/

# Prebuild Keycloak (compile extensions, optimize)
RUN /opt/keycloak/bin/kc.sh build

# === Final Runtime Image ===
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}

# Bring the prebuilt Keycloak server into the final image
COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY --from=builder /tmp/build-info.txt /opt/keycloak/

# Copy OBP themes — always included so projectVersion and obpAuthUserProvider
# are available. The realm must be configured in the Admin Console to activate
# the 'obp' login theme.
USER root
COPY themes/obp/ /opt/keycloak/themes/obp/
COPY themes/obp-dark/ /opt/keycloak/themes/obp-dark/
# Overwrite theme.properties with Maven-filtered copies that have the real
# version stamped in (pom.xml <version> → @project.version@ substitution).
COPY target/themes-filtered/ /opt/keycloak/themes/

# Ensure correct owner for theme files
RUN chown -R keycloak:keycloak /opt/keycloak/themes/ || true

# Copy the custom entrypoint wrapper that injects runtime ENV into theme config
COPY development/docker/docker-entrypoint.sh /opt/keycloak/docker-entrypoint.sh
RUN chmod 755 /opt/keycloak/docker-entrypoint.sh && chown keycloak:keycloak /opt/keycloak/docker-entrypoint.sh

# Drop privileges for runtime
USER keycloak

# Default Keycloak internal DB configuration (can be overridden at runtime)
ENV KC_DB=postgres
ENV KC_DB_URL=jdbc:postgresql://keycloak-postgres:5432/keycloak
ENV KC_DB_USERNAME=keycloak
ENV KC_DB_PASSWORD=keycloak_changeme

# OBP API configuration — override all of these at runtime
ENV OBP_API_URL=http://localhost:8080
ENV OBP_API_USERNAME=
ENV OBP_API_PASSWORD=
ENV OBP_API_CONSUMER_KEY=

# Default Keycloak runtime configuration (development-friendly)
ENV KC_HOSTNAME_STRICT=false
ENV KC_HOSTNAME_STRICT_HTTPS=false
ENV KC_HTTP_ENABLED=true
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_FEATURES=token-exchange

# Custom "Forgot Password?" link URL (overrides Keycloak's default reset credentials page)
# Set at runtime to redirect users to an external password reset page.
# Leave unset to use Keycloak's built-in password reset flow.
# Example: FORGOT_PASSWORD_URL=https://portal.example.com/reset-password
ENV FORGOT_PASSWORD_URL=

# Start Keycloak in development mode by default (matches prior development Dockerfiles).
ENTRYPOINT ["/opt/keycloak/docker-entrypoint.sh", "start-dev", "--verbose"]
