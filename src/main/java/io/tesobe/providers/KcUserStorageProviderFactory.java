package io.tesobe.providers;

import java.util.List;
import org.jboss.logging.Logger;
import org.keycloak.component.ComponentModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.provider.ProviderConfigProperty;
import org.keycloak.provider.ProviderConfigurationBuilder;
import org.keycloak.storage.UserStorageProviderFactory;

public class KcUserStorageProviderFactory
    implements UserStorageProviderFactory<KcUserStorageProvider> {

    public static final String PROVIDER_ID = "obp-keycloak-provider";

    private static final Logger log = Logger.getLogger(KcUserStorageProviderFactory.class);

    @Override
    public KcUserStorageProvider create(KeycloakSession session, ComponentModel model) {
        return new KcUserStorageProvider(session, model, SharedOBPApiClient.get());
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    public String getHelpText() {
        return "OBP Keycloak Provider — authenticates users via OBP REST API endpoints " +
            "(Direct Login + verify-credentials). Configured via environment variables.";
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        return ProviderConfigurationBuilder.create()
            .property()
            .name("priority")
            .type(ProviderConfigProperty.STRING_TYPE)
            .label("Priority")
            .defaultValue("0")
            .helpText("Priority of this provider when looking up users. Lower values have higher priority.")
            .add()
            .property()
            .name("enabled")
            .type(ProviderConfigProperty.BOOLEAN_TYPE)
            .label("Enabled")
            .defaultValue("true")
            .helpText("Set to true to enable this user storage provider.")
            .add()
            .build();
    }

    @Override
    public void close() {
        log.info("Closing OBP Keycloak Provider Factory");
    }
}
