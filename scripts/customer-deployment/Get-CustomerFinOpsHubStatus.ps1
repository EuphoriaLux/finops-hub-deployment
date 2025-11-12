<#
.SYNOPSIS
    Monitors FinOps Hub health and data flow status.

.DESCRIPTION
    Real-time monitoring script that checks export execution, pipeline runs,
    data availability, and overall hub health.

.PARAMETER ResourceGroupName
    Name of the resource group containing FinOps Hub resources.

.PARAMETER DataFactoryName
    Name of the Data Factory instance.

.PARAMETER StorageAccountName
    Name of the storage account.

.PARAMETER WaitForData
    If specified, waits for data to appear in storage.

.PARAMETER TimeoutMinutes
    Timeout in minutes when WaitForData is specified. Default: 30 minutes.

.EXAMPLE
    .\Get-CustomerFinOpsHubStatus.ps1 -ResourceGroupName "rg-finops-hub-contoso-prod" -DataFactoryName "adf-finops-hub-contoso-eastus2"

.EXAMPLE
    .\Get-CustomerFinOpsHubStatus.ps1 -ResourceGroupName "rg-finops-hub-contoso-prod" -DataFactoryName "adf-finops-hub-contoso-eastus2" -WaitForData -TimeoutMinutes 60

.NOTES
    Author: FinOps Team
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName,

    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$false)]
    [switch]$WaitForData,

    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 30
)

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

    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

Write-Log "============================================" -Level Info
Write-Log "  FinOps Hub Health Status                  " -Level Info
Write-Log "============================================" -Level Info
Write-Log ""

# Check Azure connection
try {
    $context = Get-AzContext -ErrorAction Stop
    Write-Log "Connected to tenant: $($context.Tenant.Id)" -Level Success
} catch {
    Write-Log "Not connected to Azure. Run Connect-AzAccount first." -Level Error
    exit 1
}

# Get storage account name if not provided
if (-not $StorageAccountName) {
    $storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName
    $hubStorage = $storageAccounts | Where-Object { $_.StorageAccountName -like "*finopshub*" } | Select-Object -First 1

    if ($hubStorage) {
        $StorageAccountName = $hubStorage.StorageAccountName
        Write-Log "Detected storage account: $StorageAccountName" -Level Info
    } else {
        Write-Log "Could not find storage account. Please specify -StorageAccountName" -Level Error
        exit 1
    }
}

# 1. Check Data Factory Pipeline Runs
Write-Log "`nChecking Data Factory pipeline runs..." -Level Info

$pipelineRuns = Get-AzDataFactoryV2PipelineRun `
    -ResourceGroupName $ResourceGroupName `
    -DataFactoryName $DataFactoryName `
    -LastUpdatedAfter (Get-Date).AddDays(-1) `
    -LastUpdatedBefore (Get-Date) `
    -ErrorAction SilentlyContinue

if ($pipelineRuns) {
    $succeeded = ($pipelineRuns | Where-Object { $_.Status -eq "Succeeded" }).Count
    $failed = ($pipelineRuns | Where-Object { $_.Status -eq "Failed" }).Count
    $inProgress = ($pipelineRuns | Where-Object { $_.Status -eq "InProgress" }).Count

    Write-Log "Pipeline Runs (Last 24 Hours):" -Level Info
    Write-Log "  Succeeded: $succeeded" -Level Success
    Write-Log "  Failed: $failed" -Level $(if ($failed -gt 0) { "Error" } else { "Info" })
    Write-Log "  In Progress: $inProgress" -Level Info

    if ($failed -gt 0) {
        Write-Log "`nFailed Pipeline Runs:" -Level Warning
        $failedRuns = $pipelineRuns | Where-Object { $_.Status -eq "Failed" }
        $failedRuns | Format-Table PipelineName, Status, RunStart, Message -AutoSize
    }
} else {
    Write-Log "No pipeline runs found in the last 24 hours" -Level Warning
}

# 2. Check Storage Account Data
Write-Log "`nChecking storage account data..." -Level Info

$storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$ctx = $storage.Context

# Check msexports container
$msexportsBlobs = Get-AzStorageBlob -Container "msexports" -Context $ctx -ErrorAction SilentlyContinue

