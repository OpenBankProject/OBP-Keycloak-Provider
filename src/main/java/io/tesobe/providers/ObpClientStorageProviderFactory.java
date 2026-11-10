package io.tesobe.providers;

import java.util.List;
import org.keycloak.component.ComponentModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.provider.ProviderConfigProperty;
import org.keycloak.storage.client.ClientStorageProviderFactory;

/**
 * Registers the OBP client storage: Keycloak finds its OAuth2/OIDC clients in OBP, as OBP Consumers, so a
 * client is registered once (in OBP) and never duplicated as a Keycloak client.
 *
 * Add it to a realm with the Admin REST API (the admin console has no screen for client storage providers):
 *
 *   POST /admin/realms/{realm}/components
 *   {"name": "obp-clients", "providerId": "obp-client-storage",
 *    "providerType": "org.keycloak.storage.client.ClientStorageProvider", "parentId": "{realm id}"}
 *
 * Configuration is the same environment as the user storage provider (OBP_API_URL and the admin account);
 * the admin account also needs CanGetOidcClient and CanVerifyOidcClient.
 */
public class ObpClientStorageProviderFactory implements ClientStorageProviderFactory<ObpClientStorageProvider> {

    public static final String PROVIDER_ID = "obp-client-storage";

    @Override
    public ObpClientStorageProvider create(KeycloakSession session, ComponentModel model) {
        return new ObpClientStorageProvider(session, model, SharedOBPApiClient.get());
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    public String getHelpText() {
        return "OBP client storage — OAuth2/OIDC clients are OBP Consumers (client_id = consumer key); "
            + "client secrets are checked by OBP. Configured via environment variables.";
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        return List.of();
    }
}
