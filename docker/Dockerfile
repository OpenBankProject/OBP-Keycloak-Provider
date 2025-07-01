# === Build Stage ===
# Use official Keycloak image (26.0.5) as a base for building
FROM quay.io/keycloak/keycloak:26.0.5 as builder

# Enable Keycloak health and metrics endpoints
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Set working directory inside the container
WORKDIR /opt/keycloak

# Switch to root user to perform privileged operations (e.g., keystore generation)
USER root

# Generate a self-signed SSL certificate for development/testing purposes
RUN keytool -genkeypair -storepass password -storetype PKCS12 \
    -keyalg RSA -keysize 2048 -dname "CN=server" -alias server \
    -ext "SAN:c=DNS:localhost,IP:127.0.0.1" \
    -keystore conf/server.keystore

# Prebuild the Keycloak server (e.g., compile extensions, optimize image)
RUN /opt/keycloak/bin/kc.sh build


# === Final Runtime Image ===
# Use the same Keycloak base image for the final runtime image
FROM quay.io/keycloak/keycloak:26.0.5

# Add your custom User Storage Provider (or other extensions) JAR
ADD --chown=keycloak:keycloak target/kc-obp-provider.jar /opt/keycloak/providers/

# Add the PostgreSQL JDBC driver to the providers directory for database connectivity
ADD --chown=keycloak:keycloak https://jdbc.postgresql.org/download/postgresql-42.7.2.jar /opt/keycloak/providers/

# Copy the entire prebuilt Keycloak directory (including config, keystore) from the builder stage
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Start Keycloak in development mode (enables features like auto-reload, less strict config)
ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start-dev"]
