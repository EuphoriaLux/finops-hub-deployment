# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Enhanced version with retry logic and RBAC propagation delay handling
# This script updates the settings.json file in Azure Storage with improved error handling

Write-Output "=========================================="
Write-Output "FinOps Hub - Upload Settings Script (Enhanced)"
Write-Output "=========================================="
Write-Output "Updating settings.json file..."
Write-Output "  Storage account: $env:storageAccountName"
Write-Output "  Container: $env:containerName"
Write-Output ""

$validateScopes = { $_.Length -gt 45 }

# Initialize variables
$fileName = 'settings.json'
$filePath = Join-Path -Path . -ChildPath $fileName
$newScopes = $env:scopes.Split('|') | Where-Object $validateScopes | ForEach-Object { @{ scope = $_ } }

# Retry configuration
$maxRetries = 5
$retryDelays = @(30, 60, 120, 240, 480)  # Exponential backoff in seconds
$currentRetry = 0
$success = $false

# Function to test storage access
function Test-StorageAccess {
    param(
        [hashtable]$StorageContext
    )
    try {
        Write-Output "Testing storage account access..."
        $container = Get-AzStorageContainer @StorageContext -ErrorAction Stop
        Write-Output "  ✓ Successfully accessed storage container"
        return $true
    }
    catch {
        Write-Output "  ✗ Cannot access storage container: $($_.Exception.Message)"
        return $false
    }
}

# Function to check RBAC permissions
function Test-RBACPermissions {
    param(
        [string]$StorageAccountName
    )
    try {
        Write-Output "Checking RBAC permissions..."
        # Try to get storage account properties
        $context = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -ErrorAction Stop
        Write-Output "  ✓ Successfully created storage context"
        return $context
    }
    catch {
        Write-Output "  ✗ Cannot create storage context: $($_.Exception.Message)"
        if ($_.Exception.Message -like "*Authorization*" -or $_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*403*") {
            Write-Output ""
            Write-Output "⚠️  RBAC PROPAGATION DELAY DETECTED"
            Write-Output "This is a common issue when deploying FinOps Hub."
            Write-Output "Azure RBAC role assignments can take 5-10 minutes to propagate."
            Write-Output ""
        }
        return $null
    }
}

# Initial RBAC wait period (to handle immediate propagation delays)
Write-Output "Waiting for RBAC permissions to propagate (60 seconds)..."
Write-Output "This is normal for first-time deployments."
Start-Sleep -Seconds 60

