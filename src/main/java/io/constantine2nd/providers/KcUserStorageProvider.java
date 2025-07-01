package io.constantine2nd.providers;

import io.constantine2nd.model.KcUserEntity;
import io.constantine2nd.model.UserAdapter;
import jakarta.persistence.EntityManager;
import jakarta.persistence.TypedQuery;
import org.jboss.logging.Logger;
import org.keycloak.component.ComponentModel;
import org.keycloak.connections.jpa.JpaConnectionProvider;
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
import org.mindrot.jbcrypt.BCrypt;
import java.util.*;
import java.util.stream.Stream;

public class KcUserStorageProvider implements
        UserStorageProvider,
        UserLookupProvider,
        UserRegistrationProvider,
        UserQueryProvider,
        CredentialInputUpdater,
        CredentialInputValidator,
        OnUserCache {

    private static final Logger log = Logger.getLogger(KcUserStorageProvider.class);
    public static final String PASSWORD_CACHE_KEY = UserAdapter.class.getName() + ".password";
    public static final String SALT_CACHE_KEY = UserAdapter.class.getName() + ".salt";

    private final KeycloakSession session;
    private final ComponentModel model;
    private final EntityManager em;

    public KcUserStorageProvider(KeycloakSession session, ComponentModel model) {
        this.session = session;
        this.model = model;
        this.em = session.getProvider(JpaConnectionProvider.class, "user-store").getEntityManager();
    }

    // Lifecycle
    @Override
    public void close() {
        log.info("Provider closed");
    }

    @Override
    public void preRemove(RealmModel realm) {}

    @Override
    public void preRemove(RealmModel realm, GroupModel group) {}

    @Override
    public void preRemove(RealmModel realm, RoleModel role) {}



    // Lookup
    @Override
    public UserModel getUserById(RealmModel realm, String id) {
        try {
            String externalId = StorageId.externalId(id);
            // UUID uuid = UUID.fromString(externalId);
            KcUserEntity entity = em.find(KcUserEntity.class, externalId);
            log.info("$ getUserById() called with: " + id);
            return entity == null ? null : new UserAdapter(session, realm, model, entity);
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }


    @Override
    public UserModel getUserByUsername(RealmModel realm, String username) {
        TypedQuery<KcUserEntity> query = em.createNamedQuery("getUserByUsername", KcUserEntity.class);
        query.setParameter("username", username);
        log.info("$ getUserByUsername() called with: " + username);
        return query.getResultStream().findFirst()
                .map(e -> new UserAdapter(session, realm, model, e))
                .orElse(null);
    }

    @Override
    public UserModel getUserByEmail(RealmModel realm, String email) {
        TypedQuery<KcUserEntity> query = em.createNamedQuery("getUserByEmail", KcUserEntity.class);
        query.setParameter("email", email);
        log.info("$ getUserByEmail() called with: " + email);
        return query.getResultStream().findFirst()
                .map(e -> new UserAdapter(session, realm, model, e))
                .orElse(null);
    }

    // Registration
    @Override
    public UserModel addUser(RealmModel realm, String username) {
        KcUserEntity entity = new KcUserEntity();
        // entity.setId(UUID.randomUUID());
        entity.setUsername(username);

        // Set empty firstName and lastName to avoid null errors during VERIFY_PROFILE
        entity.setFirstName("New");
        entity.setLastName("User");

        em.persist(entity);
        return new UserAdapter(session, realm, model, entity);
    }


    @Override
    public boolean removeUser(RealmModel realm, UserModel user) {
        String persistenceId = StorageId.externalId(user.getId());
        KcUserEntity entity = em.find(KcUserEntity.class, UUID.fromString(persistenceId));
        if (entity == null) return false;
        em.remove(entity);
        return true;
    }

    // Caching
    @Override
    public void onCache(RealmModel realm, CachedUserModel user, UserModel delegate) {
        String password = ((UserAdapter) delegate).getPassword();
        String salt = ((UserAdapter) delegate).getSalt();
        if (password != null) {
            user.getCachedWith().put(PASSWORD_CACHE_KEY, password);
            user.getCachedWith().put(SALT_CACHE_KEY, salt);
        }
    }

    // Credential support
    @Override
    public boolean supportsCredentialType(String credentialType) {
        return PasswordCredentialModel.TYPE.equals(credentialType);
    }

    @Override
    public boolean isConfiguredFor(RealmModel realm, UserModel user, String credentialType) {
        return supportsCredentialType(credentialType) && getPassword(user) != null;
    }

    @Override
    public boolean isValid(RealmModel realm, UserModel user, CredentialInput input) {
        if (!(input instanceof UserCredentialModel) || !supportsCredentialType(input.getType())) return false;

        String storedHash = getPassword(user); // e.g. "b;$2a$10$SGIAR0RtthMlgJK9DhElBekIvo5ulZ26GBZJQ"
        String salt = getSalt(user);           // e.g. "eXGhiuAy69XIP8fLvu6ZFO" (16-char suffix of full hash)
        String rawPassword = input.getChallengeResponse();

        if (storedHash == null || salt == null || !storedHash.startsWith("b;")) {
            log.warn("Missing or malformed stored password.");
            return false;
        }

        // Reconstruct full bcrypt hash
        String fullBcryptHash = storedHash.substring(2) + salt;

        try {
            return BCrypt.checkpw(rawPassword, fullBcryptHash);
        } catch (IllegalArgumentException e) {
            log.error("Invalid bcrypt hash format: " + fullBcryptHash, e);
            return false;
        }
    }

    @Override
    public boolean updateCredential(RealmModel realm, UserModel user, CredentialInput input) {
        if (!(input instanceof UserCredentialModel) || !supportsCredentialType(input.getType())) return false;
        getUserAdapter(user).setPassword(((UserCredentialModel) input).getValue());
        return true;
    }

    @Override
    public void disableCredentialType(RealmModel realm, UserModel user, String credentialType) {
        if (supportsCredentialType(credentialType)) {
            getUserAdapter(user).setPassword(null);
        }
    }

    @Override
    public Stream<String> getDisableableCredentialTypesStream(RealmModel realm, UserModel user) {
        return getPassword(user) != null ? Stream.of(PasswordCredentialModel.TYPE) : Stream.empty();
    }

    private String getPassword(UserModel user) {
        if (user instanceof CachedUserModel) {
            return (String) ((CachedUserModel) user).getCachedWith().get(PASSWORD_CACHE_KEY);
        } else if (user instanceof UserAdapter) {
            return ((UserAdapter) user).getPassword();
        }
        return null;
    }
    private String getSalt(UserModel user) {
        log.info("user: " + user.toString());
        if (user instanceof CachedUserModel) {
            log.info("CachedUserModel");
            return (String) ((CachedUserModel) user).getCachedWith().get(SALT_CACHE_KEY);
        } else if (user instanceof UserAdapter) {
            log.info("UserAdapter");
            return ((UserAdapter) user).getSalt();
        }
        return null;
    }

    private UserAdapter getUserAdapter(UserModel user) {
        if (user instanceof CachedUserModel) {
            return (UserAdapter) ((CachedUserModel) user).getDelegateForUpdate();
        }
        return (UserAdapter) user;
    }

    // Queries
    @Override
    public int getUsersCount(RealmModel realm) {
        Object result = em.createNamedQuery("getUserCount").getSingleResult();
        return ((Number) result).intValue();
    }

    @Override
    public Stream<UserModel> searchForUserStream(RealmModel realm, String search, Integer first, Integer max) {
        TypedQuery<KcUserEntity> query = em.createNamedQuery("searchForUser", KcUserEntity.class);
        query.setParameter("search", "%" + search.toLowerCase() + "%");

        if (first != null && first >= 0) query.setFirstResult(first);
        if (max != null && max >= 0) query.setMaxResults(max);

        return query.getResultStream().map(e -> new UserAdapter(session, realm, model, e));
    }

    @Override
    public Stream<UserModel> searchForUserStream(RealmModel realm, Map<String, String> params, Integer first, Integer max) {
        return Stream.empty(); // Optional: implement param-based filtering
    }

    @Override
    public Stream<UserModel> getGroupMembersStream(RealmModel realm, GroupModel group, Integer first, Integer max) {
        return Stream.empty(); // Optional
    }

    @Override
    public Stream<UserModel> searchForUserByUserAttributeStream(RealmModel realm, String attr, String value) {
        return Stream.empty(); // Optional
    }
}
