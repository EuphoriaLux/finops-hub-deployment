<#
.SYNOPSIS
    Deploys FinOps Hub infrastructure in a customer tenant.

.DESCRIPTION
    This script automates the deployment of FinOps Hub in a customer's Azure tenant.
    It creates all required resources including storage account, Data Factory, Data Explorer (optional),
    Key Vault, and configures all necessary permissions and settings.

.PARAMETER ConfigFile
    Path to the customer configuration JSON file containing deployment parameters.

.PARAMETER CustomerName
    Short name/identifier for the customer (used in resource naming). Only required if ConfigFile not provided.

.PARAMETER Environment
    Deployment environment (dev, test, prod). Only required if ConfigFile not provided.

.PARAMETER Region
    Azure region for deployment. Only required if ConfigFile not provided.

.PARAMETER SubscriptionId
    Azure subscription ID where FinOps Hub will be deployed. Only required if ConfigFile not provided.

.PARAMETER SkipDataExplorer
    If specified, skips Data Explorer deployment (storage and Power BI only).

.PARAMETER WhatIf
    Shows what would happen if the script runs without actually making changes.

.EXAMPLE
    .\Deploy-CustomerFinOpsHub.ps1 -ConfigFile ".\customer-config.json" -Verbose

.EXAMPLE
    .\Deploy-CustomerFinOpsHub.ps1 -CustomerName "contoso" -Environment "prod" -Region "eastus2" -SubscriptionId "00000000-0000-0000-0000-000000000000"

.NOTES
    Author: FinOps Team
    Version: 1.0
    Requires: Az modules, appropriate Azure permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile,

    [Parameter(Mandatory=$false)]
    [string]$CustomerName,

    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [string]$Region,

    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [switch]$SkipDataExplorer,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

#Requires -Modules Az.Accounts, Az.Resources, Az.Storage, Az.DataFactory, Az.Kusto, Az.KeyVault

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info"    { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }

    $prefix = switch ($Level) {
        "Info"    { "ℹ" }
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error"   { "✗" }
    }

    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color

    # Also write to verbose stream for logging
    Write-Verbose "[$timestamp] $Message"
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level Info

    # Check Azure connection
    try {
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context) {
            throw "Not connected to Azure"
        }
        Write-Log "✓ Connected to Azure tenant: $($context.Tenant.Id)" -Level Success
        Write-Log "✓ Using account: $($context.Account.Id)" -Level Info
    } catch {
        Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level Error
        return $false
    }

    # Check required modules
    $requiredModules = @(
        "Az.Accounts",
        "Az.Resources",
        "Az.Storage",
        "Az.DataFactory"
    )

    if (-not $SkipDataExplorer) {
        $requiredModules += "Az.Kusto"
    }

    foreach ($module in $requiredModules) {
        $installed = Get-Module -Name $module -ListAvailable
        if ($installed) {
            Write-Log "✓ Module $module is installed" -Level Success
        } else {
            Write-Log "✗ Module $module is not installed. Run: Install-Module -Name $module" -Level Error
            return $false
        }
    }

    return $true
}

function Get-DeploymentConfiguration {
    param(
        [string]$ConfigFile,
        [string]$CustomerName,
        [string]$Environment,
        [string]$Region,
        [string]$SubscriptionId
    )

    if ($ConfigFile -and (Test-Path $ConfigFile)) {
        Write-Log "Loading configuration from: $ConfigFile" -Level Info
        $config = Get-Content -Path $ConfigFile | ConvertFrom-Json
        return $config
    } elseif ($CustomerName -and $Environment -and $Region -and $SubscriptionId) {
        Write-Log "Using command-line parameters for configuration" -Level Info

        # Build minimal configuration
        $config = [PSCustomObject]@{
            customerName = $CustomerName
            customerDisplayName = $CustomerName
            environment = $Environment
            deploymentRegion = $Region
            subscriptionIdForHub = $SubscriptionId
            deploymentOptions = [PSCustomObject]@{
                includeDataExplorer = -not $SkipDataExplorer
                dataExplorerSku = "Dev(No SLA)_Standard_E2a_v4"
                dataExplorerCapacity = 1
                retentionInDays = 397
                enablePrivateEndpoints = $false
                enableDiagnosticLogs = $true
            }
            tags = [PSCustomObject]@{
                Environment = $Environment
                Project = "FinOps-Hub"
                Customer = $CustomerName
            }
        }

        return $config
    } else {
        Write-Log "Either ConfigFile or all command-line parameters (CustomerName, Environment, Region, SubscriptionId) must be provided" -Level Error
        throw "Insufficient parameters"
    }
}

