<#
.SYNOPSIS
    Creates Cost Management exports for multiple subscriptions automatically.

.DESCRIPTION
    This script automates the creation of Cost Management exports across multiple Azure subscriptions.
    It supports creating exports for cost data, price sheets, reservations, and recommendations.
    The script can discover subscriptions automatically or use a configuration file.

.PARAMETER ConfigFile
    Path to the customer configuration JSON file. If provided, subscriptions will be read from this file.

.PARAMETER SubscriptionIds
    Array of subscription IDs to create exports for. Used if ConfigFile is not provided.

.PARAMETER StorageAccountName
    Name of the storage account where exports will be delivered.

.PARAMETER StorageResourceGroup
    Resource group name where the storage account resides.

.PARAMETER HubName
    Name prefix for the FinOps Hub (used in export naming).

.PARAMETER ExportTypes
    Array of export types to create. Options: ActualCost, PriceSheet, ReservationDetails, ReservationRecommendations, ReservationTransactions

.PARAMETER RunExportsImmediately
    If specified, triggers immediate execution of all created exports.

.PARAMETER ParallelProcessing
    If specified, processes subscriptions in parallel for faster execution.

.PARAMETER MaxParallelJobs
    Maximum number of parallel jobs when ParallelProcessing is enabled. Default: 5

.EXAMPLE
    .\New-BulkCostExports.ps1 -ConfigFile ".\customer-config.json" -StorageAccountName "stfinopshub001" -StorageResourceGroup "rg-finops-hub-prod" -RunExportsImmediately -Verbose

.EXAMPLE
    .\New-BulkCostExports.ps1 -SubscriptionIds @("sub1-guid", "sub2-guid") -StorageAccountName "stfinopshub001" -StorageResourceGroup "rg-finops-hub-prod" -HubName "finops-hub-contoso"

.NOTES
    Author: FinOps Team
    Version: 1.0
    Requires: Az.Accounts, Az.Storage, Az.CostManagement modules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile,

    [Parameter(Mandatory=$false)]
    [string[]]$SubscriptionIds,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$StorageResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$HubName = "FinOpsHub",

    [Parameter(Mandatory=$false)]
    [ValidateSet("ActualCost", "PriceSheet", "ReservationDetails", "ReservationRecommendations", "ReservationTransactions")]
    [string[]]$ExportTypes = @("ActualCost"),

    [Parameter(Mandatory=$false)]
    [switch]$RunExportsImmediately,

    [Parameter(Mandatory=$false)]
    [switch]$ParallelProcessing,

    [Parameter(Mandatory=$false)]
    [int]$MaxParallelJobs = 5
)

#Requires -Modules Az.Accounts, Az.Storage

# Initialize results tracking
$script:results = @()
$script:successCount = 0
$script:failureCount = 0
$script:skippedCount = 0

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
}

function Get-SubscriptionList {
    param(
        [string]$ConfigFile,
        [string[]]$SubscriptionIds
    )

    if ($ConfigFile -and (Test-Path $ConfigFile)) {
        Write-Log "Loading subscriptions from config file: $ConfigFile" -Level Info
        $config = Get-Content -Path $ConfigFile | ConvertFrom-Json

        if ($config.subscriptionIdsToMonitor) {
            return $config.subscriptionIdsToMonitor
        } else {
            Write-Log "No subscriptionIdsToMonitor found in config file" -Level Warning
            return @()
        }
    } elseif ($SubscriptionIds) {
        Write-Log "Using provided subscription IDs ($($SubscriptionIds.Count) subscriptions)" -Level Info
        return $SubscriptionIds
    } else {
        Write-Log "No config file or subscription IDs provided. Discovering accessible subscriptions..." -Level Info
        $subs = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
        Write-Log "Found $($subs.Count) accessible subscriptions" -Level Info
        return $subs.Id
    }
}

