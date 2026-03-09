package io.tesobe.providers;

import io.tesobe.config.OBPApiConfig;
import io.tesobe.model.KcUserEntity;
import io.tesobe.model.UserAdapter;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
import org.jboss.logging.Logger;
import org.keycloak.component.ComponentModel;
import org.keycloak.credential.CredentialInput;
import org.keycloak.credential.CredentialInputUpdater;
import org.keycloak.credential.CredentialInputValidator;
import org.keycloak.models.*;
import org.keycloak.models.cache.CachedUserModel;
import org.keycloak.models.cache.OnUserCache;
import org.keycloak.models.credential.PasswordCredentialModel;
import org.keycloak.storage.StorageId;
import org.keycloak.storage.UserStorageProvider;
import org.keycloak.storage.user.*;

public class KcUserStorageProvider
    implements
        UserStorageProvider,
        UserLookupProvider,
        UserRegistrationProvider,
        UserQueryProvider,
        CredentialInputUpdater,
        CredentialInputValidator,
        OnUserCache {

    private static final Logger log = Logger.getLogger(KcUserStorageProvider.class);

    private final KeycloakSession session;
    private final ComponentModel model;
    private final OBPApiClient apiClient;

    public KcUserStorageProvider(
        KeycloakSession session,
        ComponentModel model,
        OBPApiClient apiClient
    ) {
        this.session = session;
        this.model = model;
        this.apiClient = apiClient;
        log.info("OBP User Storage Provider initialized (API mode)");
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    @Override
    public void close() {
        log.info("OBP User Storage Provider closed");
    }

    @Override
    public void preRemove(RealmModel realm) {
        log.infof("Realm %s is being removed", realm.getName());
    }

    @Override
    public void preRemove(RealmModel realm, GroupModel group) {
        log.infof("Group %s is being removed from realm %s", group.getName(), realm.getName());
    }

    @Override
    public void preRemove(RealmModel realm, RoleModel role) {
        log.infof("Role %s is being removed from realm %s", role.getName(), realm.getName());
    }

    @Override
    public void onCache(RealmModel realm, CachedUserModel user, UserModel delegate) {
        // No password/salt to cache — credential validation always goes to the OBP API
        log.debugf("onCache() called for user: %s (no credentials cached in API mode)",
            user.getUsername());
    }

    // -------------------------------------------------------------------------
    // Lookup
    // -------------------------------------------------------------------------

    @Override
    public UserModel getUserById(RealmModel realm, String id) {
        String externalId = StorageId.externalId(id);
        log.infof("getUserById() called: %s (external: %s)", id, externalId);
        try {
            KcUserEntity entity = apiClient.getUserById(externalId);
            if (entity == null) {
                log.warnf("User not found with external ID: %s", externalId);
                return null;
            }
            return new UserAdapter(session, realm, model, entity);
        } catch (IllegalArgumentException ex) {
            log.warn("Invalid ID format: " + id, ex);
            return null;
        }
    }

    @Override
    public UserModel getUserByUsername(RealmModel realm, String username) {
        log.infof("getUserByUsername() called: %s", username);
        KcUserEntity entity = apiClient.getUserByUsername(username);
        if (entity == null) {
            log.infof("User not found by username: %s", username);
            return null;
        }
        return new UserAdapter(session, realm, model, entity);
    }

    @Override
    public UserModel getUserByEmail(RealmModel realm, String email) {
        log.warnf("getUserByEmail() called for '%s' — email-based lookup is not supported " +
            "in OBP API mode. Returning null.", email);
        return null;
    }

    // -------------------------------------------------------------------------
    // Registration (disabled — OBP API is read-only from Keycloak's perspective)
    // -------------------------------------------------------------------------

    @Override
    public UserModel addUser(RealmModel realm, String username) {
        log.errorf("addUser() called for username '%s' — user creation is not supported. " +
            "Users must be created in OBP directly.", username);
        throw new UnsupportedOperationException(
            "User creation is not supported. Users must be created through OBP.");
    }

    @Override
    public boolean removeUser(RealmModel realm, UserModel user) {
        log.warnf("removeUser() called for '%s' — user deletion is not supported.",
            user.getUsername());
        throw new UnsupportedOperationException(
            "User deletion is not supported. Users must be removed through OBP.");
    }

    // -------------------------------------------------------------------------
    // Credential support
    // -------------------------------------------------------------------------

    @Override
    public boolean supportsCredentialType(String credentialType) {
        return PasswordCredentialModel.TYPE.equals(credentialType);
    }

    @Override
    public boolean isConfiguredFor(RealmModel realm, UserModel user, String credentialType) {
        boolean supported = supportsCredentialType(credentialType);
        log.warnf("isConfiguredFor() — user: %s, credentialType: %s → %b",
            user.getUsername(), credentialType, supported);
        return supported;
    }

    @Override
    public boolean isValid(RealmModel realm, UserModel user, CredentialInput input) {
        log.warnf(">>> isValid() called for user: %s, credentialType: %s <<<",
            user.getUsername(), input.getType());

        if (!supportsCredentialType(input.getType())) {
            log.warnf("isValid() — unsupported credential type: %s for user: %s",
                input.getType(), user.getUsername());
            return false;
        }

        String rawPassword = input.getChallengeResponse();
        if (rawPassword == null || rawPassword.trim().isEmpty()) {
            log.warnf("isValid() — empty or null password for user: %s", user.getUsername());
            return false;
        }

        boolean valid = apiClient.verifyUserCredentials(user.getUsername(), rawPassword) != null;
        if (valid) {
            log.warnf("isValid() — password validation SUCCESSFUL for user: %s", user.getUsername());
        } else {
            log.warnf("isValid() — password validation FAILED for user: %s", user.getUsername());
        }
        return valid;
    }

    @Override
    public boolean updateCredential(RealmModel realm, UserModel user, CredentialInput input) {
        log.warnf("updateCredential() called for user '%s' — password updates are not supported. " +
            "Use OBP to change passwords.", user.getUsername());
        return false;
    }

    @Override
    public void disableCredentialType(RealmModel realm, UserModel user, String credentialType) {
        log.warnf("disableCredentialType() called for user '%s', type '%s' — not supported.",
            user.getUsername(), credentialType);
    }

    @Override
    public Stream<String> getDisableableCredentialTypesStream(RealmModel realm, UserModel user) {
        return Stream.of(PasswordCredentialModel.TYPE);
    }

    // -------------------------------------------------------------------------
    // Queries / synchronisation
    // -------------------------------------------------------------------------

    @Override
    public int getUsersCount(RealmModel realm) {
        List<KcUserEntity> users = apiClient.listUsers(0, 0);
        int count = users.size();
        log.infof("getUsersCount() — found %d users for configured provider", count);
        return count;
    }

    @Override
    public Stream<UserModel> searchForUserStream(
        RealmModel realm,
        Map<String, String> params,
        Integer first,
        Integer max
    ) {
        log.infof("searchForUserStream() with params: %s", params);

        if (params == null || params.isEmpty()) {
            return getAllUsers(realm, first, max);
        }

        String username = params.get("username");
        String email = params.get("email");
        String search = params.get("search");

        if (username != null) {
            UserModel user = getUserByUsername(realm, username);
            return user != null ? Stream.of(user) : Stream.empty();
        }

        if (email != null) {
            UserModel user = getUserByEmail(realm, email);
            return user != null ? Stream.of(user) : Stream.empty();
        }

        if (search != null) {
            // Best-effort: treat search string as a username lookup
            UserModel user = getUserByUsername(realm, search);
            return user != null ? Stream.of(user) : Stream.empty();
        }

        return getAllUsers(realm, first, max);
    }

    @Override
    public Stream<UserModel> getGroupMembersStream(
        RealmModel realm,
        GroupModel group,
        Integer first,
        Integer max
    ) {
        return Stream.empty();
    }

    @Override
    public Stream<UserModel> searchForUserByUserAttributeStream(
        RealmModel realm,
        String attr,
        String value
    ) {
        return Stream.empty();
    }

    private Stream<UserModel> getAllUsers(RealmModel realm, Integer first, Integer max) {
        int offset = first != null && first >= 0 ? first : 0;
        int limit = max != null && max >= 0 ? max : 0;
        log.infof("getAllUsers() for synchronisation: offset=%d, limit=%d", offset, limit);

        List<KcUserEntity> entities = apiClient.listUsers(offset, limit);
        return entities.stream()
            .map(entity -> (UserModel) new UserAdapter(session, realm, model, entity));
    }
}
