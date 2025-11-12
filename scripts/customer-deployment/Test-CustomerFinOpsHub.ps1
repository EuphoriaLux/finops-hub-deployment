<#
.SYNOPSIS
    Validates FinOps Hub deployment and configuration.

.DESCRIPTION
    Comprehensive validation script that checks all aspects of FinOps Hub deployment
    including resources, permissions, exports, data flow, and connectivity.

.PARAMETER ConfigFile
    Path to the customer configuration JSON file.

.PARAMETER ResourceGroupName
    Name of the resource group containing FinOps Hub resources.

.PARAMETER ExportResultsToFile
    If specified, exports validation results to a JSON file.

.EXAMPLE
    .\Test-CustomerFinOpsHub.ps1 -ConfigFile ".\customer-config.json" -Verbose

.EXAMPLE
    .\Test-CustomerFinOpsHub.ps1 -ResourceGroupName "rg-finops-hub-contoso-prod" -ExportResultsToFile

.NOTES
    Author: FinOps Team
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile,

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [switch]$ExportResultsToFile
)

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

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

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-ResourceExists {
    param(
        [string]$ResourceGroupName,
        [string]$ResourceName,
        [string]$ResourceType
    )

    try {
        $resource = Get-AzResource `
            -ResourceGroupName $ResourceGroupName `
            -Name $ResourceName `
            -ResourceType $ResourceType `
            -ErrorAction SilentlyContinue

        return [PSCustomObject]@{
            Check = "$ResourceType : $ResourceName"
            Status = if ($resource) { "✓ Pass" } else { "✗ Fail" }
            Details = if ($resource) { "Exists" } else { "Not found" }
            Success = ($null -ne $resource)
        }
    } catch {
        return [PSCustomObject]@{
            Check = "$ResourceType : $ResourceName"
            Status = "✗ Fail"
            Details = $_.Exception.Message
            Success = $false
        }
    }
}

#endregion

#region Main Validation

Write-Log "============================================" -Level Info
Write-Log "  FinOps Hub Validation                     " -Level Info
Write-Log "============================================" -Level Info
Write-Log ""

$validationResults = @()

# Load configuration
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    $config = Get-Content -Path $ConfigFile | ConvertFrom-Json
    $ResourceGroupName = "rg-finops-hub-$($config.customerName)-$($config.environment)"
    Write-Log "Configuration loaded from: $ConfigFile" -Level Success
} elseif ($ResourceGroupName) {
    Write-Log "Using resource group: $ResourceGroupName" -Level Info
    $config = $null
} else {
    Write-Log "Either ConfigFile or ResourceGroupName must be provided" -Level Error
    exit 1
}

# Check Azure connection
try {
    $context = Get-AzContext -ErrorAction Stop
    Write-Log "Connected to tenant: $($context.Tenant.Id)" -Level Success
    Write-Log ""
} catch {
    Write-Log "Not connected to Azure. Run Connect-AzAccount first." -Level Error
    exit 1
}

# 1. Validate Resource Group
Write-Log "Validating Resource Group..." -Level Info
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
$validationResults += [PSCustomObject]@{
    Check = "Resource Group"
    Status = if ($rg) { "✓ Pass" } else { "✗ Fail" }
    Details = if ($rg) { $rg.Location } else { "Not found" }
    Success = ($null -ne $rg)
}

if (-not $rg) {
    Write-Log "Resource group not found. Cannot continue validation." -Level Error
    exit 1
}

# 2. Validate Storage Account
Write-Log "Validating Storage Account..." -Level Info
$storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName
$hubStorage = $storageAccounts | Where-Object { $_.StorageAccountName -like "*finopshub*" } | Select-Object -First 1

$validationResults += [PSCustomObject]@{
    Check = "Storage Account"
    Status = if ($hubStorage) { "✓ Pass" } else { "✗ Fail" }
    Details = if ($hubStorage) { $hubStorage.StorageAccountName } else { "Not found" }
    Success = ($null -ne $hubStorage)
}

if ($hubStorage) {
    # Check hierarchical namespace
    $validationResults += [PSCustomObject]@{
        Check = "Hierarchical Namespace"
        Status = if ($hubStorage.EnableHierarchicalNamespace) { "✓ Pass" } else { "✗ Fail" }
        Details = $hubStorage.EnableHierarchicalNamespace
        Success = $hubStorage.EnableHierarchicalNamespace
    }

    # Check containers
    $ctx = $hubStorage.Context
    $containers = Get-AzStorageContainer -Context $ctx
    $expectedContainers = @("msexports", "ingestion", "config")

    foreach ($containerName in $expectedContainers) {
        $exists = $containers | Where-Object { $_.Name -eq $containerName }
        $validationResults += [PSCustomObject]@{
            Check = "Container: $containerName"
            Status = if ($exists) { "✓ Pass" } else { "✗ Fail" }
            Details = if ($exists) { "Exists" } else { "Not found" }
            Success = ($null -ne $exists)
        }
    }
}

# 3. Validate Data Factory
Write-Log "Validating Data Factory..." -Level Info
$dataFactories = Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName
$hubAdf = $dataFactories | Where-Object { $_.DataFactoryName -like "*finops-hub*" } | Select-Object -First 1

$validationResults += [PSCustomObject]@{
    Check = "Data Factory"
    Status = if ($hubAdf) { "✓ Pass" } else { "✗ Fail" }
    Details = if ($hubAdf) { $hubAdf.DataFactoryName } else { "Not found" }
    Success = ($null -ne $hubAdf)
}