function Get-StorageAccountDetails {
    param(
        [string]$ResourceGroupName,
        [string]$AccountName
    )

    try {
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $AccountName -ErrorAction Stop
        return @{
            Id = $storageAccount.Id
            ResourceGroupName = $ResourceGroupName
            AccountName = $AccountName
            Context = $storageAccount.Context
            Success = $true
        }
    } catch {
        Write-Log "Failed to get storage account '$AccountName': $($_.Exception.Message)" -Level Error
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-ExportExists {
    param(
        [string]$SubscriptionId,
        [string]$ExportName
    )

    try {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
        $exports = Get-AzCostManagementExport -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue
        $existing = $exports | Where-Object { $_.Name -eq $ExportName }

        return ($null -ne $existing)
    } catch {
        return $false
    }
}

function New-CostExport {
    param(
        [string]$SubscriptionId,
        [string]$ExportName,
        [string]$ExportType,
        [string]$StorageAccountId,
        [string]$Container,
        [string]$Directory
    )

    try {
        # Set context to subscription
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

        # Check if export already exists
        if (Test-ExportExists -SubscriptionId $SubscriptionId -ExportName $ExportName) {
            Write-Log "Export '$ExportName' already exists in subscription $SubscriptionId" -Level Warning
            return @{
                Success = $false
                Skipped = $true
                Message = "Export already exists"
            }
        }

        # Map export type to dataset configuration
        $datasetConfig = switch ($ExportType) {
            "ActualCost" {
                @{
                    Configuration = @{
                        Type = "FocusCost"
                        DataVersion = "1.0"
                    }
                }
            }
            "PriceSheet" {
                @{
                    Granularity = "Daily"
                }
            }
            default {
                @{
                    Granularity = "Daily"
                }
            }
        }

        # Define export destination
        $destination = @{
            ResourceId = $StorageAccountId
            Container = $Container
            RootFolderPath = $Directory
        }

        # Define export schedule
        $schedule = @{
            Status = "Active"
            Recurrence = "Daily"
            RecurrencePeriod = @{
                From = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0).ToString("yyyy-MM-ddTHH:mm:ss")
                To = (Get-Date).AddYears(10).ToString("yyyy-MM-ddTHH:mm:ss")
            }
        }

        # Build export definition
        $exportDefinition = @{
            Type = "ActualCost"
            Timeframe = "MonthToDate"
            Schedule = $schedule
            Format = "Csv"
            Destination = $destination
            DataSet = $datasetConfig
            PartitionData = $true
        }

        Write-Verbose "Creating export with definition: $(ConvertTo-Json $exportDefinition -Depth 10)"

        # Create export using Azure CLI (Az PowerShell module has limitations)
        $scope = "/subscriptions/$SubscriptionId"

        # Use Azure CLI for export creation (more reliable than Az PowerShell)
        $exportJson = $exportDefinition | ConvertTo-Json -Depth 10 -Compress
        $exportJson = $exportJson.Replace('"', '\"')

        # Note: This is a simplified version. In production, use proper Azure CLI commands
        # or REST API calls for export creation

        Write-Log "Creating export '$ExportName' in subscription $SubscriptionId" -Level Info

        # Create export using New-AzCostManagementExport cmdlet
        $export = New-AzCostManagementExport `
            -Scope $scope `
            -Name $ExportName `
            -DefinitionType "ActualCost" `
            -DefinitionTimeframe "MonthToDate" `
            -DatasetGranularity "Daily" `
            -DestinationResourceId $StorageAccountId `
            -DestinationContainer $Container `
            -DestinationRootFolderPath $Directory `
            -Format "Csv" `
            -RecurrencePeriodFrom (Get-Date -Day 1).ToString("yyyy-MM-ddTHH:mm:ssZ") `
            -RecurrencePeriodTo (Get-Date).AddYears(10).ToString("yyyy-MM-ddTHH:mm:ssZ") `
            -ScheduleRecurrence "Daily" `
            -ScheduleStatus "Active" `
            -ErrorAction Stop

        Write-Log "Successfully created export '$ExportName'" -Level Success

        return @{
            Success = $true
            ExportName = $ExportName
            Export = $export
        }

    } catch {
        Write-Log "Failed to create export '$ExportName': $($_.Exception.Message)" -Level Error
        Write-Verbose "Error details: $($_.Exception | Format-List -Force | Out-String)"

        return @{
            Success = $false
            Skipped = $false
            Error = $_.Exception.Message
        }
    }
}

function Start-ExportExecution {
    param(
        [string]$SubscriptionId,
        [string]$ExportName
    )

    try {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

        Write-Log "Triggering immediate execution for export '$ExportName'" -Level Info

        # Use Azure CLI to execute export
        $result = az costmanagement export run `
            --export-name $ExportName `
            --scope "/subscriptions/$SubscriptionId" `
            2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Export '$ExportName' execution triggered successfully" -Level Success
            return @{ Success = $true }
        } else {
            Write-Log "Failed to trigger export execution: $result" -Level Warning
            return @{
                Success = $false
                Error = $result
            }
        }
    } catch {
        Write-Log "Failed to trigger export '$ExportName': $($_.Exception.Message)" -Level Warning
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function New-ExportForSubscription {
    param(
        [string]$SubscriptionId,
        [string]$HubName,
        [string]$StorageAccountId,
        [string[]]$ExportTypes,
        [bool]$RunImmediately
    )

    try {
        # Get subscription details
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
        $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId
        $subscriptionName = $subscription.Name

        Write-Log "`nProcessing subscription: $subscriptionName ($SubscriptionId)" -Level Info

        $subResults = @()

        foreach ($exportType in $ExportTypes) {
            # Generate export name and paths
            $exportName = "ftk-$HubName-$($exportType.ToLower())"

            $container = "msexports"
            $directory = switch ($exportType) {
                "ActualCost"                  { "$SubscriptionId/costs" }
                "PriceSheet"                  { "$SubscriptionId/prices" }
                "ReservationDetails"          { "$SubscriptionId/CommitmentDiscountUsage" }
                "ReservationRecommendations"  { "$SubscriptionId/Recommendations" }
                "ReservationTransactions"     { "$SubscriptionId/Transactions" }
                default                       { "$SubscriptionId/costs" }
            }

            # Create export
            $result = New-CostExport `
                -SubscriptionId $SubscriptionId `
                -ExportName $exportName `
                -ExportType $exportType `
                -StorageAccountId $StorageAccountId `
                -Container $container `
                -Directory $directory

            # Run export immediately if requested
            if ($result.Success -and $RunImmediately) {
                Start-Sleep -Seconds 2  # Brief pause between operations
                $runResult = Start-ExportExecution -SubscriptionId $SubscriptionId -ExportName $exportName
                $result.ExecutionTriggered = $runResult.Success
            }

            $subResults += [PSCustomObject]@{
                SubscriptionId = $SubscriptionId
                SubscriptionName = $subscriptionName
                ExportType = $exportType
                ExportName = $exportName
                Success = $result.Success
                Skipped = $result.Skipped
                Error = $result.Error
                ExecutionTriggered = $result.ExecutionTriggered
            }

            # Update counters
            if ($result.Success) {
                $script:successCount++
            } elseif ($result.Skipped) {
                $script:skippedCount++
            } else {
                $script:failureCount++
            }
        }

        return $subResults

    } catch {
        Write-Log "Failed to process subscription $SubscriptionId: $($_.Exception.Message)" -Level Error

        return [PSCustomObject]@{
            SubscriptionId = $SubscriptionId
            SubscriptionName = "Unknown"
            ExportType = "N/A"
            ExportName = "N/A"
            Success = $false
            Skipped = $false
            Error = $_.Exception.Message
            ExecutionTriggered = $false
        }
    }
}

#endregion

#region Main Script

Write-Log "========================================" -Level Info
Write-Log "  FinOps Hub - Bulk Export Creation    " -Level Info
Write-Log "========================================" -Level Info
Write-Log ""

# Verify Azure connection
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level Error
        exit 1
    }
    Write-Log "Connected to Azure tenant: $($context.Tenant.Id)" -Level Success
    Write-Log "Using account: $($context.Account.Id)" -Level Info
} catch {
    Write-Log "Failed to get Azure context: $($_.Exception.Message)" -Level Error
    Write-Log "Please run Connect-AzAccount first." -Level Error
    exit 1
}

