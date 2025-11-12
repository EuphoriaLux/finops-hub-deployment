# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.SYNOPSIS
    Diagnoses FinOps Hub deployment failures, especially uploadSettings script failures.

.DESCRIPTION
    This script performs comprehensive diagnostics for FinOps Hub deployment failures.
    It checks:
    - User permissions (Contributor + User Access Administrator)
    - Managed identity creation and role assignments
    - Storage account accessibility
    - RBAC propagation status
    - Deployment script logs and status
    - Network connectivity

.PARAMETER ResourceGroupName
    Name of the resource group where FinOps Hub is deployed

.PARAMETER StorageAccountName
    Name of the FinOps Hub storage account (optional - will auto-detect if not provided)

.PARAMETER SubscriptionId
    Azure subscription ID (optional - will use current subscription if not provided)

.EXAMPLE
    .\diagnose-deployment-failure.ps1 -ResourceGroupName "finhub-rg"

.EXAMPLE
    .\diagnose-deployment-failure.ps1 -ResourceGroupName "finhub-rg" -StorageAccountName "finopshubstorage"

.NOTES
    Requires Azure PowerShell module (Az.Accounts, Az.Storage, Az.Resources)
    User must be authenticated to Azure (Connect-AzAccount)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Resource group name where FinOps Hub is deployed")]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false, HelpMessage="Storage account name (auto-detected if not provided)")]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$false, HelpMessage="Subscription ID (uses current subscription if not provided)")]
    [string]$SubscriptionId
)

