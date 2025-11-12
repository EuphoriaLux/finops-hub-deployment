# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Script to update the uploadSettings script in template.json with retry logic
# This script reads the template, updates the PowerShell script, and saves the updated template

param(
    [string]$TemplatePath = "..\template.json",
    [string]$NewScriptPath = "uploadSettings-enhanced.ps1"
)

Write-Output "Reading template from: $TemplatePath"
$template = Get-Content $TemplatePath -Raw | ConvertFrom-Json

Write-Output "Reading enhanced script from: $NewScriptPath"
$newScript = Get-Content $NewScriptPath -Raw

Write-Output "Updating $fxv#2 variable..."
$template.resources[0].properties.template.variables.'$fxv#2' = $newScript

Write-Output "Saving updated template..."
$template | ConvertTo-Json -Depth 100 | Set-Content $TemplatePath

Write-Output "[SUCCESS] Template updated successfully!"
