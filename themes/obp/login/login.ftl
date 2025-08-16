<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
    <#if section = "header">
        ${msg("loginAccountTitle")}
    <#elseif section = "form">
        <div class="obp-form">
            <#if realm.password>
                <form id="kc-form-login" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post" class="obp-login-form">
                    <#if !usernameHidden??>
                        <div class="obp-form-group">
                            <label for="username" class="obp-label">
                                <#if !realm.loginWithEmailAllowed>${msg("username")}
                                <#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}
                                <#else>${msg("email")}
                                </#if>
                            </label>

                            <input tabindex="1" id="username" class="obp-input" name="username"
                                   value="${(login.username!'')}" type="text" autofocus autocomplete="off"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                                   placeholder="<#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if>"
                            />

                            <#if messagesPerField.existsError('username','password')>
                                <span class="obp-error-message" aria-live="polite">
                                    ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                                </span>
                            </#if>
                        </div>
                    </#if>

                    <div class="obp-form-group">
                        <label for="password" class="obp-label">${msg("password")}</label>

                        <div class="obp-input-group">
                            <input tabindex="2" id="password" class="obp-input" name="password"
                                   type="password" autocomplete="current-password"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                                   placeholder="${msg("password")}"
                            />
                            <button class="obp-password-toggle" type="button" aria-label="${msg("showPassword")}"
                                    aria-controls="password" data-password-toggle
                                    data-icon-show="fas fa-eye" data-icon-hide="fas fa-eye-slash"
                                    data-label-show="${msg('showPassword')}" data-label-hide="${msg('hidePassword')}">
                                <i class="fas fa-eye" aria-hidden="true"></i>
                            </button>
                        </div>

                        <#if usernameHidden?? && messagesPerField.existsError('username','password')>
                            <span class="obp-error-message" aria-live="polite">
                                ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                            </span>
                        </#if>
                    </div>

                    <div class="obp-form-options">
                        <div class="obp-form-remember">
                            <#if realm.rememberMe && !usernameHidden??>
                                <div class="obp-checkbox">
                                    <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox"
                                           class="obp-checkbox-input" <#if login.rememberMe??>checked</#if>>
                                    <label for="rememberMe" class="obp-checkbox-label">${msg("rememberMe")}</label>
                                </div>
                            </#if>
                        </div>
                        <div class="obp-form-links">
                            <#if realm.resetPasswordAllowed>
                                <a tabindex="5" href="${url.loginResetCredentialsUrl}" class="obp-link">${msg("doForgotPassword")}</a>
                            </#if>
                        </div>
                    </div>

                    <div class="obp-form-buttons">
                        <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                        <button tabindex="4" class="obp-button obp-button-primary" name="login" id="kc-login" type="submit">
                            ${msg("doLogIn")}
                        </button>
                    </div>
                </form>
            </#if>
        </div>
    <#elseif section = "info">
        <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
            <div class="obp-info-container">
                <div class="obp-registration-link">
                    <span class="obp-text">${msg("noAccount")} </span>
                    <a tabindex="6" href="${url.registrationUrl}" class="obp-link obp-link-bold">${msg("doRegister")}</a>
                </div>
            </div>
        </#if>
    <#elseif section = "socialProviders">
        <#if realm.password && social.providers??>
            <div class="obp-social-providers">
                <div class="obp-divider">
                    <span class="obp-divider-text">${msg("identity-provider-login-label")}</span>
                </div>
                <div class="obp-social-buttons">
                    <#list social.providers as p>
                        <a id="social-${p.alias}" class="obp-social-button"
                           href="${p.loginUrl}" title="Sign in with ${p.displayName!}">
                            <#if p.iconClasses?has_content>
                                <i class="${p.iconClasses!}" aria-hidden="true"></i>
                            </#if>
                            <span class="obp-social-text">${p.displayName!}</span>
                        </a>
                    </#list>
                </div>
            </div>
        </#if>
    </#if>
</@layout.registrationLayout>