#region Helper Functions

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Failure {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

#endregion

#region Main Script

try {
    Write-SectionHeader "FinOps Hub Deployment Diagnostics"

    # Check if Az module is installed
    Write-Info "Checking Azure PowerShell module..."
    $azModule = Get-Module -ListAvailable -Name Az.Accounts
    if (-not $azModule) {
        Write-Failure "Azure PowerShell module (Az) is not installed"
        Write-Info "Install with: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
        exit 1
    }
    Write-Success "Azure PowerShell module is installed"

    # Check if user is authenticated
    Write-Info "Checking Azure authentication..."
    $context = Get-AzContext
    if (-not $context) {
        Write-Failure "Not authenticated to Azure"
        Write-Info "Run: Connect-AzAccount"
        exit 1
    }
    Write-Success "Authenticated as: $($context.Account.Id)"

    # Set subscription if provided
    if ($SubscriptionId) {
        Write-Info "Switching to subscription: $SubscriptionId"
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }

    $currentSubscription = (Get-AzContext).Subscription
    Write-Info "Using subscription: $($currentSubscription.Name) ($($currentSubscription.Id))"

    # Check if resource group exists
    Write-SectionHeader "Resource Group Validation"
    Write-Info "Checking resource group: $ResourceGroupName"
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Failure "Resource group '$ResourceGroupName' not found"
        exit 1
    }
    Write-Success "Resource group found: $($rg.Location)"

    # Auto-detect storage account if not provided
    if (-not $StorageAccountName) {
        Write-Info "Auto-detecting storage account..."
        $storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($storageAccounts.Count -eq 0) {
            Write-Failure "No storage accounts found in resource group"
            exit 1
        }
        if ($storageAccounts.Count -gt 1) {
            Write-Warning "Multiple storage accounts found. Using first one: $($storageAccounts[0].StorageAccountName)"
            Write-Info "Specify -StorageAccountName parameter to target a specific account"
        }
        $StorageAccountName = $storageAccounts[0].StorageAccountName
    }
    Write-Success "Using storage account: $StorageAccountName"

    # Check user permissions
    Write-SectionHeader "User Permissions Check"
    $userId = $context.Account.Id
    Write-Info "Checking permissions for: $userId"

    $rgId = $rg.ResourceId
    $roleAssignments = Get-AzRoleAssignment -Scope $rgId -SignInName $userId -ErrorAction SilentlyContinue

    $hasContributor = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "Contributor" -or $_.RoleDefinitionName -eq "Owner" }
    $hasUserAccessAdmin = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "User Access Administrator" -or $_.RoleDefinitionName -eq "Owner" }

    if ($hasContributor) {
        Write-Success "Has Contributor (or Owner) role"
    } else {
        Write-Failure "Missing Contributor role"
        Write-Info "You need Contributor or Owner role to deploy resources"
    }

    if ($hasUserAccessAdmin) {
        Write-Success "Has User Access Administrator (or Owner) role"
    } else {
        Write-Failure "Missing User Access Administrator role"
        Write-Info "You need User Access Administrator or Owner role to assign roles to managed identities"
    }

    # Check storage account
    Write-SectionHeader "Storage Account Check"
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if (-not $storageAccount) {
        Write-Failure "Storage account '$StorageAccountName' not found"
        exit 1
    }
    Write-Success "Storage account exists"
    Write-Info "  SKU: $($storageAccount.Sku.Name)"
    Write-Info "  Location: $($storageAccount.Location)"
    Write-Info "  Provisioning State: $($storageAccount.ProvisioningState)"

    # Check if config container exists
    Write-Info "Checking for 'config' container..."
    $storageContext = $storageAccount.Context
    $configContainer = Get-AzStorageContainer -Name "config" -Context $storageContext -ErrorAction SilentlyContinue
    if ($configContainer) {
        Write-Success "Config container exists"
    } else {
        Write-Warning "Config container not found - deployment may be incomplete"
    }

    # Check managed identity
    Write-SectionHeader "Managed Identity Check"
    $identityName = "${StorageAccountName}_blobManager"
    Write-Info "Looking for managed identity: $identityName"

    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $identityName -ErrorAction SilentlyContinue
    if (-not $identity) {
        Write-Failure "Managed identity '$identityName' not found"
        Write-Info "The deployment may have failed before creating the identity"
    } else {
        Write-Success "Managed identity found"
        Write-Info "  Principal ID: $($identity.PrincipalId)"
        Write-Info "  Client ID: $($identity.ClientId)"

        # Check role assignments
        Write-Info "Checking role assignments for managed identity..."
        $storageAccountId = $storageAccount.Id
        $identityRoles = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -Scope $storageAccountId -ErrorAction SilentlyContinue

        $hasStorageBlobDataContributor = $identityRoles | Where-Object {
            $_.RoleDefinitionName -eq "Storage Blob Data Contributor"
        }
        $hasStorageAccountContributor = $identityRoles | Where-Object {
            $_.RoleDefinitionName -eq "Storage Account Contributor"
        }

        if ($hasStorageBlobDataContributor) {
            Write-Success "Has 'Storage Blob Data Contributor' role"
        } else {
            Write-Failure "Missing 'Storage Blob Data Contributor' role"
            Write-Info "This role is required to read/write blobs in the storage account"
        }

        if ($hasStorageAccountContributor) {
            Write-Success "Has 'Storage Account Contributor' role"
        } else {
            Write-Warning "Missing 'Storage Account Contributor' role (may be optional for some configurations)"
        }

        # Check RBAC propagation
        Write-Info "Testing RBAC propagation..."
        try {
            $testContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -ErrorAction Stop
            $testContainer = Get-AzStorageContainer -Name "config" -Context $testContext -ErrorAction Stop
            Write-Success "RBAC permissions are working (propagated)"
        } catch {
            if ($_.Exception.Message -like "*Authorization*" -or $_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*403*") {
                Write-Warning "RBAC permissions not yet propagated"
                Write-Info "Azure RBAC can take 5-10 minutes to propagate after role assignment"
                Write-Info "This is the MOST COMMON cause of deployment failures"
            } else {
                Write-Warning "Could not test RBAC: $($_.Exception.Message)"
            }
        }
    }

    # Check deployment scripts
    Write-SectionHeader "Deployment Scripts Check"
    Write-Info "Looking for deployment scripts in resource group..."
    $deploymentScripts = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Resources/deploymentScripts" -ErrorAction SilentlyContinue

    if ($deploymentScripts.Count -eq 0) {
        Write-Warning "No deployment scripts found"
        Write-Info "Deployment may have failed before reaching the script execution phase"
    } else {
        Write-Success "Found $($deploymentScripts.Count) deployment script(s)"

        foreach ($script in $deploymentScripts) {
            Write-Info ""
            Write-Info "Script: $($script.Name)"
            $scriptDetail = Get-AzResourcegroupDeploymentScript -ResourceGroupName $ResourceGroupName -Name $script.Name -ErrorAction SilentlyContinue

            if ($scriptDetail) {
                Write-Info "  Provisioning State: $($scriptDetail.ProvisioningState)"
                Write-Info "  Status Message: $($scriptDetail.Status.Message)"

                if ($scriptDetail.ProvisioningState -eq "Failed") {
                    Write-Failure "  Deployment script failed!"

                    # Try to get logs
                    Write-Info "  Attempting to retrieve logs..."
                    try {
                        if ($scriptDetail.Status.Error) {
                            Write-Failure "  Error Code: $($scriptDetail.Status.Error.Code)"
                            Write-Failure "  Error Message: $($scriptDetail.Status.Error.Message)"
                        }
                    } catch {
                        Write-Warning "  Could not retrieve detailed error information"
                    }
                } elseif ($scriptDetail.ProvisioningState -eq "Succeeded") {
                    Write-Success "  Deployment script succeeded"
                } else {
                    Write-Info "  Deployment script status: $($scriptDetail.ProvisioningState)"
                }
            }
        }
    }

    # Check recent deployments
    Write-SectionHeader "Recent Deployments Check"
    Write-Info "Retrieving recent deployments..."
    $deployments = Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue |
        Sort-Object Timestamp -Descending |
        Select-Object -First 10

    if ($deployments) {
        foreach ($deployment in $deployments) {
            $statusColor = switch ($deployment.ProvisioningState) {
                "Succeeded" { "Green" }
                "Failed" { "Red" }
                default { "Yellow" }
            }

            Write-Host "  $($deployment.DeploymentName)" -NoNewline
            Write-Host " - " -NoNewline
            Write-Host $deployment.ProvisioningState -ForegroundColor $statusColor -NoNewline
            Write-Host " ($($deployment.Timestamp))"

            if ($deployment.ProvisioningState -eq "Failed") {
                # Get deployment operations to find specific failure
                $operations = Get-AzResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $deployment.DeploymentName -ErrorAction SilentlyContinue
                $failedOps = $operations | Where-Object { $_.ProvisioningState -eq "Failed" }

                foreach ($op in $failedOps) {
                    Write-Failure "    Failed: $($op.TargetResource)"
                    if ($op.StatusMessage) {
                        Write-Info "    Message: $($op.StatusMessage)"
                    }
                }
            }
        }
    }

    # Network connectivity check
    Write-SectionHeader "Network Connectivity Check"
    Write-Info "Checking storage account network rules..."
    $networkRules = $storageAccount.NetworkRuleSet

    if ($networkRules.DefaultAction -eq "Deny") {
        Write-Warning "Storage account has network restrictions (DefaultAction: Deny)"
        Write-Info "  Allowed IP ranges: $($networkRules.IpRules.Count)"
        Write-Info "  Allowed virtual networks: $($networkRules.VirtualNetworkRules.Count)"
        Write-Info "  This may prevent deployment scripts from accessing storage"
    } else {
        Write-Success "Storage account allows public network access"
    }

    # Summary and recommendations
    Write-SectionHeader "Summary and Recommendations"

    $issues = @()
    $recommendations = @()

    if (-not $hasContributor -or -not $hasUserAccessAdmin) {
        $issues += "Insufficient user permissions"
        $recommendations += "Ensure deploying user has both 'Contributor' and 'User Access Administrator' roles"
    }

    if ($identity -and (-not $hasStorageBlobDataContributor)) {
        $issues += "Managed identity missing required role"
        $recommendations += "Wait 10-15 minutes for RBAC to propagate, then retry deployment"
    }

    if ($networkRules.DefaultAction -eq "Deny") {
        $issues += "Storage account has network restrictions"
        $recommendations += "Add deployment script IP range to storage account firewall, or temporarily allow public access"
    }

    if ($issues.Count -eq 0) {
        Write-Success "No obvious issues detected"
        Write-Info "If deployment is still failing, check:"
        Write-Info "  1. Azure service health for the region"
        Write-Info "  2. Subscription quotas for deployment scripts"
        Write-Info "  3. Detailed deployment logs in Azure Portal"
    } else {
        Write-Host ""
        Write-Host "Identified Issues:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "Recommendations:" -ForegroundColor Yellow
        foreach ($rec in $recommendations) {
            Write-Host "  - $rec" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Common Solutions:" -ForegroundColor Cyan
    Write-Host "  1. RBAC Propagation Delay (MOST COMMON)" -ForegroundColor Cyan
    Write-Host "     Wait 10-15 minutes after initial failure, then retry the deployment" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Retry Deployment" -ForegroundColor Cyan
    Write-Host "     The second deployment attempt usually succeeds after roles have propagated" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Check Azure Portal" -ForegroundColor Cyan
    Write-Host "     Resource Group -> Deployments -> (select failed deployment) -> Operation details" -ForegroundColor Gray
    Write-Host ""

    Write-SectionHeader "Diagnostics Complete"
}
catch {
    Write-Host ""
    Write-Failure "An error occurred during diagnostics:"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Gray
    Write-Host $_.Exception.StackTrace -ForegroundColor Gray
    exit 1
}

#endregion
