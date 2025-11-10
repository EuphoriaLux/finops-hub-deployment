# FinOps Hub Custom Deployment Guide

## Overview
This package contains a customized FinOps Hub deployment template for Azure cost management and optimization.

## Package Contents
- `template.json` - Main ARM deployment template
- `template.parameters.json` - Customized parameters file with pre-configured settings

## Prerequisites

### Required Permissions
- **Contributor** role on the target subscription or resource group
- **User Access Administrator** role (if using managed exports)

### Azure CLI or PowerShell
- Azure CLI 2.50.0+ OR
- Azure PowerShell Az module 10.0.0+

## Deployment Options

### Option 1: Azure Portal Deployment

1. **Log in to Azure Portal**: https://portal.azure.com
2. **Search** for "Deploy a custom template"
3. **Click** "Build your own template in the editor"
4. **Copy/paste** the contents of `template.json`
5. **Click** "Save"
6. **Upload** or paste parameters from `template.parameters.json`
7. **Review** and click "Create"

### Option 2: Azure CLI Deployment

```bash
# Login to Azure
az login

# Set your subscription (replace with your subscription ID)
az account set --subscription "YOUR-SUBSCRIPTION-ID"

# Create resource group (if needed)
az group create \
  --name "rg-finops-hub-prod" \
  --location "eastus"

# Deploy the template
az deployment group create \
  --name "finops-hub-deployment" \
  --resource-group "rg-finops-hub-prod" \
  --template-file "template.json" \
  --parameters "@template.parameters.json"
```

### Option 3: PowerShell Deployment

```powershell
# Login to Azure
Connect-AzAccount

# Set your subscription (replace with your subscription ID)
Set-AzContext -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# Create resource group (if needed)
New-AzResourceGroup `
  -Name "rg-finops-hub-prod" `
  -Location "eastus"

# Deploy the template
New-AzResourceGroupDeployment `
  -Name "finops-hub-deployment" `
  -ResourceGroupName "rg-finops-hub-prod" `
  -TemplateFile "template.json" `
  -TemplateParameterFile "template.parameters.json"
```

## Customization Guide

### Pre-Configured Settings

The parameters file has been customized with the following settings:

| Parameter | Value | Description |
|-----------|-------|-------------|
| hubName | `customer-finops-hub` | Unique hub identifier |
| location | `eastus` | Azure region |
| storageSku | `Premium_LRS` | Storage performance tier |
| enableManagedExports | `true` | Auto-create Cost Management exports |
| enablePublicAccess | `true` | Allow public network access |

### Optional Customizations

#### 1. Change Hub Name
```json
"hubName": {
  "value": "your-company-finops-hub"
}
```

#### 2. Change Azure Region
```json
"location": {
  "value": "westeurope"
}
```

#### 3. Enable Azure Data Explorer (for >$2M/month costs)
```json
"dataExplorerName": {
  "value": "adx-finops-prod"
},
"dataExplorerSku": {
  "value": "Standard_D11_v2"
},
"dataExplorerCapacity": {
  "value": 2
}
```

#### 4. Configure Cost Scopes to Monitor
```json
"scopesToMonitor": {
  "value": [
    "/subscriptions/YOUR-SUBSCRIPTION-ID-1",
    "/subscriptions/YOUR-SUBSCRIPTION-ID-2",
    "/providers/Microsoft.Billing/billingAccounts/YOUR-BILLING-ACCOUNT-ID"
  ]
}
```

#### 5. Enable Private Networking
```json
"enablePublicAccess": {
  "value": false
},
"virtualNetworkAddressPrefix": {
  "value": "10.100.0.0/26"
}
```

#### 6. Adjust Data Retention
```json
"exportRetentionInDays": {
  "value": 30
},
"ingestionRetentionInMonths": {
  "value": 24
}
```

#### 7. Enable Infrastructure Encryption
```json
"enableInfrastructureEncryption": {
  "value": true
}
```

