package io.tesobe.model;

import io.tesobe.providers.OBPApiClient;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;
import org.keycloak.models.ClientScopeModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.ProtocolMapperModel;
import org.keycloak.models.RealmModel;
import org.keycloak.models.RoleModel;
import org.keycloak.protocol.oidc.OIDCLoginProtocol;
import org.keycloak.storage.client.AbstractReadOnlyClientStorageAdapter;
import org.keycloak.storage.client.ClientStorageProviderModel;

/**
 * An OBP Consumer as a Keycloak client, read only. What OBP holds (client_id, name, redirect URLs, enabled,
 * grant types) comes from OBP; the rest is a fixed confidential OpenID Connect client: secret checked by OBP,
 * the realm's default client scopes, no client roles and no protocol mappers of its own.
 *
 * People log in through it (authorization code flow) only when its grant types include authorization_code.
 * A Consumer set to client credentials only is never a login client here; Keycloak's own token for an
 * application acting as itself comes from a service-account client stored in Keycloak itself.
 */
public class ObpClientAdapter extends AbstractReadOnlyClientStorageAdapter {

    private final ObpClient client;
    private final OBPApiClient api;

    public ObpClientAdapter(KeycloakSession session, RealmModel realm, ClientStorageProviderModel component,
                            ObpClient client, OBPApiClient api) {
        super(session, realm, component);
        this.client = client;
        this.api = api;
    }

    // ---- What OBP holds

    @Override public String getClientId() { return client.clientId(); }
    @Override public String getName() { return client.name(); }
    @Override public String getDescription() { return "OBP Consumer " + client.consumerId(); }
    @Override public boolean isEnabled() { return client.enabled(); }
    @Override public Set<String> getRedirectUris() { return Set.copyOf(client.redirectUris()); }

    /** The secret stays in OBP: Keycloak hands the presented secret to OBP to check. */
    @Override public boolean validateSecret(String secret) { return api.verifyClientSecret(client.clientId(), client.consumerId(), secret); }
    @Override public String getSecret() { return null; }

    // ---- A fixed confidential OpenID Connect client

    @Override public String getProtocol() { return OIDCLoginProtocol.LOGIN_PROTOCOL; }
    @Override public String getClientAuthenticatorType() { return "client-secret"; }
    @Override public boolean isPublicClient() { return false; }
    @Override public boolean isBearerOnly() { return false; }
    @Override public boolean isStandardFlowEnabled() { return client.allowsLogin(); }
    @Override public boolean isImplicitFlowEnabled() { return false; }
    @Override public boolean isDirectAccessGrantsEnabled() { return false; }
    @Override public boolean isServiceAccountsEnabled() { return false; }
    @Override public boolean isConsentRequired() { return false; }
    @Override public boolean isFrontchannelLogout() { return true; }
    @Override public boolean isFullScopeAllowed() { return true; }
    @Override public boolean isAlwaysDisplayInConsole() { return false; }
    /** "+" allows the origins of the redirect URLs, for CORS. */
    @Override public Set<String> getWebOrigins() { return Set.of("+"); }
    @Override public String getRootUrl() { return null; }
    @Override public String getBaseUrl() { return null; }
    @Override public String getManagementUrl() { return null; }
    @Override public String getRegistrationToken() { return null; }
    @Override public int getNodeReRegistrationTimeout() { return 0; }
    @Override public int getNotBefore() { return 0; }

    @Override public String getAttribute(String name) { return null; }
    @Override public Map<String, String> getAttributes() { return Map.of(); }
    @Override public String getAuthenticationFlowBindingOverride(String binding) { return null; }
    @Override public Map<String, String> getAuthenticationFlowBindingOverrides() { return Map.of(); }

    @Override
    public Map<String, ClientScopeModel> getClientScopes(boolean defaultScope) {
        return session.clients().getClientScopes(getRealm(), this, defaultScope);
    }

    // ---- No protocol mappers of its own: the realm's default client scopes carry them

    @Override public Stream<ProtocolMapperModel> getProtocolMappersStream() { return Stream.empty(); }
    @Override public ProtocolMapperModel getProtocolMapperById(String id) { return null; }
    @Override public ProtocolMapperModel getProtocolMapperByName(String protocol, String name) { return null; }
    @Override public void updateProtocolMapper(ProtocolMapperModel mapping) { throw readOnly(); }

    // ---- No role scope mappings: with full scope allowed, a token carries the user's roles

    @Override public Stream<RoleModel> getScopeMappingsStream() { return Stream.empty(); }
    @Override public Stream<RoleModel> getRealmScopeMappingsStream() { return Stream.empty(); }
    @Override public void addScopeMapping(RoleModel role) { throw readOnly(); }
    @Override public void deleteScopeMapping(RoleModel role) { throw readOnly(); }
    @Override public boolean hasScope(RoleModel role) { return true; }

    private static UnsupportedOperationException readOnly() {
        return new UnsupportedOperationException("OBP clients are read only in Keycloak: change the Consumer in OBP");
    }
}
