package io.tesobe.model;

import org.jboss.logging.Logger;
import org.keycloak.component.ComponentModel;
import org.keycloak.models.*;
import org.keycloak.storage.StorageId;
import org.keycloak.storage.adapter.AbstractUserAdapterFederatedStorage;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

public class UserAdapter extends AbstractUserAdapterFederatedStorage {

    private static final Logger log = Logger.getLogger(UserAdapter.class);
    private final KcUserEntity entity;
    private final String keycloakId;

    public UserAdapter(KeycloakSession session, RealmModel realm, ComponentModel model, KcUserEntity entity) {
        super(session, realm, model);
        this.entity = entity;
        log.info("UserAdapter created for: " + this.entity);
        this.keycloakId = StorageId.keycloakId(model, entity.getId().toString());
    }

    // Username
    @Override
    public String getUsername() {
        return entity.getUsername();
    }

    @Override
    public void setUsername(String username) {
        log.info("$ setUsername() called with: " + username);
        entity.setUsername(username);
    }

    // Email
    @Override
    public String getEmail() {
        return entity.getEmail();
    }

    @Override
    public void setEmail(String email) {
        log.info("$ setEmail() called with: " + email);
        entity.setEmail(email);
    }

    // First name
    @Override
    public String getFirstName() {
        return entity.getFirstName();
    }

    @Override
    public void setFirstName(String firstName) {
        log.info("$ setFirstName() called with: " + firstName);
        entity.setFirstName(firstName);
    }

    // Last name
    @Override
    public String getLastName() {
        return entity.getLastName();
    }

    @Override
    public void setLastName(String lastName) {
        log.info("$ setLastName() called with: " + lastName);
        entity.setLastName(lastName);
    }

    // Password and salt (custom fields)
    public String getPassword() {
        return entity.getPassword();
    }

    public void setPassword(String password) {
        log.info("$ setPassword() called with: password = [" + password + "]");
        entity.setPassword(password);
    }

    public String getSalt() {
        return entity.getSalt();
    }

    public void setSalt(String salt) {
        log.info("$ setSalt() called with: salt = [" + salt + "]");
        entity.setSalt(salt);
    }

    // Keycloak ID (used internally)
    @Override
    public String getId() {
        return keycloakId;
    }

    @Override
    public boolean isEmailVerified() {
        return Boolean.TRUE.equals(entity.getValidated());
    }

    @Override
    public void setEmailVerified(boolean verified) {
        entity.setValidated(verified);
    }

    // Optional: Required actions
    @Override
    public Stream<String> getRequiredActionsStream() {
        return super.getRequiredActionsStream(); // uses federated storage
    }

    @Override
    public void addRequiredAction(String action) {
        super.addRequiredAction(action);
    }

    @Override
    public void removeRequiredAction(String action) {
        super.removeRequiredAction(action);
    }

    // Optional: Attributes — can override if storing externally
    @Override
    public void setSingleAttribute(String name, String value) {
        super.setSingleAttribute(name, value);
    }

    @Override
    public void setAttribute(String name, List<String> values) {
        super.setAttribute(name, values);
    }

    @Override
    public void removeAttribute(String name) {
        super.removeAttribute(name);
    }

    @Override
    public String getFirstAttribute(String name) {
        return super.getFirstAttribute(name);
    }

    @Override
    public Map<String, List<String>> getAttributes() {
        return super.getAttributes();
    }

    // Optional: Groups
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

    // Optional: Roles
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

    @Override
    public String toString() {
        return "UserAdapter[" + keycloakId + ", " + getUsername() + "]";
    }
}
