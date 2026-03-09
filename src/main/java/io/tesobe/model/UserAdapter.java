package io.tesobe.model;

import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
import org.jboss.logging.Logger;
import org.keycloak.component.ComponentModel;
import org.keycloak.models.*;
import org.keycloak.storage.StorageId;
import org.keycloak.storage.adapter.AbstractUserAdapterFederatedStorage;

/**
 * Simplified UserAdapter for OBP Keycloak Provider
 *
 * This adapter treats the database as the single source of truth.
 * The Keycloak GUI reflects the database data but cannot modify it.
 * All write operations are disabled to maintain read-only access.
 *
 * Database Structure:
 * - Uses v_oidc_users view (JOIN of authuser and resourceuser tables)
 * - user_id: UUID from resourceuser.userid_ (primary identifier)
 * - Other fields: from authuser table (username, email, etc.)
 * - Handles both numeric and UUID-based external IDs
 */
public class UserAdapter extends AbstractUserAdapterFederatedStorage {

    private static final Logger log = Logger.getLogger(UserAdapter.class);
    private final KcUserEntity entity;
    private final String keycloakId;

    public UserAdapter(
        KeycloakSession session,
        RealmModel realm,
        ComponentModel model,
        KcUserEntity entity
    ) {
        super(session, realm, model);
        this.entity = entity;
        log.infof(
            "UserAdapter created for user: %s with database values - firstName: '%s', lastName: '%s', email: '%s'",
            entity.getUsername(),
            entity.getFirstName(),
            entity.getLastName(),
            entity.getEmail()
        );

        // Generate Keycloak ID using database primary key (UUID from resourceuser.userid_)
        if (entity.getId() == null || entity.getId().trim().isEmpty()) {
            throw new IllegalStateException(
                "Primary key user_id is null or empty for user: " +
                    entity.getUsername()
            );
        }

        // entity.getId() is already a String (UUID), no conversion needed
        this.keycloakId = StorageId.keycloakId(model, entity.getId());

        log.infof(
            "UserAdapter initialized at %d for user: %s (user_id: %s)",
            System.currentTimeMillis(),
            getUsername(),
            entity.getId()
        );
    }

    // =====================================================
    // READ-ONLY METHODS (Database as Source of Truth)
    // =====================================================

    @Override
    public String getId() {
        return keycloakId;
    }

    @Override
    public String getUsername() {
        String value = entity.getUsername();
        log.debugf(
            "getUsername() for user %s returning API value: '%s'",
            value,
            value
        );
        return value;
    }

    @Override
    public String getEmail() {
        String value = entity.getEmail();
        log.debugf(
            "getEmail() for user %s returning API value: '%s'",
            getUsername(),
            value
        );
        return value;
    }

    @Override
    public String getFirstName() {
        String value = entity.getFirstName();
        log.debugf(
            "getFirstName() for user %s returning API value: '%s'",
            getUsername(),
            value
        );
        return value;
    }

    @Override
    public String getLastName() {
        String value = entity.getLastName();
        log.debugf(
            "getLastName() for user %s returning API value: '%s'",
            getUsername(),
            value
        );
        return value;
    }

    @Override
    public boolean isEmailVerified() {
        return Boolean.TRUE.equals(entity.getValidated());
    }

    @Override
    public boolean isEnabled() {
        return Boolean.TRUE.equals(entity.getValidated());
    }

    @Override
    public Long getCreatedTimestamp() {
        // OBP API does not expose an account creation date.
        // Return current time so the admin console shows a valid date rather than "Invalid Date".
        return System.currentTimeMillis();
    }

    // Custom methods for password validation
    public String getPassword() {
        return entity.getPassword();
    }

    public String getSalt() {
        return entity.getSalt();
    }

