#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#
# diagnose-deployment-failure.sh
#
# Diagnoses FinOps Hub deployment failures, especially uploadSettings script failures.
# This script performs comprehensive diagnostics including permission checks, RBAC status,
# and deployment history analysis.
#
# Usage:
#   ./diagnose-deployment-failure.sh -g <resource-group-name> [-s <storage-account-name>] [-sub <subscription-id>]
#
# Examples:
#   ./diagnose-deployment-failure.sh -g finhub-rg
#   ./diagnose-deployment-failure.sh -g finhub-rg -s finopshubstorage
#
# Requirements:
#   - Azure CLI (az) must be installed
#   - User must be authenticated (az login)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Helper functions
write_section_header() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}============================================${NC}"
}

write_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

write_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

write_failure() {
    echo -e "${RED}[ERROR]${NC} $1"
}

write_info() {
    echo -e "${GRAY}[INFO]${NC} $1"
}

# Usage information
usage() {
    echo "Usage: $0 -g <resource-group-name> [-s <storage-account-name>] [-sub <subscription-id>]"
    echo ""
    echo "Required:"
    echo "  -g    Resource group name where FinOps Hub is deployed"
    echo ""
    echo "Optional:"
    echo "  -s    Storage account name (auto-detected if not provided)"
    echo "  -sub  Subscription ID (uses current subscription if not provided)"
    echo "  -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -g finhub-rg"
    echo "  $0 -g finhub-rg -s finopshubstorage"
    echo ""
    exit 1
}

# Parse arguments
RESOURCE_GROUP=""
STORAGE_ACCOUNT=""
SUBSCRIPTION_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -s|--storage-account)
            STORAGE_ACCOUNT="$2"
            shift 2
            ;;
        -sub|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}Error: Resource group name is required${NC}"
    usage
fi

