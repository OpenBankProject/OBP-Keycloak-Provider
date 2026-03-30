# CI/CD Production Dockerfile — themed build
#
# Builds the provider JAR inside Docker (no pre-built artifacts needed on the host),
# then packages it with Keycloak and OBP custom themes.
#
# Usage (GitHub Actions):
#   docker build . --file .github/Dockerfile_themed --tag <image>
#
# All OBP API and Keycloak database configuration is supplied at container
# runtime via environment variables — nothing sensitive is baked into the image.
#
# Required runtime variables:
#   OBP_API_URL            — base URL of the OBP API instance
#   OBP_API_USERNAME       — OBP admin user (needs CanGetAnyUser, CanVerifyUserCredentials)
#   OBP_API_PASSWORD       — OBP admin password
#   OBP_API_CONSUMER_KEY   — consumer key registered in OBP for Direct Login
#   OBP_AUTHUSER_PROVIDER  — provider filter; only users with this provider are authenticated
#   KC_DB_URL              — Keycloak's internal PostgreSQL JDBC URL
#   KC_DB_USERNAME         — Keycloak database user
#   KC_DB_PASSWORD         — Keycloak database password

# Keycloak version — passed at build time from the workflow env.KEYCLOAK_VERSION.
# Never hardcode it here — change KEYCLOAK_VERSION in the workflow and it propagates
# to both the Maven build (via -Dversion.keycloak) and the Keycloak base images.
ARG KEYCLOAK_VERSION

# === Stage 1: Build the provider JAR with Maven ===
FROM maven:3-eclipse-temurin-17 AS maven

# Re-declare so it is available inside this stage
ARG KEYCLOAK_VERSION
ARG BUILD_TIMESTAMP
ARG JAR_CHECKSUM

WORKDIR /app
COPY . .
# Override pom.xml <version.keycloak> with the value from the workflow
RUN mvn clean package -Dversion.keycloak=${KEYCLOAK_VERSION} -DskipTests -q

# Build metadata for cache invalidation
RUN echo "Build timestamp: ${BUILD_TIMESTAMP}" > /tmp/build-info.txt && \
    echo "JAR checksum: ${JAR_CHECKSUM}" >> /tmp/build-info.txt

# === Stage 2: Build Keycloak with the provider JAR ===
ARG KEYCLOAK_VERSION
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} AS builder

ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_FEATURES=token-exchange
ENV KC_DB=postgres

WORKDIR /opt/keycloak
USER root

# Generate a self-signed SSL certificate for HTTPS
RUN keytool -genkeypair -storepass password -storetype PKCS12 \
    -keyalg RSA -keysize 2048 -dname "CN=server" -alias server \
    -ext "SAN:c=DNS:localhost,IP:127.0.0.1" \
    -keystore conf/server.keystore

# Copy the provider JAR built in the maven stage
COPY --chown=keycloak:keycloak --from=maven /app/target/obp-keycloak-provider.jar /opt/keycloak/providers/

# Prebuild Keycloak (compile extensions, optimise)
RUN /opt/keycloak/bin/kc.sh build


# === Final Runtime Image ===
# Use the same Keycloak base image for the final runtime image
ARG KEYCLOAK_VERSION
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}

COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY --from=maven /tmp/build-info.txt /opt/keycloak/

USER root

# Copy OBP themes
COPY themes/obp/ /opt/keycloak/themes/obp/
COPY themes/obp-dark/ /opt/keycloak/themes/obp-dark/
# Overwrite theme.properties with Maven-filtered copies that have the real
# version stamped in (pom.xml <version> → @project.version@ substitution).
COPY --from=maven /app/target/themes-filtered/ /opt/keycloak/themes/
RUN chown -R keycloak:keycloak /opt/keycloak/themes/

# Copy the custom entrypoint wrapper that injects runtime ENV into theme config
COPY development/docker/docker-entrypoint.sh /opt/keycloak/docker-entrypoint.sh
RUN chmod 755 /opt/keycloak/docker-entrypoint.sh && chown keycloak:keycloak /opt/keycloak/docker-entrypoint.sh

USER keycloak

# Keycloak internal database — override all at runtime
ENV KC_DB=postgres
ENV KC_DB_URL=jdbc:postgresql://keycloak-postgres:5432/keycloak
ENV KC_DB_USERNAME=keycloak
ENV KC_DB_PASSWORD=keycloak_changeme

# OBP API configuration — override all at runtime
ENV OBP_API_URL=http://localhost:8080
ENV OBP_API_USERNAME=
ENV OBP_API_PASSWORD=
ENV OBP_API_CONSUMER_KEY=
ENV OBP_AUTHUSER_PROVIDER=

# Keycloak runtime defaults
ENV KC_HOSTNAME_STRICT=false
ENV KC_HOSTNAME_STRICT_HTTPS=false
ENV KC_HTTP_ENABLED=true
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_FEATURES=token-exchange

# Custom "Forgot Password?" link — leave empty to use Keycloak's built-in flow
ENV FORGOT_PASSWORD_URL=

ENTRYPOINT ["/opt/keycloak/docker-entrypoint.sh", "start-dev", "--verbose"]
