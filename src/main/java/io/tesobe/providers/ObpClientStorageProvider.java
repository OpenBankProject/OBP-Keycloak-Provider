package io.tesobe.providers;

import io.tesobe.model.ObpClient;
import io.tesobe.model.ObpClientAdapter;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.jboss.logging.Logger;
import org.keycloak.component.ComponentModel;
import org.keycloak.models.ClientModel;
import org.keycloak.models.ClientScopeModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.protocol.oidc.OIDCLoginProtocol;
import org.keycloak.storage.StorageId;
import org.keycloak.storage.client.ClientStorageProvider;
import org.keycloak.storage.client.ClientStorageProviderModel;

/**
 * Looks up OAuth2/OIDC clients in OBP. Keycloak asks its own clients first (admin-cli, account, ...), then
 * this provider; a client found here is an OBP Consumer, read only: it is edited in OBP (API Manager or the
 * consumer endpoints), never in Keycloak.
 *
 * Lookups are cached briefly per client_id, found or not, so a burst of token requests is one OBP call;
 * a change in OBP (redirect URL, disabling the Consumer) takes effect within the cache time. Secrets are not
 * cached: each check goes to OBP.
 */
public class ObpClientStorageProvider implements ClientStorageProvider {

    private static final Logger log = Logger.getLogger(ObpClientStorageProvider.class);
    private static final long FOUND_TTL_MS = 60_000;
    private static final long MISSING_TTL_MS = 10_000;

    private record Cached(ObpClient client, long expiresAt) {}

    private static final Map<String, Cached> CACHE = new ConcurrentHashMap<>();

    private final KeycloakSession session;
    private final ClientStorageProviderModel model;
    private final OBPApiClient api;

    public ObpClientStorageProvider(KeycloakSession session, ComponentModel model, OBPApiClient api) {
        this.session = session;
        this.model = new ClientStorageProviderModel(model);
        this.api = api;
    }

    private ObpClient lookup(String clientId) {
        if (clientId == null || clientId.isBlank()) return null;
        long now = System.currentTimeMillis();
        Cached cached = CACHE.get(clientId);
        if (cached != null && cached.expiresAt() > now) return cached.client();
        ObpClient client = api.getClient(clientId);
        CACHE.put(clientId, new Cached(client, now + (client != null ? FOUND_TTL_MS : MISSING_TTL_MS)));
        if (client == null) log.debug("No OBP client found for a client_id that Keycloak does not know");
        return client;
    }

    @Override
    public ClientModel getClientByClientId(RealmModel realm, String clientId) {
        ObpClient client = lookup(clientId);
        return client != null ? new ObpClientAdapter(session, realm, model, client, api) : null;
    }

    /** Keycloak's id for a stored client is f:{component id}:{external id}; ours is the client_id. */
    @Override
    public ClientModel getClientById(RealmModel realm, String id) {
        return getClientByClientId(realm, new StorageId(id).getExternalId());
    }

    /** OBP has no client search for Keycloak: an exact client_id finds its client, nothing else is listed. */
    @Override
    public Stream<ClientModel> searchClientsByClientIdStream(RealmModel realm, String clientId, Integer first, Integer max) {
        return Stream.ofNullable(getClientByClientId(realm, clientId));
    }

    @Override
    public Stream<ClientModel> searchClientsByAttributes(RealmModel realm, Map<String, String> attributes, Integer first, Integer max) {
        return Stream.empty();
    }

    /** Every OBP client gets the realm's default (or optional) OpenID Connect client scopes. */
    @Override
    public Map<String, ClientScopeModel> getClientScopes(RealmModel realm, ClientModel client, boolean defaultScope) {
        return realm.getDefaultClientScopesStream(defaultScope)
            .filter(scope -> OIDCLoginProtocol.LOGIN_PROTOCOL.equals(scope.getProtocol()))
            .collect(Collectors.toMap(ClientScopeModel::getName, scope -> scope, (a, b) -> a));
    }

    @Override
    public void close() {
    }
}