# Main script
main() {
    write_section_header "FinOps Hub Deployment Diagnostics"

    # Check if Azure CLI is installed
    write_info "Checking Azure CLI installation..."
    if ! command -v az &> /dev/null; then
        write_failure "Azure CLI is not installed"
        write_info "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    write_success "Azure CLI is installed"

    # Check if user is authenticated
    write_info "Checking Azure authentication..."
    if ! az account show &> /dev/null; then
        write_failure "Not authenticated to Azure"
        write_info "Run: az login"
        exit 1
    fi

    CURRENT_USER=$(az account show --query user.name -o tsv)
    write_success "Authenticated as: $CURRENT_USER"

    # Set subscription if provided
    if [ -n "$SUBSCRIPTION_ID" ]; then
        write_info "Switching to subscription: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi

    CURRENT_SUB_NAME=$(az account show --query name -o tsv)
    CURRENT_SUB_ID=$(az account show --query id -o tsv)
    write_info "Using subscription: $CURRENT_SUB_NAME ($CURRENT_SUB_ID)"

    # Check if resource group exists
    write_section_header "Resource Group Validation"
    write_info "Checking resource group: $RESOURCE_GROUP"

    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        write_failure "Resource group '$RESOURCE_GROUP' not found"
        exit 1
    fi

    RG_LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    write_success "Resource group found: $RG_LOCATION"

    # Auto-detect storage account if not provided
    if [ -z "$STORAGE_ACCOUNT" ]; then
        write_info "Auto-detecting storage account..."
        STORAGE_ACCOUNTS=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv)

        if [ -z "$STORAGE_ACCOUNTS" ]; then
            write_failure "No storage accounts found in resource group"
            exit 1
        fi

        STORAGE_ACCOUNT=$(echo "$STORAGE_ACCOUNTS" | head -n 1)
        ACCOUNT_COUNT=$(echo "$STORAGE_ACCOUNTS" | wc -l)

        if [ "$ACCOUNT_COUNT" -gt 1 ]; then
            write_warning "Multiple storage accounts found. Using first one: $STORAGE_ACCOUNT"
            write_info "Specify -s parameter to target a specific account"
        fi
    fi
    write_success "Using storage account: $STORAGE_ACCOUNT"

    # Check user permissions
    write_section_header "User Permissions Check"
    write_info "Checking permissions for: $CURRENT_USER"

    RG_ID="/subscriptions/$CURRENT_SUB_ID/resourceGroups/$RESOURCE_GROUP"
    USER_ROLES=$(az role assignment list --scope "$RG_ID" --assignee "$CURRENT_USER" --query "[].roleDefinitionName" -o tsv)

    if echo "$USER_ROLES" | grep -qE "Contributor|Owner"; then
        write_success "Has Contributor (or Owner) role"
    else
        write_failure "Missing Contributor role"
        write_info "You need Contributor or Owner role to deploy resources"
    fi

    if echo "$USER_ROLES" | grep -qE "User Access Administrator|Owner"; then
        write_success "Has User Access Administrator (or Owner) role"
    else
        write_failure "Missing User Access Administrator role"
        write_info "You need User Access Administrator or Owner role to assign roles to managed identities"
    fi

    # Check storage account
    write_section_header "Storage Account Check"

    if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        write_failure "Storage account '$STORAGE_ACCOUNT' not found"
        exit 1
    fi

    write_success "Storage account exists"

    STORAGE_SKU=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query sku.name -o tsv)
    STORAGE_LOCATION=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query location -o tsv)
    STORAGE_STATE=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query provisioningState -o tsv)

    write_info "  SKU: $STORAGE_SKU"
    write_info "  Location: $STORAGE_LOCATION"
    write_info "  Provisioning State: $STORAGE_STATE"

    # Check if config container exists
    write_info "Checking for 'config' container..."
    if az storage container exists --name config --account-name "$STORAGE_ACCOUNT" --auth-mode login --query exists -o tsv 2>/dev/null | grep -q "true"; then
        write_success "Config container exists"
    else
        write_warning "Config container not found - deployment may be incomplete"
    fi

    # Check managed identity
    write_section_header "Managed Identity Check"
    IDENTITY_NAME="${STORAGE_ACCOUNT}_blobManager"
    write_info "Looking for managed identity: $IDENTITY_NAME"

    if ! az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        write_failure "Managed identity '$IDENTITY_NAME' not found"
        write_info "The deployment may have failed before creating the identity"
    else
        write_success "Managed identity found"

        IDENTITY_PRINCIPAL=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)
        IDENTITY_CLIENT=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)

        write_info "  Principal ID: $IDENTITY_PRINCIPAL"
        write_info "  Client ID: $IDENTITY_CLIENT"

        # Check role assignments
        write_info "Checking role assignments for managed identity..."
        STORAGE_ACCOUNT_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
        IDENTITY_ROLES=$(az role assignment list --assignee "$IDENTITY_PRINCIPAL" --scope "$STORAGE_ACCOUNT_ID" --query "[].roleDefinitionName" -o tsv)

        if echo "$IDENTITY_ROLES" | grep -q "Storage Blob Data Contributor"; then
            write_success "Has 'Storage Blob Data Contributor' role"
        else
            write_failure "Missing 'Storage Blob Data Contributor' role"
            write_info "This role is required to read/write blobs in the storage account"
        fi

        if echo "$IDENTITY_ROLES" | grep -q "Storage Account Contributor"; then
            write_success "Has 'Storage Account Contributor' role"
        else
            write_warning "Missing 'Storage Account Contributor' role (may be optional for some configurations)"
        fi

        # Check RBAC propagation
        write_info "Testing RBAC propagation..."
        if az storage container list --account-name "$STORAGE_ACCOUNT" --auth-mode login &> /dev/null; then
            write_success "RBAC permissions are working (propagated)"
        else
            write_warning "RBAC permissions not yet propagated"
            write_info "Azure RBAC can take 5-10 minutes to propagate after role assignment"
            write_info "This is the MOST COMMON cause of deployment failures"
        fi
    fi

    # Check deployment scripts
    write_section_header "Deployment Scripts Check"
    write_info "Looking for deployment scripts in resource group..."

    DEPLOYMENT_SCRIPTS=$(az resource list --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.Resources/deploymentScripts" --query "[].name" -o tsv)

    if [ -z "$DEPLOYMENT_SCRIPTS" ]; then
        write_warning "No deployment scripts found"
        write_info "Deployment may have failed before reaching the script execution phase"
    else
        SCRIPT_COUNT=$(echo "$DEPLOYMENT_SCRIPTS" | wc -l)
        write_success "Found $SCRIPT_COUNT deployment script(s)"

        while IFS= read -r script_name; do
            write_info ""
            write_info "Script: $script_name"

            SCRIPT_STATE=$(az resource show --resource-group "$RESOURCE_GROUP" --name "$script_name" --resource-type "Microsoft.Resources/deploymentScripts" --query properties.provisioningState -o tsv 2>/dev/null)

            write_info "  Provisioning State: $SCRIPT_STATE"

            if [ "$SCRIPT_STATE" == "Failed" ]; then
                write_failure "  Deployment script failed!"

                # Try to get error details
                ERROR_MSG=$(az resource show --resource-group "$RESOURCE_GROUP" --name "$script_name" --resource-type "Microsoft.Resources/deploymentScripts" --query properties.status.error.message -o tsv 2>/dev/null)
                if [ -n "$ERROR_MSG" ]; then
                    write_failure "  Error Message: $ERROR_MSG"
                fi
            elif [ "$SCRIPT_STATE" == "Succeeded" ]; then
                write_success "  Deployment script succeeded"
            fi
        done <<< "$DEPLOYMENT_SCRIPTS"
    fi

    # Check recent deployments
    write_section_header "Recent Deployments Check"
    write_info "Retrieving recent deployments..."

    DEPLOYMENTS=$(az deployment group list --resource-group "$RESOURCE_GROUP" --query "[].{name:name, state:properties.provisioningState, timestamp:properties.timestamp}" -o json)

    if [ -n "$DEPLOYMENTS" ] && [ "$DEPLOYMENTS" != "[]" ]; then
        echo "$DEPLOYMENTS" | jq -r '.[] | "\(.name) - \(.state) (\(.timestamp))"' | head -n 10 | while IFS= read -r line; do
            if echo "$line" | grep -q "Succeeded"; then
                echo -e "  ${GREEN}$line${NC}"
            elif echo "$line" | grep -q "Failed"; then
                echo -e "  ${RED}$line${NC}"
            else
                echo -e "  ${YELLOW}$line${NC}"
            fi
        done
    fi

    # Network connectivity check
    write_section_header "Network Connectivity Check"
    write_info "Checking storage account network rules..."

    DEFAULT_ACTION=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query networkRuleSet.defaultAction -o tsv)

    if [ "$DEFAULT_ACTION" == "Deny" ]; then
        write_warning "Storage account has network restrictions (DefaultAction: Deny)"
        IP_RULES_COUNT=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "length(networkRuleSet.ipRules)" -o tsv)
        VNET_RULES_COUNT=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "length(networkRuleSet.virtualNetworkRules)" -o tsv)
        write_info "  Allowed IP ranges: $IP_RULES_COUNT"
        write_info "  Allowed virtual networks: $VNET_RULES_COUNT"
        write_info "  This may prevent deployment scripts from accessing storage"
    else
        write_success "Storage account allows public network access"
    fi

    # Summary and recommendations
    write_section_header "Summary and Recommendations"

    echo ""
    echo -e "${CYAN}Common Solutions:${NC}"
    echo -e "${CYAN}  1. RBAC Propagation Delay (MOST COMMON)${NC}"
    echo -e "${GRAY}     Wait 10-15 minutes after initial failure, then retry the deployment${NC}"
    echo ""
    echo -e "${CYAN}  2. Retry Deployment${NC}"
    echo -e "${GRAY}     The second deployment attempt usually succeeds after roles have propagated${NC}"
    echo ""
    echo -e "${CYAN}  3. Check Azure Portal${NC}"
    echo -e "${GRAY}     Resource Group -> Deployments -> (select failed deployment) -> Operation details${NC}"
    echo ""

    write_section_header "Diagnostics Complete"
}

# Run main function
main