if ($msexportsBlobs) {
    $totalFiles = $msexportsBlobs.Count
    $totalSize = ($msexportsBlobs | Measure-Object -Property Length -Sum).Sum / 1GB
    $latestBlob = $msexportsBlobs | Sort-Object LastModified -Descending | Select-Object -First 1

    Write-Log "msexports Container:" -Level Info
    Write-Log "  Total Files: $totalFiles" -Level Success
    Write-Log "  Total Size: $([math]::Round($totalSize, 2)) GB" -Level Info
    Write-Log "  Latest File: $($latestBlob.Name)" -Level Info
    Write-Log "  Last Modified: $($latestBlob.LastModified)" -Level Info
} else {
    Write-Log "msexports Container: No data found" -Level Warning
}

# Check ingestion container
$ingestionBlobs = Get-AzStorageBlob -Container "ingestion" -Context $ctx -ErrorAction SilentlyContinue

if ($ingestionBlobs) {
    $totalFiles = $ingestionBlobs.Count
    $totalSize = ($ingestionBlobs | Measure-Object -Property Length -Sum).Sum / 1GB
    $latestBlob = $ingestionBlobs | Sort-Object LastModified -Descending | Select-Object -First 1

    Write-Log "`ningestion Container:" -Level Info
    Write-Log "  Total Files: $totalFiles" -Level Success
    Write-Log "  Total Size: $([math]::Round($totalSize, 2)) GB" -Level Info
    Write-Log "  Latest File: $($latestBlob.Name)" -Level Info
    Write-Log "  Last Modified: $($latestBlob.LastModified)" -Level Info
} else {
    Write-Log "`ningestion Container: No data found yet" -Level Warning
}

# 3. Wait for data if requested
if ($WaitForData -and -not $msexportsBlobs) {
    Write-Log "`nWaiting for data to appear (timeout: $TimeoutMinutes minutes)..." -Level Info

    $startTime = Get-Date
    $dataFound = $false

    while (((Get-Date) - $startTime).TotalMinutes -lt $TimeoutMinutes) {
        Start-Sleep -Seconds 60

        $blobs = Get-AzStorageBlob -Container "msexports" -Context $ctx -ErrorAction SilentlyContinue

        if ($blobs) {
            Write-Log "✓ Data detected in msexports container!" -Level Success
            $dataFound = $true
            break
        }

        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
        Write-Log "  Still waiting... ($elapsed / $TimeoutMinutes minutes)" -Level Info
    }

    if (-not $dataFound) {
        Write-Log "⚠ Timeout reached. No data appeared in $TimeoutMinutes minutes." -Level Warning
        Write-Log "Exports may still be running. Check Cost Management for export status." -Level Info
    }
}

# 4. Overall Health Summary
Write-Log "`n============================================" -Level Info
Write-Log "  Health Summary                             " -Level Info
Write-Log "============================================" -Level Info

$healthStatus = @{
    PipelinesHealthy = ($pipelineRuns -and (($pipelineRuns | Where-Object { $_.Status -eq "Failed" }).Count -eq 0))
    DataPresent = ($null -ne $msexportsBlobs -and $msexportsBlobs.Count -gt 0)
    ProcessedDataPresent = ($null -ne $ingestionBlobs -and $ingestionBlobs.Count -gt 0)
}

if ($healthStatus.PipelinesHealthy) {
    Write-Log "✓ Data Factory pipelines are healthy" -Level Success
} else {
    Write-Log "⚠ Data Factory has pipeline failures" -Level Warning
}

if ($healthStatus.DataPresent) {
    Write-Log "✓ Export data is present in storage" -Level Success
} else {
    Write-Log "⚠ No export data found yet" -Level Warning
}

if ($healthStatus.ProcessedDataPresent) {
    Write-Log "✓ Processed data is available" -Level Success
} else {
    Write-Log "⚠ No processed data found yet" -Level Warning
}

$allHealthy = $healthStatus.Values -notcontains $false

if ($allHealthy) {
    Write-Log "`n✓ FinOps Hub is fully operational!" -Level Success
} else {
    Write-Log "`n⚠ FinOps Hub has some pending items or issues" -Level Warning
    Write-Log "This is normal for new deployments. Data typically arrives within 4-8 hours." -Level Info
}

Write-Log ""
