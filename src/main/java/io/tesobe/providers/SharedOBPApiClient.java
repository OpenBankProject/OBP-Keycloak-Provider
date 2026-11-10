package io.tesobe.providers;

import io.tesobe.config.OBPApiConfig;
import org.jboss.logging.Logger;

/**
 * The one OBP API client of this jar, shared by the user and the client storage providers: one configuration
 * check, one connection test and one admin Direct Login token for both.
 */
final class SharedOBPApiClient {

    private static final Logger log = Logger.getLogger(SharedOBPApiClient.class);
    private static volatile OBPApiClient instance;

    private SharedOBPApiClient() {}

    static OBPApiClient get() {
        OBPApiClient client = instance;
        if (client != null) return client;
        synchronized (SharedOBPApiClient.class) {
            if (instance == null) {
                log.info("Validating OBP API configuration for OBP Keycloak Provider");
                OBPApiConfig.validateConfiguration();
                OBPApiClient created = new OBPApiClient(OBPApiConfig.getInstance());
                if (!created.testConnection()) {
                    log.warn("OBP API connection test failed at startup — provider registered " +
                        "but authentication will fail until OBP API is reachable. " +
                        "Check OBP_API_URL, OBP_API_USERNAME, OBP_API_PASSWORD, OBP_API_CONSUMER_KEY");
                }
                instance = created;
            }
            return instance;
        }
    }
}