# Retry loop with exponential backoff
while (-not $success -and $currentRetry -lt $maxRetries) {
    try {
        if ($currentRetry -gt 0) {
            $delay = $retryDelays[$currentRetry - 1]
            Write-Output ""
            Write-Output "=========================================="
            Write-Output "Retry attempt $currentRetry of $maxRetries"
            Write-Output "Waiting $delay seconds before retry..."
            Write-Output "=========================================="
            Start-Sleep -Seconds $delay
        }

        Write-Output ""
        Write-Output "Attempting to access storage account..."

        # Get storage context with RBAC check
        $context = Test-RBACPermissions -StorageAccountName $env:storageAccountName
        if ($null -eq $context) {
            throw "Failed to create storage context. RBAC permissions may not be propagated yet."
        }

        $storageContext = @{
            Context   = $context
            Container = $env:containerName
        }

        # Test storage access
        if (-not (Test-StorageAccess -StorageContext $storageContext)) {
            throw "Cannot access storage container. Permissions may not be propagated yet."
        }

        Write-Output ""
        Write-Output "Downloading existing settings (if any)..."

        # Download existing settings, if they exist
        $blob = Get-AzStorageBlobContent @storageContext -Blob $fileName -Destination $filePath -Force -ErrorAction Stop
        if ($blob)
        {
            $text = Get-Content $filePath -Raw
            Write-Output "---------"
            Write-Output $text
            Write-Output "---------"
            $json = $text | ConvertFrom-Json
            Write-Output "Existing settings.json file found. Updating..."

            # Rename exportScopes to scopes + convert to object array
            if ($json.exportScopes)
            {
                Write-Output "  Updating exportScopes..."
                if ($json.exportScopes[0] -is [string])
                {
                    Write-Output "    Converting string array to object array..."
                    $json.exportScopes = @($json.exportScopes | Where-Object $validateScopes | ForEach-Object { @{ scope = $_ } })
                    if (-not ($json.exportScopes -is [array]))
                    {
                        Write-Output "    Converting single object to object array..."
                        $json.exportScopes = @($json.exportScopes)
                    }
                }

                Write-Output "    Renaming to 'scopes'..."
                $json | Add-Member -MemberType NoteProperty -Name scopes -Value $json.exportScopes
                $json.PSObject.Properties.Remove('exportScopes')
            }

            # Force string array to object array with unique values
            if ($json.scopes)
            {
                Write-Output "  Converting string array to object array..."
                $scopeArray = @()
                $json.scopes | Where-Object $validateScopes | ForEach-Object { $scopeArray += $_ } | Select-Object -Unique
                $json.scopes = @() + $scopeArray
            }
        }

        # Set default if not found
        if (!$json)
        {
            Write-Output "No existing settings.json file found. Creating new file..."
            $json = [ordered]@{
                '$schema' = 'https://aka.ms/finops/hubs/settings-schema'
                type      = 'HubInstance'
                version   = ''
                learnMore = 'https://aka.ms/finops/hubs'
                scopes    = @()
                retention = @{
                    'msexports' = @{
                        days = 0
                    }
                    'ingestion' = @{
                        months = 13
                    }
                    'raw'       = @{
                        days = 0
                    }
                    'final'     = @{
                        months = 13
                    }
                }
            }

            $text = $json | ConvertTo-Json
            Write-Output "---------"
            Write-Output $text
            Write-Output "---------"
        }

        # Set default retention
        if (!($json.retention))
        {
            # In case the retention object is not present in the settings.json file (versions before 0.4), add it with default values
            $retention = @"
    {
        "msexports": {
            "days": 0
        },
        "ingestion": {
            "months": 13
        },
        "raw": {
            "days": 0
        },
        "final": {
            "months": 13
        }
    }
"@
            $json | Add-Member -Name retention -Value (ConvertFrom-Json $retention) -MemberType NoteProperty
        }

        # Set or update msexports retention
        if (!($json.retention.msexports))
        {
            $json.retention | Add-Member -Name msexports -Value (ConvertFrom-Json "{""days"":$($env:msexportRetentionInDays)}") -MemberType NoteProperty
        }
        else
        {
            $json.retention.msexports.days = [Int32]::Parse($env:msexportRetentionInDays)
        }

        # Set or update ingestion retention
        if (!($json.retention.ingestion))
        {
            $json.retention | Add-Member -Name ingestion -Value (ConvertFrom-Json "{""months"":$($env:ingestionRetentionInMonths)}") -MemberType NoteProperty
        }
        else
        {
            $json.retention.ingestion.months = [Int32]::Parse($env:ingestionRetentionInMonths)
        }

        # Set or update raw retention
        if (!($json.retention.raw))
        {
            $json.retention | Add-Member -Name raw -Value (ConvertFrom-Json "{""days"":$($env:rawRetentionInDays)}") -MemberType NoteProperty
        }
        else
        {
            $json.retention.raw.days = [Int32]::Parse($env:rawRetentionInDays)
        }

        # Set or update final retention
        if (!($json.retention.final))
        {
            $json.retention | Add-Member -Name final -Value (ConvertFrom-Json "{""months"":$($env:finalRetentionInMonths)}") -MemberType NoteProperty
        }
        else
        {
            $json.retention.final.months = [Int32]::Parse($env:finalRetentionInMonths)
        }

        # Updating settings
        Write-Output "Updating version to $env:ftkVersion..."
        $json.version = $env:ftkVersion
        $json.scopes = (@() + $json.scopes + $newScopes) | Select-Object -Unique
        if ($null -eq $json.scopes) { $json.scopes = @() }
        $text = $json | ConvertTo-Json
        Write-Output "---------"
        Write-Output $text
        Write-Output "---------"
        $text | Out-File $filePath

        # Upload new/updated settings
        Write-Output ""
        Write-Output "Uploading settings.json file..."
        Set-AzStorageBlobContent @storageContext -File $filePath -Force -ErrorAction Stop | Out-Null

        Write-Output ""
        Write-Output "=========================================="
        Write-Output "✓ SUCCESS: Settings file uploaded successfully!"
        Write-Output "=========================================="
        $success = $true
    }
    catch {
        $currentRetry++
        Write-Output ""
        Write-Output "=========================================="
        Write-Output "✗ ERROR: Attempt $currentRetry failed"
        Write-Output "=========================================="
        Write-Output "Error details: $($_.Exception.Message)"
        Write-Output "Error type: $($_.Exception.GetType().FullName)"

        if ($_.Exception.Message -like "*Authorization*" -or $_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*403*") {
            Write-Output ""
            Write-Output "⚠️  This appears to be an RBAC permission issue."
            Write-Output "Managed identity permissions may not have propagated yet."
            Write-Output "This is normal and usually resolves within 5-10 minutes."
        }

        if ($currentRetry -ge $maxRetries) {
            Write-Output ""
            Write-Output "=========================================="
            Write-Output "✗ DEPLOYMENT FAILED"
            Write-Output "=========================================="
            Write-Output ""
            Write-Output "All retry attempts exhausted. Common causes:"
            Write-Output ""
            Write-Output "1. RBAC Propagation Delay (MOST COMMON)"
            Write-Output "   - Azure RBAC can take 5-10 minutes to propagate"
            Write-Output "   - Solution: Wait 10-15 minutes and retry the deployment"
            Write-Output ""
            Write-Output "2. Missing Permissions"
            Write-Output "   - Deploying user needs: Contributor + User Access Administrator"
            Write-Output "   - Managed identity needs: Storage Blob Data Contributor"
            Write-Output ""
            Write-Output "3. Network/Firewall Issues"
            Write-Output "   - Check storage account firewall rules"
            Write-Output "   - Verify deployment script can access storage"
            Write-Output ""
            Write-Output "For detailed diagnostics, run:"
            Write-Output "  .\scripts\diagnose-deployment-failure.ps1 -ResourceGroupName '<your-rg>' -StorageAccountName '<storage-account>'"
            Write-Output ""
            Write-Output "For more help, visit: https://github.com/microsoft/finops-toolkit"
            Write-Output ""
            throw "Deployment script failed after $maxRetries attempts. See above for troubleshooting guidance."
        }
    }
}
