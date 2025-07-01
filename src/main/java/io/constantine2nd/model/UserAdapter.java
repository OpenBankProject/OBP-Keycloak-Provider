package io.constantine2nd.model;

import org.jboss.logging.Logger;
import org.keycloak.component.ComponentModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.storage.StorageId;
import org.keycloak.storage.adapter.AbstractUserAdapterFederatedStorage;

public class UserAdapter extends AbstractUserAdapterFederatedStorage {

    private static final Logger log = Logger.getLogger(UserAdapter.class);
    private final KcUserEntity entity;
    private final String keycloakId;

    public UserAdapter(KeycloakSession session, RealmModel realm, ComponentModel model, KcUserEntity entity) {
        super(session, realm, model);
        this.entity = entity;
        log.info(this.entity);
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

    // Password (custom credential field)
    public String getPassword() {
        return entity.getPassword();
    }

    public void setPassword(String password) {
        log.info("$ setPassword() called with: password = [" + password + "]");
        entity.setPassword(password);
    }
    // Password (custom credential field)
    public String getSalt() {
        return entity.getSalt();
    }

    public void setSalt(String salt) {
        log.info("$ setSalt() called with: salt = [" + salt + "]");
        entity.setSalt(salt);
    }

    @Override
    public String getId() {
        return keycloakId;
    }

//    @Override
//    public Map<String, List<String>> getAttributes() {
//        Map<String, List<String>> attrs = new HashMap<>();
//        attrs.put("firstName", List.of(getFirstName()));
//        attrs.put("lastName", List.of(getLastName()));
//        attrs.put("email", List.of(getEmail()));
//        return attrs;
//    }

    @Override
    public boolean isEmailVerified() {
        return entity.getValidated();
    }

}