#### 8. Use High Availability Storage
```json
"storageSku": {
  "value": "Premium_ZRS"
}
```

## Post-Deployment Steps

### 1. Retrieve Deployment Outputs

**Azure CLI:**
```bash
az deployment group show \
  --name "finops-hub-deployment" \
  --resource-group "rg-finops-hub-prod" \
  --query properties.outputs
```

**PowerShell:**
```powershell
(Get-AzResourceGroupDeployment `
  -ResourceGroupName "rg-finops-hub-prod" `
  -Name "finops-hub-deployment").Outputs
```

### 2. Configure Cost Management Exports (if using managed exports)

1. Note the `managedIdentityId` and `managedIdentityTenantId` from outputs
2. Grant the managed identity permissions to your billing scopes
3. The hub will automatically create exports

### 3. Access Your Resources

After deployment, you'll have:
- **Storage Account** - `st{hubname}{uniqueid}`
- **Data Factory** - `adf-{hubname}-{uniqueid}`
- **Key Vault** - `kv-{hubname}-{uniqueid}`
- **Data Explorer** (if enabled) - `{dataExplorerName}`

## Validation

### Check Deployment Status

**Azure CLI:**
```bash
az deployment group list \
  --resource-group "rg-finops-hub-prod" \
  --output table
```

**PowerShell:**
```powershell
Get-AzResourceGroupDeployment `
  -ResourceGroupName "rg-finops-hub-prod" `
  | Format-Table
```

### Verify Resources

```bash
az resource list \
  --resource-group "rg-finops-hub-prod" \
  --output table
```

## Estimated Deployment Time

- **Without Data Explorer**: 15-25 minutes
- **With Data Explorer**: 30-45 minutes

## Cost Estimation

### Base Configuration (No Data Explorer)
- Storage Account: ~$50-150/month
- Data Factory: ~$20-100/month (depending on pipeline runs)
- Key Vault: ~$5/month
- **Total: ~$75-255/month**

### With Data Explorer (Dev SKU)
- Add ~$200-400/month for Dev Data Explorer
- **Total: ~$275-655/month**

### With Data Explorer (Standard SKU)
- Add ~$1,500-3,000/month for Standard Data Explorer
- **Total: ~$1,575-3,255/month**

## Troubleshooting

### Deployment Fails with "Insufficient Permissions"
- Ensure you have Contributor + User Access Administrator roles
- Or disable managed exports: `"enableManagedExports": { "value": false }`

### Resource Name Conflicts
- Change the `hubName` parameter to ensure unique resource names

### Quota Exceeded
- Check your subscription quotas for Data Factory, Storage, or Data Explorer
- Request quota increases via Azure Portal

### Private Endpoint Issues
- Ensure the virtual network address prefix doesn't overlap with existing networks
- Verify DNS zone configurations

## Support & Documentation

- **FinOps Hub Documentation**: https://aka.ms/finops/hub
- **Azure Cost Management**: https://aka.ms/costmgmt
- **Issue Reporting**: Contact your solution provider

## Security Considerations

1. **Review Tags** - Ensure tags align with your governance policies
2. **Network Access** - Consider disabling public access for production
3. **Encryption** - Enable infrastructure encryption for sensitive data
4. **RBAC** - Implement least-privilege access after deployment
5. **Monitoring** - Enable Azure Monitor alerts on deployed resources

## Updates & Maintenance

To update the deployment:
1. Modify parameters in `template.parameters.json`
2. Re-run the deployment command
3. ARM will update resources incrementally (mode: Incremental)

## Backup & Disaster Recovery

- Storage Account has versioning and soft delete enabled
- Data Factory pipelines are stored as code
- Key Vault has soft delete and purge protection
- Consider cross-region replication for critical scenarios

---

**Deployment Package Version**: 1.0
**Template Version**: 0.36.177.2456
**Last Updated**: 2025-11-10