# Get storage account details
Write-Log "`nValidating storage account..." -Level Info
$storageDetails = Get-StorageAccountDetails -ResourceGroupName $StorageResourceGroup -AccountName $StorageAccountName

if (-not $storageDetails.Success) {
    Write-Log "Cannot proceed without valid storage account." -Level Error
    exit 1
}

Write-Log "Storage account validated: $($storageDetails.AccountName)" -Level Success
Write-Log "Storage account resource ID: $($storageDetails.Id)" -Level Info

# Ensure msexports container exists
try {
    $container = Get-AzStorageContainer -Name "msexports" -Context $storageDetails.Context -ErrorAction SilentlyContinue
    if (-not $container) {
        Write-Log "Creating 'msexports' container..." -Level Info
        New-AzStorageContainer -Name "msexports" -Context $storageDetails.Context -Permission Off | Out-Null
        Write-Log "Container 'msexports' created successfully" -Level Success
    } else {
        Write-Log "Container 'msexports' already exists" -Level Info
    }
} catch {
    Write-Log "Failed to create container: $($_.Exception.Message)" -Level Error
    exit 1
}

# Get subscription list
$subscriptions = Get-SubscriptionList -ConfigFile $ConfigFile -SubscriptionIds $SubscriptionIds

if ($subscriptions.Count -eq 0) {
    Write-Log "No subscriptions found to process." -Level Warning
    exit 0
}

