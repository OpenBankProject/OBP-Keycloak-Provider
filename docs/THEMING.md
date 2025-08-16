# Keycloak Theme Customization Guide

This document provides comprehensive guidance on customizing Keycloak themes in the OBP-Keycloak-Provider project.

## Overview

The OBP-Keycloak-Provider includes custom theme support that allows you to:
- Apply custom branding and styling to Keycloak login pages
- Customize internationalization messages
- Create responsive designs for different devices
- Maintain theme consistency across your application

## Theme Structure

The theme files are located in the `themes/` directory:

```
themes/
├── theme.properties      # Theme configuration
├── styles.css           # Custom CSS styling
└── messages_en.properties # Internationalization messages
```

### Theme Properties (`theme.properties`)

Defines the basic theme configuration:

```properties
parent=keycloak
styles=css/styles.css
```

- **parent**: Specifies the base theme to inherit from (Keycloak's default theme)
- **styles**: References the custom CSS file for styling overrides

### Custom Styling (`styles.css`)

Contains custom CSS that implements a modern dark theme:

#### Key Features:
- **Dark Theme**: Black/dark gray backgrounds with light text
- **Responsive Design**: Optimized for mobile, tablet, and desktop
- **Modern UI Components**: Custom form controls, buttons, and layouts
- **Consistent Branding**: Professional appearance with custom colors

#### Main Style Components:

1. **Layout and Container Styles**:
   - Responsive card layout with auto-centering
   - Maximum width constraints for larger screens
   - Professional spacing and margins

2. **Form Controls**:
   - Dark input fields with custom borders
   - Consistent height and padding
   - Hover effects for better user experience

3. **Buttons**:
   - Primary buttons with light background
   - Hover states for interactive feedback
   - Control buttons with dark styling

4. **Typography**:
   - Light gray text for readability on dark backgrounds
   - Bold headers for emphasis
   - Consistent font styling

### Internationalization (`messages_en.properties`)

Customizes text labels displayed in the UI:

```properties
usernameOrEmail=Username
password=Password
```

You can add more message customizations as needed:

```properties
loginTitle=Sign In to OBP
loginUsernameOrEmail=Username or Email
loginPassword=Password
loginSubmit=Sign In
loginForgotPassword=Forgot Password?
```

## Deployment Options

### 1. Standard Deployment

Runs Keycloak without custom themes:

```bash
./sh/run-with-env.sh
# or explicitly
./sh/run-with-env.sh --standard
```

### 2. Themed Deployment

Runs Keycloak with custom themes enabled:

```bash
./sh/run-with-env.sh --themed
```

This deployment:
- Uses the `.github/Dockerfile_themed` for building
- Passes database configuration as build arguments for Maven resource filtering
- Copies theme files to the correct Keycloak directories
- Makes the custom theme available as 'obp' in the theme selector

**Important**: Themed deployment requires your `.env` file to be configured before building, as database configuration is embedded into the JAR during build time through Maven resource filtering.

## Theme Development Workflow

### 1. Testing Your Setup

Before making changes, validate your themed deployment:

```bash
./sh/test-themed-deployment.sh
```

This script checks:
- Prerequisites (Docker, Maven, Java)
- Required theme files
- File content validation
- Script permissions
- Environment configuration

### 2. Customizing Styles

To modify the appearance:

1. **Edit `themes/styles.css`**:
   ```css
   /* Example: Change primary button color */
   .pf-c-button.pf-m-primary {
     color: #fff;
     background-color: #007bff;
   }
   
   /* Example: Modify login card background */
   .card-pf {
     background: #1a1a1a;
     border-radius: 8px;
   }
   ```

2. **Rebuild and test**:
   ```bash
   ./sh/run-with-env.sh --themed
   ```

3. **Access the login page**:
   - Navigate to `https://localhost:8443`
   - Your changes should be visible immediately

### 3. Adding Internationalization

To add support for additional languages:

1. **Create new message files**:
   ```bash
   cp themes/messages_en.properties themes/messages_es.properties
   cp themes/messages_en.properties themes/messages_fr.properties
   ```

2. **Translate the messages**:
   ```properties
   # messages_es.properties
   usernameOrEmail=Usuario o Email
   password=Contraseña
   ```

3. **Update the themed Dockerfile** to copy additional files:
   ```dockerfile
   COPY themes/messages_*.properties /opt/keycloak/themes/obp/login/messages/
   ```

### 4. Configuration Architecture

#### Build-Time vs Runtime Configuration

**Themed Deployment** uses a hybrid configuration approach:

- **Build-Time Configuration**: Database settings are embedded into the JAR file during Maven build through resource filtering. This happens when Docker builds the image.
- **Runtime Configuration**: Environment variables can still override Docker container settings, but database connection details are fixed at build time.

**Why Build-Time Configuration?**
- Keycloak 26.x (Quarkus-based) doesn't support runtime environment variable substitution in persistence.xml
- Maven resource filtering provides a clean way to inject configuration during build
- Ensures consistent database configuration across deployments

### 4. Advanced Customization

#### Adding Custom Templates

To customize HTML templates:

1. **Create template directory**:
   ```bash
   mkdir -p themes/login
   ```

2. **Copy base templates from Keycloak**:
   ```bash
   # Extract templates from Keycloak container
   docker run --rm quay.io/keycloak/keycloak:26.0.5 \
     tar -cf - /opt/keycloak/themes/base/login/*.ftl | \
     tar -xf - --strip-components=5 -C themes/login/
   ```

3. **Modify templates as needed** and update the Dockerfile to copy them.

#### Adding Custom Images/Assets

1. **Create resources directory**:
   ```bash
   mkdir -p themes/resources/img
   ```

2. **Add your images**:
   ```bash
   cp your-logo.png themes/resources/img/
   ```

3. **Reference in CSS**:
   ```css
   .login-pf-header {
     background-image: url('../img/your-logo.png');
   }
   ```

4. **Update Dockerfile** to copy resources:
   ```dockerfile
   COPY themes/resources/ /opt/keycloak/themes/obp/login/resources/
   ```

## Environment Variables

### Build-Time Variables

When using themed deployment, these variables are read from your `.env` file during Docker build:

```bash
DB_URL=jdbc:postgresql://host:port/database
DB_USER=username
DB_PASSWORD=password
DB_DRIVER=org.postgresql.Driver
DB_DIALECT=org.hibernate.dialect.PostgreSQLDialect
HIBERNATE_DDL_AUTO=validate
HIBERNATE_SHOW_SQL=true
HIBERNATE_FORMAT_SQL=true
```

These are passed as Docker build arguments and embedded into the JAR file through Maven resource filtering.

### Runtime Variables

These environment variables can be set at container runtime:

```bash
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin
KC_HEALTH_ENABLED=true
KC_METRICS_ENABLED=true
```

Note: Database configuration cannot be changed at runtime for themed deployments - it must be configured before building.

## Troubleshooting

### Theme Not Applying

1. **Check container logs**:
   ```bash
   docker logs -f obp-keycloak
   ```

2. **Verify theme files in container**:
   ```bash
   docker exec -it obp-keycloak ls -la /opt/keycloak/themes/obp/login/
   ```

3. **Check theme configuration in Keycloak Admin**:
   - Go to Admin Console > Realm Settings > Themes
   - Select "obp" for Login Theme
   - Click "Save"

### Database Connection Errors

If you see errors like `Unable to resolve name [${DB_DIALECT}]`:

1. **Verify .env file configuration**:
   ```bash
   ./sh/validate-env.sh
   ```

2. **Ensure .env file exists before building**:
   ```bash
   ls -la .env
   ```

3. **Rebuild with correct configuration**:
   ```bash
   # Fix .env file first, then rebuild
   ./sh/run-with-env.sh --themed
   ```

4. **Check filtered persistence.xml** (locally):
   ```bash
   mvn clean package -DskipTests -DDB_URL="your_url" ...
   cat target/classes/META-INF/persistence.xml
   ```

### CSS Changes Not Visible

1. **Clear browser cache** (Ctrl+F5 or Cmd+Shift+R)
2. **Check CSS syntax** for errors
3. **Verify file permissions** in the container
4. **Restart the container** to reload themes

### Build Failures

1. **Validate theme files**:
   ```bash
   ./sh/test-themed-deployment.sh
   ```

2. **Check Docker build logs** for specific errors
3. **Ensure all theme files exist** before building

## Best Practices

1. **Version Control**: Keep theme files in version control
2. **Testing**: Test themes on different screen sizes and browsers
3. **Backup**: Keep backups of working theme configurations
4. **Documentation**: Document custom changes for team members
5. **Validation**: Use the test script before deploying to production

## CSS Class Reference

### Common Keycloak CSS Classes

- `.login-pf-page`: Main login page container
- `.card-pf`: Login form card
- `.pf-c-form-control`: Input fields
- `.pf-c-button.pf-m-primary`: Primary buttons
- `.pf-c-form__label-text`: Form labels
- `.login-pf-header`: Header section

### Custom Variables

The theme uses CSS custom properties for easy customization:

```css
:root {
  --obp-primary-color: #000;
  --obp-secondary-color: #aaa;
  --obp-background-color: #030303;
  --obp-card-background: #000;
  --obp-border-color: #0a0917;
}
```

## Production Considerations

1. **Performance**: Optimize CSS for production (minification, compression)
2. **Caching**: Configure proper cache headers for theme assets
3. **Security**: Ensure theme files don't expose sensitive information
4. **Monitoring**: Monitor theme loading and performance
5. **Fallbacks**: Ensure graceful degradation if custom themes fail

## Support and Resources

- **Keycloak Theming Documentation**: [Official Keycloak Docs](https://www.keycloak.org/docs/latest/server_development/#_themes)
- **Theme Testing Script**: `./sh/test-themed-deployment.sh`
- **Project Issues**: Submit issues via GitHub for theme-related problems
- **Community**: Engage with the Keycloak community for advanced theming questions