    // Password setters - disabled for read-only approach
    public void setPassword(String password) {
        log.warnf(
            "OPERATION DISABLED: setPassword() called for user %s. " +
                "Database is read-only. Use external tools to update passwords.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    public void setSalt(String salt) {
        log.warnf(
            "OPERATION DISABLED: setSalt() called for user %s. " +
                "Database is read-only. Use external tools to update passwords.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    public KcUserEntity getEntity() {
        return entity;
    }

    // =====================================================
    // READ-ONLY ATTRIBUTES
    // =====================================================

    @Override
    public String getFirstAttribute(String name) {
        String value;
        switch (name) {
            case "firstName":
                value = getFirstName();
                break;
            case "lastName":
                value = getLastName();
                break;
            case "email":
                value = getEmail();
                break;
            case "username":
                value = getUsername();
                break;
            case "validated":
                value = String.valueOf(isEmailVerified());
                break;
            case "provider":
                value = entity.getProvider();
                break;
            default:
                // For unknown attributes, explicitly check if it exists in federated storage
                // and log a warning if it does
                String federatedValue = super.getFirstAttribute(name);
                if (federatedValue != null) {
                    log.warnf(
                        "FEDERATED STORAGE LEAK: Attribute %s='%s' found in federated storage for user %s but not in database. Returning null to enforce database-only policy.",
                        name,
                        federatedValue,
                        getUsername()
                    );
                }
                value = null;
        }
        log.debugf(
            "getFirstAttribute(%s) for user %s returning API value: '%s'",
            name,
            getUsername(),
            value
        );
        return value;
    }

    @Override
    public Map<String, List<String>> getAttributes() {
        log.debugf("getAttributes() called for user: %s", getUsername());

        // Check what federated storage contains before we return database-only values
        Map<String, List<String>> federatedAttributes = super.getAttributes();
        if (!federatedAttributes.isEmpty()) {
            log.warnf(
                "FEDERATED STORAGE DETECTED: Found %d federated attributes for user %s: %s",
                federatedAttributes.size(),
                getUsername(),
                federatedAttributes.keySet()
            );
        }

        // Create new map with ONLY database fields - ignore federated storage
        Map<String, List<String>> attributes = new HashMap<>();

        // Add database fields as attributes
        addAttributeIfNotNull(attributes, "firstName", entity.getFirstName());
        addAttributeIfNotNull(attributes, "lastName", entity.getLastName());
        addAttributeIfNotNull(attributes, "email", entity.getEmail());
        addAttributeIfNotNull(attributes, "username", entity.getUsername());
        addAttributeIfNotNull(attributes, "provider", entity.getProvider());
        addAttributeIfNotNull(
            attributes,
            "validated",
            String.valueOf(entity.getValidated())
        );

        // Note: createdAt and updatedAt are excluded from attributes to prevent
        // OIDC mapper parsing errors (timestamps cannot be parsed as Long)

        return attributes;
    }

    private void addAttributeIfNotNull(
        Map<String, List<String>> attributes,
        String key,
        String value
    ) {
        if (value != null) {
            attributes.put(key, Collections.singletonList(value));
        }
    }

    public List<String> getAttribute(String name) {
        // Return database values only - ignore federated storage
        switch (name) {
            case "firstName":
                return entity.getFirstName() != null
                    ? Collections.singletonList(entity.getFirstName())
                    : Collections.emptyList();
            case "lastName":
                return entity.getLastName() != null
                    ? Collections.singletonList(entity.getLastName())
                    : Collections.emptyList();
            case "email":
                return entity.getEmail() != null
                    ? Collections.singletonList(entity.getEmail())
                    : Collections.emptyList();
            case "username":
                return entity.getUsername() != null
                    ? Collections.singletonList(entity.getUsername())
                    : Collections.emptyList();
            case "validated":
                return Collections.singletonList(
                    String.valueOf(entity.getValidated())
                );
            case "provider":
                return entity.getProvider() != null
                    ? Collections.singletonList(entity.getProvider())
                    : Collections.emptyList();
            default:
                // Return empty list for unknown attributes - do not use federated storage
                return Collections.emptyList();
        }
    }

    // =====================================================
    // DISABLED WRITE OPERATIONS
    // =====================================================

    @Override
    public void setUsername(String username) {
        log.warnf(
            "OPERATION DISABLED: setUsername() called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void setEmail(String email) {
        log.warnf(
            "OPERATION DISABLED: setEmail() called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void setFirstName(String firstName) {
        log.warnf(
            "OPERATION DISABLED: setFirstName() called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void setLastName(String lastName) {
        log.warnf(
            "OPERATION DISABLED: setLastName() called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void setEmailVerified(boolean verified) {
        log.warnf(
            "OPERATION DISABLED: setEmailVerified() called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void setEnabled(boolean enabled) {
        log.warnf(
            "OPERATION DISABLED: setEnabled() called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void setSingleAttribute(String name, String value) {
        log.warnf(
            "OPERATION DISABLED: setSingleAttribute(%s, %s) called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            name,
            value,
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void setAttribute(String name, List<String> values) {
        log.warnf(
            "OPERATION DISABLED: setAttribute(%s, %s) called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            name,
            values,
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    @Override
    public void removeAttribute(String name) {
        log.warnf(
            "OPERATION DISABLED: removeAttribute(%s) called for user %s. " +
                "Database is read-only. Use external tools to update user data.",
            name,
            getUsername()
        );
        // Do nothing - database is source of truth
    }

    // =====================================================
    // REQUIRED ACTIONS (Delegated to Federated Storage)
    // =====================================================

    @Override
    public Stream<String> getRequiredActionsStream() {
        // Database is source of truth — never surface stored required actions such as
        // UPDATE_PROFILE from federated storage, as users cannot update their profile
        // through Keycloak and the form would appear on every login with no way to dismiss it.
        return Stream.empty();
    }

    @Override
    public void addRequiredAction(String action) {
        log.debugf("addRequiredAction(%s) for user: %s", action, getUsername());
        super.addRequiredAction(action);
    }

    @Override
    public void removeRequiredAction(String action) {
        log.debugf(
            "removeRequiredAction(%s) for user: %s",
            action,
            getUsername()
        );
        super.removeRequiredAction(action);
    }

    // =====================================================
    // GROUPS AND ROLES (Delegated to Federated Storage)
    // =====================================================

    @Override
    public Stream<GroupModel> getGroupsStream() {
        return super.getGroupsStream();
    }

    @Override
    public void joinGroup(GroupModel group) {
        super.joinGroup(group);
    }

    @Override
    public void leaveGroup(GroupModel group) {
        super.leaveGroup(group);
    }

    @Override
    public boolean isMemberOf(GroupModel group) {
        return super.isMemberOf(group);
    }

    @Override
    public Stream<RoleModel> getRoleMappingsStream() {
        return super.getRoleMappingsStream();
    }

    @Override
    public void grantRole(RoleModel role) {
        super.grantRole(role);
    }

    @Override
    public void deleteRoleMapping(RoleModel role) {
        super.deleteRoleMapping(role);
    }

    @Override
    public boolean hasRole(RoleModel role) {
        return super.hasRole(role);
    }

    @Override
    public Stream<RoleModel> getRealmRoleMappingsStream() {
        return super.getRealmRoleMappingsStream();
    }

    @Override
    public Stream<RoleModel> getClientRoleMappingsStream(ClientModel client) {
        return super.getClientRoleMappingsStream(client);
    }

    // =====================================================
    // UTILITY METHODS
    // =====================================================

    /**
     * Clears federated storage attributes to ensure database is the source of truth.
     * This prevents fed_user_attribute table values from overriding database values.
     */
    private void clearFederatedStorageAttributes() {
        try {
            log.infof(
                "CLEARING FEDERATED STORAGE for user: %s - Database values: firstName='%s', lastName='%s', email='%s'",
                getUsername(),
                entity.getFirstName(),
                entity.getLastName(),
                entity.getEmail()
            );

            // Clear core profile attributes from federated storage
            String[] coreAttributes = {
                "firstName",
                "lastName",
                "email",
                "username",
                "validated",
                "provider",
            };
            for (String attrName : coreAttributes) {
                // Check what's currently in federated storage before clearing
                String federatedValue = super.getFirstAttribute(attrName);
                log.infof(
                    "Attribute %s: federated='%s', database='%s' for user %s",
                    attrName,
                    federatedValue,
                    getFirstAttribute(attrName),
                    getUsername()
                );

                // Remove from federated storage - this calls the parent's method to actually clear it
                super.removeAttribute(attrName);
                log.infof(
                    "Removed %s from federated storage for user %s",
                    attrName,
                    getUsername()
                );
            }

            log.infof(
                "FEDERATED STORAGE CLEARED for user: %s - Database is now source of truth",
                getUsername()
            );
        } catch (Exception e) {
            log.errorf(
                "Failed to clear federated storage attributes for user %s: %s",
                getUsername(),
                e.getMessage()
            );
            // Continue anyway - this is just cleanup
        }
    }

    /**
     * Forces a complete refresh of user data by clearing all federated attributes
     * and ensuring database values are returned.
     *
     * This method ensures the JOIN-based view data (v_oidc_users) is the source of truth.
     */
    public void forceRefreshFromDatabase() {
        try {
            log.infof(
                "FORCING REFRESH from database for user: %s (user_id: %s)",
                getUsername(),
                entity.getId()
            );

            // Clear all possible federated storage attributes
            String[] allAttributes = {
                "firstName",
                "lastName",
                "email",
                "username",
                "validated",
                "provider",
                "locale",
                "timezone",
                "FIRST_NAME",
                "LAST_NAME",
                "EMAIL",
                "USERNAME",
            };

            for (String attr : allAttributes) {
                super.removeAttribute(attr);
            }

            log.infof("Force refresh completed for user: %s", getUsername());
        } catch (Exception e) {
            log.errorf(
                "Failed to force refresh for user %s: %s",
                getUsername(),
                e.getMessage()
            );
        }
    }

    @Override
    public String toString() {
        return String.format(
            "UserAdapter[id=%s, username=%s, email=%s]",
            keycloakId,
            getUsername(),
            getEmail()
        );
    }
}