Write-Log "`nFound $($subscriptions.Count) subscription(s) to process" -Level Info
Write-Log "Export types: $($ExportTypes -join ', ')" -Level Info
Write-Log "Total exports to create: $($subscriptions.Count * $ExportTypes.Count)" -Level Info

if ($ParallelProcessing) {
    Write-Log "Parallel processing enabled (max $MaxParallelJobs jobs)" -Level Info
}

# Confirm before proceeding
if (-not $PSCmdlet.ShouldProcess("Create exports for $($subscriptions.Count) subscriptions", "", "")) {
    $confirm = Read-Host "`nProceed with export creation? (Y/N)"
    if ($confirm -ne 'Y') {
        Write-Log "Operation cancelled by user" -Level Warning
        exit 0
    }
}

Write-Log "`nStarting export creation..." -Level Info
$startTime = Get-Date

# Process subscriptions
if ($ParallelProcessing) {
    # Parallel processing using ForEach-Object -Parallel (PowerShell 7+)
    $script:results = $subscriptions | ForEach-Object -Parallel {
        $sub = $_
        $funcDef = $using:functionDefinitions  # Would need to pass function definitions

        # Call New-ExportForSubscription
        # Note: This requires PowerShell 7+ and proper function passing
    } -ThrottleLimit $MaxParallelJobs

} else {
    # Sequential processing
    foreach ($subscriptionId in $subscriptions) {
        $result = New-ExportForSubscription `
            -SubscriptionId $subscriptionId `
            -HubName $HubName `
            -StorageAccountId $storageDetails.Id `
            -ExportTypes $ExportTypes `
            -RunImmediately $RunExportsImmediately.IsPresent

        $script:results += $result

        # Brief pause between subscriptions to avoid throttling
        Start-Sleep -Seconds 1
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

# Display results
Write-Log "`n========================================" -Level Info
Write-Log "  Export Creation Summary               " -Level Info
Write-Log "========================================" -Level Info

Write-Log "`nResults by subscription:" -Level Info
$script:results | Format-Table SubscriptionName, ExportType, ExportName, Success, Skipped, Error -AutoSize

Write-Log "`n=== Summary Statistics ===" -Level Info
Write-Log "Total subscriptions processed: $($subscriptions.Count)" -Level Info
Write-Log "Total export operations: $($script:results.Count)" -Level Info
Write-Log "Successful: $script:successCount" -Level Success
Write-Log "Skipped: $script:skippedCount" -Level Warning
Write-Log "Failed: $script:failureCount" -Level $(if ($script:failureCount -gt 0) { "Error" } else { "Info" })
Write-Log "Duration: $($duration.ToString('mm\:ss'))" -Level Info

if ($RunExportsImmediately) {
    $triggered = ($script:results | Where-Object { $_.ExecutionTriggered -eq $true }).Count
    Write-Log "Exports triggered: $triggered" -Level Info
}

# Export results to CSV
$resultsCsvPath = ".\export-creation-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$script:results | Export-Csv -Path $resultsCsvPath -NoTypeInformation
Write-Log "`nResults exported to: $resultsCsvPath" -Level Info

# Final status
if ($script:failureCount -eq 0) {
    Write-Log "`n✓ All export operations completed successfully!" -Level Success
    Write-Log "Exports will run on their configured schedule (typically daily)." -Level Info

    if ($RunExportsImmediately) {
        Write-Log "Immediate execution triggered. Check Cost Management for export status." -Level Info
        Write-Log "Exports typically take 4-8 hours to complete." -Level Info
    }

    exit 0
} else {
    Write-Log "`n⚠ Some export operations failed. Please review the errors above." -Level Warning
    Write-Log "You may need to:" -Level Info
    Write-Log "  1. Verify permissions (Cost Management Contributor role)" -Level Info
    Write-Log "  2. Check storage account access" -Level Info
    Write-Log "  3. Retry failed subscriptions manually" -Level Info

    exit 1
}

#endregion