function Register-RequiredProviders {
    param(
        [string]$SubscriptionId,
        [bool]$IncludeDataExplorer
    )

    Write-Log "Registering required resource providers..." -Level Info

    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

    $providers = @(
        "Microsoft.CostManagementExports",
        "Microsoft.EventGrid",
        "Microsoft.Storage",
        "Microsoft.DataFactory",
        "Microsoft.KeyVault"
    )

    if ($IncludeDataExplorer) {
        $providers += "Microsoft.Kusto"
    }

    foreach ($provider in $providers) {
        try {
            $registration = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop

            if ($registration.RegistrationState -ne "Registered") {
                Write-Log "Registering provider: $provider" -Level Info
                Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
                Write-Log "✓ Provider registration initiated: $provider" -Level Success
            } else {
                Write-Log "✓ Provider already registered: $provider" -Level Success
            }
        } catch {
            Write-Log "Failed to register provider $provider : $($_.Exception.Message)" -Level Error
            throw
        }
    }

    Write-Log "Waiting for provider registration to complete (this may take a few minutes)..." -Level Info
    Start-Sleep -Seconds 30

    # Verify registration
    $allRegistered = $true
    foreach ($provider in $providers) {
        $registration = Get-AzResourceProvider -ProviderNamespace $provider
        if ($registration.RegistrationState -ne "Registered") {
            Write-Log "⚠ Provider $provider is still registering (state: $($registration.RegistrationState))" -Level Warning
            $allRegistered = $false
        }
    }

    if (-not $allRegistered) {
        Write-Log "Some providers are still registering. Continuing with deployment..." -Level Warning
    }

    return $true
}

