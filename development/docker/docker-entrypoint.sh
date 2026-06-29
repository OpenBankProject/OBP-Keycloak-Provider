#!/bin/bash
# Custom entrypoint wrapper for OBP Keycloak Provider
# Injects runtime environment variables into theme configuration before starting Keycloak.

# --- Build/version banner ---
# Surface which build is running so logs can be correlated to a specific image
# during deployment/maintenance (build-info.txt is baked in at image build time).
if [ -f /opt/keycloak/build-info.txt ]; then
    echo "[OBP Entrypoint] ===== OBP Keycloak Provider build ====="
    sed 's/^/[OBP Entrypoint] /' /opt/keycloak/build-info.txt
    echo "[OBP Entrypoint] ======================================="
fi

# --- Forgot Password URL override ---
# If FORGOT_PASSWORD_URL is set, inject it into all theme.properties files
# so the "Forgot Password?" link points to a custom URL instead of Keycloak's default.
if [ -n "$FORGOT_PASSWORD_URL" ]; then
    echo "[OBP Entrypoint] Setting forgotPasswordUrl=$FORGOT_PASSWORD_URL in theme properties"
    for f in /opt/keycloak/themes/*/theme.properties /opt/keycloak/themes/*/login/theme.properties; do
        if [ -f "$f" ]; then
            sed -i "s|^forgotPasswordUrl=.*|forgotPasswordUrl=$FORGOT_PASSWORD_URL|" "$f"
        fi
    done
fi

# --- OBP Auth User Provider display ---
# If OBP_AUTHUSER_PROVIDER is set, inject it into theme.properties
# so the login page can display the provider name.
if [ -n "$OBP_AUTHUSER_PROVIDER" ]; then
    echo "[OBP Entrypoint] Setting obpAuthUserProvider=$OBP_AUTHUSER_PROVIDER in theme properties"
    for f in /opt/keycloak/themes/*/theme.properties /opt/keycloak/themes/*/login/theme.properties; do
        if [ -f "$f" ]; then
            sed -i "s|^obpAuthUserProvider=.*|obpAuthUserProvider=$OBP_AUTHUSER_PROVIDER|" "$f"
        fi
    done
fi

# Delegate to Keycloak's entrypoint
exec /opt/keycloak/bin/kc.sh "$@"
