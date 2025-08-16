#!/bin/bash

# Environment Configuration Validation Script
# This script validates the .env file configuration for OBP Keycloak Provider

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}OBP Keycloak Provider - Environment Validation${NC}"
echo "================================================"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo -e "${YELLOW}Run: cp .env.example .env${NC}"
    echo -e "${YELLOW}   Then edit .env with your configuration${NC}"
    exit 1
fi

echo -e "${GREEN}.env file found${NC}"

# Load environment variables from .env file
echo "Loading environment variables from .env file..."
export $(grep -v '^#' .env | grep -v '^$' | xargs)

echo ""
echo -e "${BLUE}=== VALIDATION RESULTS ===${NC}"

# Validation flags
validation_passed=true
warnings=0

# Required variables for database
required_db_vars=("DB_URL" "DB_USER" "DB_PASSWORD")
optional_db_vars=("DB_DRIVER" "DB_DIALECT" "HIBERNATE_DDL_AUTO" "HIBERNATE_SHOW_SQL" "HIBERNATE_FORMAT_SQL")

# Required variables for Keycloak
required_kc_vars=("KC_BOOTSTRAP_ADMIN_USERNAME" "KC_BOOTSTRAP_ADMIN_PASSWORD")
optional_kc_vars=("KC_HEALTH_ENABLED" "KC_METRICS_ENABLED" "KC_FEATURES" "KC_HOSTNAME_STRICT" "KC_LOG_LEVEL" "LOG_LEVEL")

echo ""
echo -e "${BLUE}--- Database Configuration ---${NC}"

