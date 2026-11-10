package io.tesobe.model;

import java.util.List;

/**
 * An OAuth2/OIDC client as OBP holds it: an OBP Consumer, whose key is the client_id.
 * From GET /obp/v6.0.0/oidc/clients/{CLIENT_ID} (GetOidcClientResponseJsonV600). The secret is never
 * part of it: Keycloak checks a secret by asking OBP (POST /obp/v6.0.0/oidc/clients/verify).
 */
public record ObpClient(
    String clientId,
    String name,
    String consumerId,
    List<String> redirectUris,
    boolean enabled,
    // The OAuth2 grant types OBP allows for the client (the Consumer's own, or every grant when it sets none)
    List<String> grantTypes
) {
    /** People may log in through it (authorization code flow). */
    public boolean allowsLogin() { return grantTypes.contains("authorization_code"); }
}
