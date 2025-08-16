#!/bin/bash

# Environment Configuration Comparison Script
# This script compares .env and .env.example files to show differences

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}OBP Keycloak Provider - Environment Configuration Comparison${NC}"
echo "============================================================"

# Check if files exist
if [ ! -f ".env.example" ]; then
    echo -e "${RED}Error: .env.example file not found!${NC}"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file not found!${NC}"
    echo -e "${YELLOW}Run: cp .env.example .env${NC}"
    echo ""
    echo -e "${BLUE}Showing all variables from .env.example:${NC}"

    # Extract variables from .env.example (ignore comments and empty lines)
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # Extract variable name and value
        if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)= ]]; then
            var_name="${BASH_REMATCH[1]}"
            echo -e "${YELLOW}$var_name: [NOT SET IN .env]${NC}"
        fi
    done < .env.example

    exit 1
fi

echo -e "${GREEN}Both .env and .env.example files found${NC}"
echo ""

# Extract variables from both files
extract_variables() {
    local file="$1"
    local -A vars

    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # Extract variable name and value
        if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            vars["$var_name"]="$var_value"
        fi
    done < "$file"

    # Print variable names (keys)
    for key in "${!vars[@]}"; do
        echo "$key=${vars[$key]}"
    done
}

# Get variables from both files
echo "Analyzing configuration files..."
example_vars=$(extract_variables ".env.example")
current_vars=$(extract_variables ".env")

# Create temporary files for comparison
temp_example=$(mktemp)
temp_current=$(mktemp)

echo "$example_vars" | sort > "$temp_example"
echo "$current_vars" | sort > "$temp_current"

# Function to mask sensitive values
mask_value() {
    local var_name="$1"
    local var_value="$2"

    if [[ "$var_name" == *"PASSWORD"* ]] || [[ "$var_name" == *"SECRET"* ]]; then
        if [ -n "$var_value" ]; then
            echo "[SET - ${#var_value} chars]"
        else
            echo "[NOT SET]"
        fi
    else
        echo "$var_value"
    fi
}

echo ""
echo -e "${BLUE}=== CONFIGURATION COMPARISON ===${NC}"

# Compare variables
declare -A example_vars_map
declare -A current_vars_map

# Parse example variables
while IFS='=' read -r name value; do
    [ -n "$name" ] && example_vars_map["$name"]="$value"
done < "$temp_example"

# Parse current variables
while IFS='=' read -r name value; do
    [ -n "$name" ] && current_vars_map["$name"]="$value"
done < "$temp_current"

# Check variables in example but not in current
echo ""
echo -e "${BLUE}--- Variables in .env.example but missing from .env ---${NC}"
missing_count=0
for var in "${!example_vars_map[@]}"; do
    if [[ -z "${current_vars_map[$var]}" ]]; then
        example_value=$(mask_value "$var" "${example_vars_map[$var]}")
        echo -e "${YELLOW}$var=$example_value${NC}"
        missing_count=$((missing_count + 1))
    fi
done

if [ $missing_count -eq 0 ]; then
    echo -e "${GREEN}No missing variables${NC}"
fi

# Check variables in current but not in example
echo ""
echo -e "${BLUE}--- Variables in .env but not in .env.example ---${NC}"
extra_count=0
for var in "${!current_vars_map[@]}"; do
    if [[ -z "${example_vars_map[$var]}" ]]; then
        current_value=$(mask_value "$var" "${current_vars_map[$var]}")
        echo -e "${CYAN}$var=$current_value${NC}"
        extra_count=$((extra_count + 1))
    fi
done

if [ $extra_count -eq 0 ]; then
    echo -e "${GREEN}No extra variables${NC}"
fi

# Check variables with different values
echo ""
echo -e "${BLUE}--- Variables with different values ---${NC}"
different_count=0
for var in "${!example_vars_map[@]}"; do
    if [[ -n "${current_vars_map[$var]}" ]]; then
        if [ "${example_vars_map[$var]}" != "${current_vars_map[$var]}" ]; then
            example_value=$(mask_value "$var" "${example_vars_map[$var]}")
            current_value=$(mask_value "$var" "${current_vars_map[$var]}")
            echo -e "${CYAN}$var:${NC}"
            echo -e "   Example: $example_value"
            echo -e "   Current: $current_value"
            different_count=$((different_count + 1))
        fi
    fi
done

if [ $different_count -eq 0 ]; then
    echo -e "${GREEN}No different values found${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}=== SUMMARY ===${NC}"
echo -e "Missing variables: $missing_count"
echo -e "Extra variables: $extra_count"
echo -e "Different values: $different_count"

if [ $missing_count -eq 0 ] && [ $extra_count -eq 0 ]; then
    echo ""
    echo -e "${GREEN}Your .env file is in sync with .env.example!${NC}"
    if [ $different_count -gt 0 ]; then
        echo -e "${CYAN}You have customized $different_count variable(s) - this is normal${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}Recommendations:${NC}"

    if [ $missing_count -gt 0 ]; then
        echo -e "${YELLOW}  - Add missing variables to your .env file${NC}"
        echo -e "${YELLOW}  - Check .env.example for documentation${NC}"
    fi

    if [ $extra_count -gt 0 ]; then
        echo -e "${YELLOW}  - Review extra variables (they may be obsolete)${NC}"
        echo -e "${YELLOW}  - Consider adding them to .env.example if they're useful${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review differences above"
echo "  2. Update .env file if needed"
echo "  3. Run: ./sh/validate-env.sh"
echo "  4. Run: ./sh/run-with-env.sh"

# Cleanup
rm -f "$temp_example" "$temp_current"

echo ""
echo -e "${GREEN}Comparison completed!${NC}"