# Validate required database variables
for var in "${required_db_vars[@]}"; do
    var_value="${!var}"
    if [ -z "$var_value" ]; then
        echo -e "${RED}Missing required variable: $var${NC}"
        validation_passed=false
    else
        case $var in
            "DB_URL")
                if [[ ! "$var_value" =~ ^jdbc:postgresql://.*:[0-9]+/.+ ]]; then
                    echo -e "${RED}Invalid DB_URL format: $var_value${NC}"
                    echo -e "${YELLOW}   Expected format: jdbc:postgresql://host:port/database${NC}"
                    validation_passed=false
                else
                    echo -e "${GREEN}$var: $var_value${NC}"
                fi
                ;;
            "DB_USER")
                if [ ${#var_value} -lt 1 ]; then
                    echo -e "${RED}DB_USER cannot be empty${NC}"
                    validation_passed=false
                else
                    echo -e "${GREEN}$var: $var_value${NC}"
                fi
                ;;
            "DB_PASSWORD")
                if [ ${#var_value} -lt 1 ]; then
                    echo -e "${RED}DB_PASSWORD cannot be empty${NC}"
                    validation_passed=false
                elif [ ${#var_value} -lt 8 ]; then
                    echo -e "${YELLOW}$var: [SET] (Warning: Password is less than 8 characters)${NC}"
                    warnings=$((warnings + 1))
                elif [ "$var_value" = "changeme" ] || [ "$var_value" = "password" ] || [ "$var_value" = "123456" ]; then
                    echo -e "${YELLOW}$var: [SET] (Warning: Using weak/default password)${NC}"
                    warnings=$((warnings + 1))
                else
                    echo -e "${GREEN}$var: [SET] (${#var_value} characters)${NC}"
                fi
                ;;
        esac
    fi
done

# Validate optional database variables
for var in "${optional_db_vars[@]}"; do
    var_value="${!var}"
    if [ -n "$var_value" ]; then
        case $var in
            "DB_DRIVER")
                if [[ "$var_value" == *"postgresql"* ]]; then
                    echo -e "${GREEN}$var: $var_value${NC}"
                else
                    echo -e "${YELLOW}$var: $var_value (Warning: Not a PostgreSQL driver)${NC}"
                    warnings=$((warnings + 1))
                fi
                ;;
            "HIBERNATE_DDL_AUTO")
                if [[ "$var_value" =~ ^(validate|update|create|create-drop|none)$ ]]; then
                    echo -e "${GREEN}$var: $var_value${NC}"
                    if [ "$var_value" = "create" ] || [ "$var_value" = "create-drop" ]; then
                        echo -e "${YELLOW}   Warning: This mode will modify/destroy existing data${NC}"
                        warnings=$((warnings + 1))
                    fi
                else
                    echo -e "${YELLOW}$var: $var_value (Warning: Invalid value)${NC}"
                    echo -e "${YELLOW}   Valid values: validate, update, create, create-drop, none${NC}"
                    warnings=$((warnings + 1))
                fi
                ;;
            "HIBERNATE_SHOW_SQL"|"HIBERNATE_FORMAT_SQL")
                if [[ "$var_value" =~ ^(true|false)$ ]]; then
                    echo -e "${GREEN}$var: $var_value${NC}"
                else
                    echo -e "${YELLOW}$var: $var_value (Warning: Should be true or false)${NC}"
                    warnings=$((warnings + 1))
                fi
                ;;
            *)
                echo -e "${GREEN}$var: $var_value${NC}"
                ;;
        esac
    else
        echo -e "${BLUE}$var: [Using default]${NC}"
    fi
done

echo ""
echo -e "${BLUE}--- Keycloak Configuration ---${NC}"

# Validate required Keycloak variables
for var in "${required_kc_vars[@]}"; do
    var_value="${!var}"
    if [ -z "$var_value" ]; then
        echo -e "${RED}Missing required variable: $var${NC}"
        validation_passed=false
    else
        case $var in
            "KC_BOOTSTRAP_ADMIN_USERNAME")
                if [ ${#var_value} -lt 3 ]; then
                    echo -e "${YELLOW}$var: $var_value (Warning: Username is very short)${NC}"
                    warnings=$((warnings + 1))
                else
                    echo -e "${GREEN}$var: $var_value${NC}"
                fi
                ;;
            "KC_BOOTSTRAP_ADMIN_PASSWORD")
                if [ ${#var_value} -lt 8 ]; then
                    echo -e "${YELLOW}$var: [SET] (Warning: Password is less than 8 characters)${NC}"
                    warnings=$((warnings + 1))
                elif [ "$var_value" = "admin" ] || [ "$var_value" = "password" ] || [ "$var_value" = "123456" ]; then
                    echo -e "${YELLOW}$var: [SET] (Warning: Using weak/default password)${NC}"
                    warnings=$((warnings + 1))
                else
                    echo -e "${GREEN}$var: [SET] (${#var_value} characters)${NC}"
                fi
                ;;
        esac
    fi
done

# Validate optional Keycloak variables
for var in "${optional_kc_vars[@]}"; do
    var_value="${!var}"
    if [ -n "$var_value" ]; then
        case $var in
            "KC_HEALTH_ENABLED"|"KC_METRICS_ENABLED"|"KC_HOSTNAME_STRICT")
                if [[ "$var_value" =~ ^(true|false)$ ]]; then
                    echo -e "${GREEN}$var: $var_value${NC}"
                else
                    echo -e "${YELLOW}$var: $var_value (Warning: Should be true or false)${NC}"
                    warnings=$((warnings + 1))
                fi
                ;;
            "KC_LOG_LEVEL"|"LOG_LEVEL")
                if [[ "$var_value" =~ ^(TRACE|DEBUG|INFO|WARN|ERROR)$ ]]; then
                    echo -e "${GREEN}$var: $var_value${NC}"
                else
                    echo -e "${YELLOW}$var: $var_value (Warning: Invalid log level)${NC}"
                    echo -e "${YELLOW}   Valid values: TRACE, DEBUG, INFO, WARN, ERROR${NC}"
                    warnings=$((warnings + 1))
                fi
                ;;
            *)
                echo -e "${GREEN}$var: $var_value${NC}"
                ;;
        esac
    else
        echo -e "${BLUE}$var: [Using default]${NC}"
    fi
done

echo ""
echo -e "${BLUE}=== VALIDATION SUMMARY ===${NC}"

if [ "$validation_passed" = true ]; then
    echo -e "${GREEN}All required variables are properly configured${NC}"

    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}$warnings warning(s) found - please review above${NC}"
        echo -e "${YELLOW}   The configuration will work but may not be optimal${NC}"
    else
        echo -e "${GREEN}Perfect! No warnings found${NC}"
    fi

    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Review any warnings above"
    echo "  2. Run: ./sh/run-with-env.sh"
    echo "  3. Access Keycloak at: http://localhost:8080 or https://localhost:8443"

else
    echo -e "${RED}Validation failed! Please fix the errors above${NC}"
    echo ""
    echo -e "${YELLOW}To fix:${NC}"
    echo "  1. Edit the .env file and set the missing variables"
    echo "  2. Run this script again to validate"
    echo "  3. Once validation passes, run: ./sh/run-with-env.sh"

    exit 1
fi

echo ""
echo -e "${BLUE}=== SECURITY REMINDERS ===${NC}"
echo -e "${YELLOW}Remember to:${NC}"
echo "  - Never commit the .env file to version control"
echo "  - Use strong passwords in production"
echo "  - Change default admin credentials after first login"
echo "  - Enable HTTPS in production environments"
echo "  - Regularly rotate credentials"

echo ""
echo -e "${GREEN}Validation completed successfully!${NC}"
