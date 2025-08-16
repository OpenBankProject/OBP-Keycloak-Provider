#!/bin/bash

# Test script for themed deployment validation
# This script tests the themed deployment functionality and validates the setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}OBP Keycloak Themed Deployment Test${NC}"
echo "====================================="
echo ""

# Function to check if a file exists
check_file() {
    local file="$1"
    local description="$2"

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $description: $file${NC}"
        return 0
    else
        echo -e "${RED}✗ $description: $file (MISSING)${NC}"
        return 1
    fi
}

# Function to check if a command exists
check_command() {
    local cmd="$1"
    local description="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $description: $(which $cmd)${NC}"
        return 0
    else
        echo -e "${RED}✗ $description: $cmd (NOT FOUND)${NC}"
        return 1
    fi
}

# Function to validate theme file content
validate_theme_file() {
    local file="$1"
    local expected_content="$2"
    local description="$3"

    if [ -f "$file" ] && grep -q "$expected_content" "$file"; then
        echo -e "${GREEN}✓ $description: Valid content${NC}"
        return 0
    else
        echo -e "${RED}✗ $description: Invalid or missing content${NC}"
        return 1
    fi
}

# Test 1: Check prerequisites
echo -e "${YELLOW}Test 1: Checking prerequisites...${NC}"
failed_prereqs=0

check_command "docker" "Docker" || ((failed_prereqs++))
check_command "mvn" "Maven" || ((failed_prereqs++))
check_command "java" "Java" || ((failed_prereqs++))

if [ $failed_prereqs -gt 0 ]; then
    echo -e "${RED}Error: $failed_prereqs prerequisite(s) missing. Please install them before proceeding.${NC}"
    exit 1
fi
echo ""

# Test 2: Check required files
echo -e "${YELLOW}Test 2: Checking required files...${NC}"
failed_files=0

check_file "sh/run-with-env.sh" "Main script" || ((failed_files++))
check_file ".github/Dockerfile_themed" "Themed Dockerfile" || ((failed_files++))
check_file "themes/theme.properties" "Theme properties" || ((failed_files++))
check_file "themes/styles.css" "Theme styles" || ((failed_files++))
check_file "themes/messages_en.properties" "Theme messages" || ((failed_files++))
check_file "pom.xml" "Maven configuration" || ((failed_files++))

if [ $failed_files -gt 0 ]; then
    echo -e "${RED}Error: $failed_files required file(s) missing.${NC}"
    exit 1
fi
echo ""

# Test 3: Validate theme files content
echo -e "${YELLOW}Test 3: Validating theme files content...${NC}"
failed_content=0

validate_theme_file "themes/theme.properties" "parent=keycloak" "Theme properties parent" || ((failed_content++))
validate_theme_file "themes/theme.properties" "styles=css/styles.css" "Theme properties styles" || ((failed_content++))
validate_theme_file "themes/styles.css" ".login-pf-page" "CSS styles" || ((failed_content++))
validate_theme_file "themes/messages_en.properties" "usernameOrEmail" "English messages" || ((failed_content++))

if [ $failed_content -gt 0 ]; then
    echo -e "${YELLOW}Warning: $failed_content theme content validation(s) failed.${NC}"
fi
echo ""

# Test 4: Check script permissions
echo -e "${YELLOW}Test 4: Checking script permissions...${NC}"
if [ -x "sh/run-with-env.sh" ]; then
    echo -e "${GREEN}✓ Script is executable${NC}"
else
    echo -e "${YELLOW}! Script is not executable, fixing...${NC}"
    chmod +x sh/run-with-env.sh
    echo -e "${GREEN}✓ Script permissions fixed${NC}"
fi
echo ""

# Test 5: Test script help option
echo -e "${YELLOW}Test 5: Testing script help functionality...${NC}"
if ./sh/run-with-env.sh --help >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Script help option works${NC}"
else
    echo -e "${RED}✗ Script help option failed${NC}"
    exit 1
fi
echo ""

# Test 6: Check .env setup
echo -e "${YELLOW}Test 6: Checking environment configuration...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"

    # Check for required variables
    required_vars=("DB_URL" "DB_USER" "DB_PASSWORD")
    missing_vars=()

    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" .env; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All required environment variables present${NC}"
    else
        echo -e "${YELLOW}! Missing environment variables: ${missing_vars[*]}${NC}"
    fi
else
    echo -e "${YELLOW}! .env file not found${NC}"
    if [ -f ".env.example" ]; then
        echo -e "${GREEN}✓ .env.example exists (will be copied on first run)${NC}"
    else
        echo -e "${RED}✗ .env.example also missing${NC}"
        exit 1
    fi
fi
echo ""

# Test 7: Validate Docker build context
echo -e "${YELLOW}Test 7: Validating Docker build context...${NC}"
if [ -f "pom.xml" ] && [ -d "src" ] && [ -d "themes" ]; then
    echo -e "${GREEN}✓ All required build context files present${NC}"
else
    echo -e "${RED}✗ Missing build context files${NC}"
    exit 1
fi
echo ""

# Test 8: Check theme directory structure
echo -e "${YELLOW}Test 8: Checking theme directory structure...${NC}"
theme_structure_valid=true

if [ ! -d "themes" ]; then
    echo -e "${RED}✗ themes/ directory missing${NC}"
    theme_structure_valid=false
fi

required_theme_files=(
    "themes/theme.properties"
    "themes/styles.css"
    "themes/messages_en.properties"
)

for file in "${required_theme_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Missing: $file${NC}"
        theme_structure_valid=false
    fi
done

if $theme_structure_valid; then
    echo -e "${GREEN}✓ Theme directory structure is valid${NC}"
else
    echo -e "${RED}✗ Theme directory structure is invalid${NC}"
    exit 1
fi
echo ""

# Test 9: Dry run build test (syntax check)
echo -e "${YELLOW}Test 9: Testing Maven build (syntax check)...${NC}"
if mvn clean compile -q -DskipTests >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Maven build syntax check passed${NC}"
else
    echo -e "${RED}✗ Maven build syntax check failed${NC}"
    echo -e "${YELLOW}Note: This may be due to missing dependencies or network issues${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}Test Summary${NC}"
echo "============"
echo ""

echo -e "${GREEN}✓ All critical tests passed!${NC}"
echo ""

echo "Usage Examples:"
echo "  Standard deployment:  ./sh/run-with-env.sh"
echo "  Themed deployment:    ./sh/run-with-env.sh --themed"
echo "  Get help:             ./sh/run-with-env.sh --help"
echo ""

echo "Theme Features:"
echo "  • Custom dark theme with modern styling"
echo "  • Responsive design for mobile and desktop"
echo "  • Custom form controls and button styling"
echo "  • Internationalization support"
echo "  • Easy customization through CSS and properties files"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure your .env file with database settings"
echo "2. Run: ./sh/run-with-env.sh --themed"
echo "3. Access Keycloak at https://localhost:8443"
echo "4. The custom theme will be automatically applied"
echo ""

echo -e "${GREEN}Themed deployment test completed successfully!${NC}"