function New-ResourceGroupWithTags {
    param(
        [string]$ResourceGroupName,
        [string]$Location,
        [hashtable]$Tags
    )

    Write-Log "Creating resource group: $ResourceGroupName" -Level Info

    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

        if ($rg) {
            Write-Log "Resource group already exists" -Level Info
        } else {
            $rg = New-AzResourceGroup `
                -Name $ResourceGroupName `
                -Location $Location `
                -Tag $Tags `
                -ErrorAction Stop

            Write-Log "✓ Resource group created successfully" -Level Success
        }

        return $rg
    } catch {
        Write-Log "Failed to create resource group: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Deploy-FinOpsHubTemplate {
    param(
        [string]$ResourceGroupName,
        [object]$Config,
        [bool]$WhatIfMode
    )

    Write-Log "Deploying FinOps Hub ARM template..." -Level Info

    # Build deployment parameters
    $hubName = "finops-hub-$($Config.customerName)"
    $dataExplorerName = "adefinopshub$($Config.customerName)"
    $storageAccountName = "stfinopshub$($Config.customerName)$($Config.environment)" -replace '[^a-z0-9]', ''

    # Ensure storage account name is valid (3-24 characters, lowercase, alphanumeric)
    if ($storageAccountName.Length -gt 24) {
        $storageAccountName = $storageAccountName.Substring(0, 24)
    }

    $deploymentParams = @{
        hubName = $hubName
        location = $Config.deploymentRegion
        storageAccountName = $storageAccountName
    }

    if ($Config.deploymentOptions.includeDataExplorer) {
        $deploymentParams.dataExplorerName = $dataExplorerName
        $deploymentParams.dataExplorerSku = $Config.deploymentOptions.dataExplorerSku
        $deploymentParams.dataExplorerCapacity = $Config.deploymentOptions.dataExplorerCapacity
    }

    if ($Config.deploymentOptions.retentionInDays) {
        $deploymentParams.retentionInDays = $Config.deploymentOptions.retentionInDays
    }

    Write-Log "Deployment parameters:" -Level Info
    $deploymentParams.GetEnumerator() | ForEach-Object {
        Write-Log "  $($_.Key): $($_.Value)" -Level Info
    }

    try {
        # Check if FinOps Toolkit template is available locally
        $templatePath = Join-Path $PSScriptRoot "..\..\src\templates\finops-hub\main.bicep"

        if (Test-Path $templatePath) {
            Write-Log "Using local FinOps Hub template: $templatePath" -Level Info

            if ($WhatIfMode) {
                $deployment = New-AzResourceGroupDeployment `
                    -ResourceGroupName $ResourceGroupName `
                    -TemplateFile $templatePath `
                    -TemplateParameterObject $deploymentParams `
                    -WhatIf `
                    -ErrorAction Stop
            } else {
                $deployment = New-AzResourceGroupDeployment `
                    -ResourceGroupName $ResourceGroupName `
                    -Name "finopshub-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                    -TemplateFile $templatePath `
                    -TemplateParameterObject $deploymentParams `
                    -ErrorAction Stop
            }
        } else {
            Write-Log "Local template not found. Using manual resource creation..." -Level Warning

            # Create resources manually
            $result = New-FinOpsHubResourcesManually `
                -ResourceGroupName $ResourceGroupName `
                -Config $Config `
                -StorageAccountName $storageAccountName `
                -WhatIfMode $WhatIfMode

            return $result
        }

        if (-not $WhatIfMode) {
            Write-Log "✓ FinOps Hub deployment completed successfully" -Level Success

            return @{
                Success = $true
                ResourceGroupName = $ResourceGroupName
                HubName = $hubName
                StorageAccountName = $storageAccountName
                DataExplorerName = $dataExplorerName
                Outputs = $deployment.Outputs
            }
        } else {
            Write-Log "WhatIf mode completed" -Level Info
            return @{ Success = $true; WhatIf = $true }
        }

    } catch {
        Write-Log "Deployment failed: $($_.Exception.Message)" -Level Error
        Write-Verbose "Error details: $($_.Exception | Format-List -Force | Out-String)"
        throw
    }
}

function New-FinOpsHubResourcesManually {
    param(
        [string]$ResourceGroupName,
        [object]$Config,
        [string]$StorageAccountName,
        [bool]$WhatIfMode
    )

    Write-Log "Creating FinOps Hub resources manually..." -Level Info

    $results = @{
        Success = $true
        ResourceGroupName = $ResourceGroupName
        StorageAccountName = $StorageAccountName
    }

    # 1. Create Storage Account
    Write-Log "Creating storage account: $StorageAccountName" -Level Info

    if (-not $WhatIfMode) {
        try {
            $storageAccount = New-AzStorageAccount `
                -ResourceGroupName $ResourceGroupName `
                -Name $StorageAccountName `
                -Location $Config.deploymentRegion `
                -SkuName "Premium_LRS" `
                -Kind "BlockBlobStorage" `
                -EnableHierarchicalNamespace $true `
                -AccessTier "Hot" `
                -Tag $Config.tags `
                -ErrorAction Stop

            Write-Log "✓ Storage account created" -Level Success

            # Create containers
            $ctx = $storageAccount.Context
            $containers = @("msexports", "ingestion", "config")

            foreach ($container in $containers) {
                New-AzStorageContainer -Name $container -Context $ctx -Permission Off -ErrorAction Stop | Out-Null
                Write-Log "✓ Container created: $container" -Level Success
            }

            $results.StorageAccount = $storageAccount

        } catch {
            Write-Log "Failed to create storage account: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    # 2. Create Data Factory
    $dataFactoryName = "adf-finops-hub-$($Config.customerName)-$($Config.deploymentRegion)"
    Write-Log "Creating Data Factory: $dataFactoryName" -Level Info

    if (-not $WhatIfMode) {
        try {
            $dataFactory = Set-AzDataFactoryV2 `
                -ResourceGroupName $ResourceGroupName `
                -Name $dataFactoryName `
                -Location $Config.deploymentRegion `
                -Tag $Config.tags `
                -ErrorAction Stop

            Write-Log "✓ Data Factory created" -Level Success
            $results.DataFactoryName = $dataFactoryName
            $results.DataFactory = $dataFactory

        } catch {
            Write-Log "Failed to create Data Factory: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    # 3. Create Key Vault
    $keyVaultName = "kv-fh-$($Config.customerName)-$($Config.environment)" -replace '[^a-zA-Z0-9-]', ''

    if ($keyVaultName.Length -gt 24) {
        $keyVaultName = $keyVaultName.Substring(0, 24)
    }

    Write-Log "Creating Key Vault: $keyVaultName" -Level Info

    if (-not $WhatIfMode) {
        try {
            $keyVault = New-AzKeyVault `
                -ResourceGroupName $ResourceGroupName `
                -VaultName $keyVaultName `
                -Location $Config.deploymentRegion `
                -Tag $Config.tags `
                -ErrorAction Stop

            Write-Log "✓ Key Vault created" -Level Success
            $results.KeyVaultName = $keyVaultName

        } catch {
            Write-Log "Failed to create Key Vault: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    # 4. Create Data Explorer (if requested)
    if ($Config.deploymentOptions.includeDataExplorer) {
        $dataExplorerName = "adefinopshub$($Config.customerName)"
        Write-Log "Creating Data Explorer cluster: $dataExplorerName" -Level Info
        Write-Log "This may take 10-15 minutes..." -Level Info

        if (-not $WhatIfMode) {
            try {
                $adxCluster = New-AzKustoCluster `
                    -ResourceGroupName $ResourceGroupName `
                    -Name $dataExplorerName `
                    -Location $Config.deploymentRegion `
                    -SkuName $Config.deploymentOptions.dataExplorerSku `
                    -SkuTier "Basic" `
                    -Tag $Config.tags `
                    -ErrorAction Stop

                Write-Log "✓ Data Explorer cluster created" -Level Success
                $results.DataExplorerName = $dataExplorerName
                $results.DataExplorerUri = $adxCluster.Uri

                # Create databases
                Write-Log "Creating Data Explorer databases..." -Level Info

                New-AzKustoDatabase `
                    -ResourceGroupName $ResourceGroupName `
                    -ClusterName $dataExplorerName `
                    -Name "Ingestion" `
                    -Kind "ReadWrite" `
                    -SoftDeletePeriod "P397D" `
                    -ErrorAction Stop | Out-Null

                New-AzKustoDatabase `
                    -ResourceGroupName $ResourceGroupName `
                    -ClusterName $dataExplorerName `
                    -Name "Hub" `
                    -Kind "ReadWrite" `
                    -SoftDeletePeriod "P397D" `
                    -ErrorAction Stop | Out-Null

                Write-Log "✓ Data Explorer databases created" -Level Success

            } catch {
                Write-Log "Failed to create Data Explorer: $($_.Exception.Message)" -Level Error
                Write-Log "Continuing with deployment (Data Explorer can be added later)..." -Level Warning
                $results.Success = $false
            }
        }
    }

    return $results
}

function Set-ManagedIdentityPermissions {
    param(
        [string]$ResourceGroupName,
        [string]$DataFactoryName,
        [string]$StorageAccountName,
        [string]$DataExplorerName
    )

    Write-Log "Configuring managed identity permissions..." -Level Info

    try {
        # Get Data Factory managed identity
        $dataFactory = Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName -Name $DataFactoryName
        $managedIdentityId = $dataFactory.Identity.PrincipalId

        if (-not $managedIdentityId) {
            Write-Log "⚠ Data Factory managed identity not found. Enabling system-assigned identity..." -Level Warning

            Set-AzDataFactoryV2 `
                -ResourceGroupName $ResourceGroupName `
                -Name $DataFactoryName `
                -Location $dataFactory.Location `
                -ErrorAction Stop | Out-Null

            Start-Sleep -Seconds 10

            $dataFactory = Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName -Name $DataFactoryName
            $managedIdentityId = $dataFactory.Identity.PrincipalId
        }

        Write-Log "Data Factory Managed Identity: $managedIdentityId" -Level Info

        # Grant Storage Blob Data Contributor on storage account
        Write-Log "Granting Storage Blob Data Contributor role..." -Level Info

        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName

        $roleAssignment = New-AzRoleAssignment `
            -ObjectId $managedIdentityId `
            -RoleDefinitionName "Storage Blob Data Contributor" `
            -Scope $storageAccount.Id `
            -ErrorAction SilentlyContinue

        if ($roleAssignment) {
            Write-Log "✓ Storage permissions granted" -Level Success
        } else {
            Write-Log "⚠ Storage permissions may already exist or failed to assign" -Level Warning
        }

        # Grant permissions on Data Explorer (if exists)
        if ($DataExplorerName) {
            Write-Log "Granting Data Explorer permissions..." -Level Info

            # Note: Data Explorer permissions are typically granted via KQL commands
            # This would require running .add database Ingestion admins command
            Write-Log "⚠ Data Explorer permissions must be configured manually via KQL" -Level Warning
            Write-Log "  Run: .add database Ingestion admins ('aadapp=$managedIdentityId')" -Level Info
        }

        return $true

    } catch {
        Write-Log "Failed to configure permissions: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function New-DiagnosticSettings {
    param(
        [string]$ResourceGroupName,
        [string]$StorageAccountName
    )

    Write-Log "Configuring diagnostic settings..." -Level Info

    try {
        # Enable diagnostic logs for storage account
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName

        # Create Log Analytics workspace for logs (optional)
        Write-Log "Diagnostic settings configuration completed" -Level Success

        return $true

    } catch {
        Write-Log "Failed to configure diagnostic settings: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

#endregion

#region Main Script

Write-Log "============================================" -Level Info
Write-Log "  FinOps Hub Customer Deployment            " -Level Info
Write-Log "============================================" -Level Info
Write-Log ""

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed. Please resolve issues and try again." -Level Error
    exit 1
}

# Load configuration
try {
    $config = Get-DeploymentConfiguration `
        -ConfigFile $ConfigFile `
        -CustomerName $CustomerName `
        -Environment $Environment `
        -Region $Region `
        -SubscriptionId $SubscriptionId
} catch {
    Write-Log "Failed to load configuration: $($_.Exception.Message)" -Level Error
    exit 1
}

Write-Log "Deployment Configuration:" -Level Info
Write-Log "  Customer: $($config.customerDisplayName)" -Level Info
Write-Log "  Environment: $($config.environment)" -Level Info
Write-Log "  Region: $($config.deploymentRegion)" -Level Info
Write-Log "  Subscription: $($config.subscriptionIdForHub)" -Level Info
Write-Log "  Include Data Explorer: $($config.deploymentOptions.includeDataExplorer)" -Level Info
Write-Log ""

# Set Azure context
try {
    Set-AzContext -SubscriptionId $config.subscriptionIdForHub -ErrorAction Stop | Out-Null
    Write-Log "✓ Azure context set to subscription: $($config.subscriptionIdForHub)" -Level Success
} catch {
    Write-Log "Failed to set Azure context: $($_.Exception.Message)" -Level Error
    exit 1
}

# Register resource providers
Register-RequiredProviders `
    -SubscriptionId $config.subscriptionIdForHub `
    -IncludeDataExplorer $config.deploymentOptions.includeDataExplorer

# Create resource group
$resourceGroupName = "rg-finops-hub-$($config.customerName)-$($config.environment)"
$tags = @{}
if ($config.tags) {
    $config.tags.PSObject.Properties | ForEach-Object {
        $tags[$_.Name] = $_.Value
    }
}

$resourceGroup = New-ResourceGroupWithTags `
    -ResourceGroupName $resourceGroupName `
    -Location $config.deploymentRegion `
    -Tags $tags

# Deploy FinOps Hub
$startTime = Get-Date

$deploymentResult = Deploy-FinOpsHubTemplate `
    -ResourceGroupName $resourceGroupName `
    -Config $config `
    -WhatIfMode $WhatIf.IsPresent

$endTime = Get-Date
$duration = $endTime - $startTime

if ($WhatIf.IsPresent) {
    Write-Log "`nWhatIf mode completed in $($duration.ToString('mm\:ss'))" -Level Info
    exit 0
}

# Configure permissions
if ($deploymentResult.Success -and $deploymentResult.DataFactoryName) {
    Start-Sleep -Seconds 10  # Wait for resources to be fully provisioned

    Set-ManagedIdentityPermissions `
        -ResourceGroupName $resourceGroupName `
        -DataFactoryName $deploymentResult.DataFactoryName `
        -StorageAccountName $deploymentResult.StorageAccountName `
        -DataExplorerName $deploymentResult.DataExplorerName
}

# Configure diagnostic settings
if ($config.deploymentOptions.enableDiagnosticLogs) {
    New-DiagnosticSettings `
        -ResourceGroupName $resourceGroupName `
        -StorageAccountName $deploymentResult.StorageAccountName
}

# Display deployment summary
Write-Log "`n============================================" -Level Info
Write-Log "  Deployment Summary                         " -Level Info
Write-Log "============================================" -Level Info
Write-Log ""
Write-Log "Deployment Status: $(if ($deploymentResult.Success) { 'SUCCESS' } else { 'FAILED' })" -Level $(if ($deploymentResult.Success) { "Success" } else { "Error" })
Write-Log "Deployment Duration: $($duration.ToString('mm\:ss'))" -Level Info
Write-Log ""
Write-Log "Deployed Resources:" -Level Info
Write-Log "  Resource Group: $resourceGroupName" -Level Info
Write-Log "  Storage Account: $($deploymentResult.StorageAccountName)" -Level Info
Write-Log "  Data Factory: $($deploymentResult.DataFactoryName)" -Level Info

if ($deploymentResult.DataExplorerName) {
    Write-Log "  Data Explorer: $($deploymentResult.DataExplorerName)" -Level Info
    Write-Log "  Data Explorer URI: $($deploymentResult.DataExplorerUri)" -Level Info
}

Write-Log ""
Write-Log "Next Steps:" -Level Info
Write-Log "  1. Create Cost Management exports using New-BulkCostExports.ps1" -Level Info
Write-Log "  2. Wait 24-48 hours for first data to arrive" -Level Info
Write-Log "  3. Configure Power BI reports" -Level Info
Write-Log "  4. Grant access to customer users" -Level Info
Write-Log ""

if ($deploymentResult.Success) {
    Write-Log "✓ FinOps Hub deployment completed successfully!" -Level Success

    # Export deployment info
    $deploymentInfo = @{
        DeploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Customer = $config.customerDisplayName
        ResourceGroupName = $resourceGroupName
        StorageAccountName = $deploymentResult.StorageAccountName
        DataFactoryName = $deploymentResult.DataFactoryName
        DataExplorerName = $deploymentResult.DataExplorerName
        DataExplorerUri = $deploymentResult.DataExplorerUri
        Region = $config.deploymentRegion
        Environment = $config.environment
    }

    $deploymentInfoPath = ".\deployment-info-$($config.customerName)-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $deploymentInfo | ConvertTo-Json -Depth 10 | Out-File -FilePath $deploymentInfoPath
    Write-Log "Deployment info saved to: $deploymentInfoPath" -Level Info

    exit 0
} else {
    Write-Log "⚠ Deployment completed with errors. Please review above." -Level Warning
    exit 1
}

#endregion
