<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="robots" content="noindex, nofollow">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>${msg("loginTitle",(realm.displayName!''))}</title>
    <link rel="icon" href="${url.resourcesPath}/img/favicon.png" />

    <!-- Font Awesome for icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">

    <!-- Google Fonts - Plus Jakarta Sans -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:ital,wght@0,200..800;1,200..800&display=swap" rel="stylesheet">

    <!-- OBP Theme CSS -->
    <link href="${url.resourcesPath}/css/styles.css" rel="stylesheet" />

    <!-- JavaScript for form functionality -->
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // Password visibility toggle
            const toggleButton = document.querySelector('[data-password-toggle]');
            if (toggleButton) {
                toggleButton.addEventListener('click', function() {
                    const passwordField = document.getElementById('password');
                    const icon = this.querySelector('i');
                    if (passwordField.type === 'password') {
                        passwordField.type = 'text';
                        icon.className = 'fas fa-eye-slash';
                        this.setAttribute('aria-label', 'Hide password');
                    } else {
                        passwordField.type = 'password';
                        icon.className = 'fas fa-eye';
                        this.setAttribute('aria-label', 'Show password');
                    }
                });
            }

            // Form validation
            const loginForm = document.getElementById('kc-form-login');
            if (loginForm) {
                loginForm.addEventListener('submit', function(e) {
                    const username = document.getElementById('username');
                    const password = document.getElementById('password');

                    if (username && !username.value.trim()) {
                        e.preventDefault();
                        username.focus();
                        return false;
                    }

                    if (password && !password.value) {
                        e.preventDefault();
                        password.focus();
                        return false;
                    }

                    // Disable submit button to prevent double submission
                    const submitButton = document.getElementById('kc-login');
                    if (submitButton) {
                        submitButton.disabled = true;
                        submitButton.value = 'Signing in...';
                    }
                });
            }
        });
    </script>
</head>

<body class="obp-login-body">
    <div class="obp-login-container">
        <div class="obp-login-card">
            <!-- Logo and Header -->
            <header class="obp-login-header">
                <div class="obp-logo-container">
                    <img src="${url.resourcesPath}/img/obp_logo.png" alt="Open Bank Project" class="obp-logo" />
                </div>
                <h1 class="obp-login-title">${kcSanitize(msg("loginTitleHtml",(realm.displayNameHtml!'')))?no_esc}</h1>
            </header>

            <!-- Main Content -->
            <div class="obp-login-content">
                <!-- Messages (Errors, Success, Info) -->
                <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
                    <div class="obp-alert obp-alert-${message.type}">
                        <div class="obp-alert-icon">
                            <#if message.type = 'success'><i class="fas fa-check-circle"></i></#if>
                            <#if message.type = 'warning'><i class="fas fa-exclamation-triangle"></i></#if>
                            <#if message.type = 'error'><i class="fas fa-times-circle"></i></#if>
                            <#if message.type = 'info'><i class="fas fa-info-circle"></i></#if>
                        </div>
                        <div class="obp-alert-content">${kcSanitize(message.summary)?no_esc}</div>
                    </div>
                </#if>

                <!-- Form Content -->
                <div class="obp-form-container">
                    <#nested "form">
                </div>

                <!-- Try Another Way Link -->
                <#if auth?? && auth.showTryAnotherWayLink() && showAnotherWayIfPresent>
                    <form id="kc-select-try-another-way-form" action="${url.loginAction}" method="post" class="obp-try-another-way">
                        <input type="hidden" name="tryAnotherWay" value="on"/>
                        <a href="#" class="obp-link" onclick="document.forms['kc-select-try-another-way-form'].submit();return false;">
                            ${msg("doTryAnotherWay")}
                        </a>
                    </form>
                </#if>

                <!-- Social Providers -->
                <#nested "socialProviders">

                <!-- Info Section -->
                <#if displayInfo>
                    <div class="obp-info-section">
                        <#nested "info">
                    </div>
                </#if>
            </div>

            <!-- Footer -->
            <footer class="obp-login-footer">
                <p class="obp-copyright">© 2011-2025 TESOBE. All rights reserved.</p>
            </footer>
        </div>
    </div>
</body>
</html>
</#macro>