if ($hubAdf) {
    # Check managed identity
    $validationResults += [PSCustomObject]@{
        Check = "Data Factory Managed Identity"
        Status = if ($hubAdf.Identity.PrincipalId) { "✓ Pass" } else { "✗ Fail" }
        Details = $hubAdf.Identity.PrincipalId
        Success = ($null -ne $hubAdf.Identity.PrincipalId)
    }

    # Check pipelines
    $pipelines = Get-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $hubAdf.DataFactoryName
    $expectedPipelines = @("msexports_ETL_ingestion")

    foreach ($pipelineName in $expectedPipelines) {
        $exists = $pipelines | Where-Object { $_.Name -eq $pipelineName }
        $validationResults += [PSCustomObject]@{
            Check = "Pipeline: $pipelineName"
            Status = if ($exists) { "✓ Pass" } else { "⚠ Warning" }
            Details = if ($exists) { "Configured" } else { "Not found (may be custom deployment)" }
            Success = $true  # Non-critical
        }
    }
}

# 4. Validate Data Explorer (if configured)
if ($config -and $config.deploymentOptions.includeDataExplorer) {
    Write-Log "Validating Data Explorer..." -Level Info
    $adxClusters = Get-AzKustoCluster -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    $hubAdx = $adxClusters | Where-Object { $_.Name -like "*finopshub*" } | Select-Object -First 1

    $validationResults += [PSCustomObject]@{
        Check = "Data Explorer Cluster"
        Status = if ($hubAdx) { "✓ Pass" } else { "✗ Fail" }
        Details = if ($hubAdx) { $hubAdx.Uri } else { "Not found" }
        Success = ($null -ne $hubAdx)
    }

    if ($hubAdx) {
        # Check databases
        $databases = Get-AzKustoDatabase -ResourceGroupName $ResourceGroupName -ClusterName $hubAdx.Name
        $expectedDatabases = @("Ingestion", "Hub")

        foreach ($dbName in $expectedDatabases) {
            $exists = $databases | Where-Object { $_.Name -eq $dbName }
            $validationResults += [PSCustomObject]@{
                Check = "Database: $dbName"
                Status = if ($exists) { "✓ Pass" } else { "✗ Fail" }
                Details = if ($exists) { "Created" } else { "Not found" }
                Success = ($null -ne $exists)
            }
        }
    }
}

# 5. Validate Exports
if ($config -and $config.subscriptionIdsToMonitor) {
    Write-Log "Validating Cost Management Exports..." -Level Info

    foreach ($subId in $config.subscriptionIdsToMonitor) {
        try {
            Set-AzContext -SubscriptionId $subId -ErrorAction Stop | Out-Null
            $exports = Get-AzCostManagementExport -Scope "/subscriptions/$subId" -ErrorAction SilentlyContinue
            $hubExport = $exports | Where-Object { $_.Name -like "*FinOpsHub*" }

            $validationResults += [PSCustomObject]@{
                Check = "Export for Subscription: $subId"
                Status = if ($hubExport) { "✓ Pass" } else { "⚠ Warning" }
                Details = if ($hubExport) { $hubExport.Name } else { "Not configured" }
                Success = $true  # Non-critical for validation
            }
        } catch {
            $validationResults += [PSCustomObject]@{
                Check = "Export for Subscription: $subId"
                Status = "✗ Fail"
                Details = "Access denied or subscription not found"
                Success = $false
            }
        }
    }
}

# 6. Validate Permissions
if ($hubAdf -and $hubStorage) {
    Write-Log "Validating Permissions..." -Level Info

    $miPrincipalId = $hubAdf.Identity.PrincipalId
    $roleAssignments = Get-AzRoleAssignment -Scope $hubStorage.Id -ObjectId $miPrincipalId

    $hasStorageRole = $roleAssignments | Where-Object {
        $_.RoleDefinitionName -eq "Storage Blob Data Contributor"
    }

    $validationResults += [PSCustomObject]@{
        Check = "Data Factory Storage Permissions"
        Status = if ($hasStorageRole) { "✓ Pass" } else { "✗ Fail" }
        Details = if ($hasStorageRole) { "Storage Blob Data Contributor assigned" } else { "Missing permissions" }
        Success = ($null -ne $hasStorageRole)
    }
}

# Display results
Write-Log "`n============================================" -Level Info
Write-Log "  Validation Results                         " -Level Info
Write-Log "============================================" -Level Info
Write-Log ""

$validationResults | Format-Table Check, Status, Details -AutoSize

# Summary
$passed = ($validationResults | Where-Object { $_.Status -like "*Pass*" }).Count
$warnings = ($validationResults | Where-Object { $_.Status -like "*Warning*" }).Count
$failed = ($validationResults | Where-Object { $_.Status -like "*Fail*" }).Count
$total = $validationResults.Count

Write-Log "`n=== Summary ===" -Level Info
Write-Log "Total Checks: $total" -Level Info
Write-Log "Passed: $passed" -Level Success
Write-Log "Warnings: $warnings" -Level Warning
Write-Log "Failed: $failed" -Level $(if ($failed -gt 0) { "Error" } else { "Info" })

# Export results
if ($ExportResultsToFile) {
    $resultsPath = ".\validation-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $validationResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsPath
    Write-Log "`nResults exported to: $resultsPath" -Level Info
}

# Final status
if ($failed -eq 0) {
    Write-Log "`n✓ All critical validation checks passed!" -Level Success
    exit 0
} else {
    Write-Log "`n✗ Some validation checks failed." -Level Error
    Write-Log "Please review the failures above and resolve before proceeding." -Level Warning
    exit 1
}

#endregion
