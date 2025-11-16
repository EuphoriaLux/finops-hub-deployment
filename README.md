# FinOps Hub - Azure Deployment

[![Documentation](https://img.shields.io/badge/📖_Documentation-GitHub_Pages-blue?style=for-the-badge)](https://EuphoriaLux.github.io/finops-hub-deployment/)

Deploy a streamlined FinOps Hub solution to your Azure subscription for cost management and optimization.

> **📘 [View Complete Documentation](https://EuphoriaLux.github.io/finops-hub-deployment/)** - Comprehensive deployment guide, export setup instructions, CSP considerations, and troubleshooting

## 🚀 Quick Deploy

Click the button below to deploy to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FEuphoriaLux%2Ffinops-hub-deployment%2Fmain%2Ftemplate.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FEuphoriaLux%2Ffinops-hub-deployment%2Fmain%2FcreateUiDefinition.json%3Ft%3D1762981499)

> **📋 IMPORTANT:** After deployment completes, follow the [Post-Deployment Checklist](./POST-DEPLOYMENT-CHECKLIST.md) to verify automatic processing is configured correctly.

## 📋 What Gets Deployed

This template deploys the core FinOps Hub infrastructure:

- **Storage Account** (Data Lake Gen2) - For cost data storage with `msexports` and `ingestion` containers
- **Azure Data Factory** - ETL pipelines for data processing
- **Key Vault** - Secure secrets management
- **Managed Identities** - Service authentication (Data Factory MI, Trigger Manager MI, Blob Manager MI)
- **Event Grid System Topic** - For blob event handling

**Note:** This is a streamlined deployment **without** Azure Data Explorer, optimized for most cost management scenarios.

## ⏱️ Deployment Time & Cost

### Deployment Time
- **Estimated:** 15-20 minutes
- **Resources:** 5-7 core resources

### Monthly Cost Estimate
- **Storage Account:** ~$2-10/month (typically 10-50 GB of cost data)
- **Azure Data Factory:** ~$1-5/month (daily pipeline runs, ~$0.005 per activity)
- **Key Vault:** ~$1-2/month
- **Event Grid:** <$1/month
- **Managed Identities:** FREE
- **Total:** ~$5-20/month

**Note:** Actual costs depend on your data volume, pipeline execution frequency, and retention settings. This estimate assumes daily cost export processing with typical enterprise cost data volumes.

## ✅ Prerequisites

Before deploying, ensure you have:

- ✅ Active Azure subscription
- ✅ **Contributor** role on target subscription/resource group
- ✅ 15-45 minutes for deployment

### ⚠️ CRITICAL: Register Event Grid Provider First

**You MUST register the Event Grid provider BEFORE deployment:**

```powershell
# Register Event Grid provider
az provider register --namespace Microsoft.EventGrid

# Verify registration (wait until status is "Registered")
az provider show --namespace Microsoft.EventGrid --query "registrationState" --output tsv
```

**Why this matters:** If `Microsoft.EventGrid` is not registered before deployment, the Event Grid System Topic won't be created, and automatic export processing will NOT work. You'll need to create it manually later.

**⏱️ Registration takes 1-2 minutes** - wait for `Registered` status before clicking "Deploy to Azure".

## 🔧 Deployment Methods

### Option 1: Azure Portal (Recommended)
Click the "Deploy to Azure" button above.

### Option 2: Azure CLI
```bash
az deployment group create \
  --name finops-hub-deployment \
  --resource-group rg-finops-hub-prod \
  --template-uri https://raw.githubusercontent.com/EuphoriaLux/finops-hub-deployment/main/template.json \
  --parameters hubName=my-finops-hub
```

### Option 3: PowerShell
```powershell
New-AzResourceGroupDeployment `
  -Name finops-hub-deployment `
  -ResourceGroupName rg-finops-hub-prod `
  -TemplateUri https://raw.githubusercontent.com/EuphoriaLux/finops-hub-deployment/main/template.json `
  -hubName my-finops-hub
```

## 🔧 Key Parameters

You'll configure these during deployment:

| Parameter | Description | Recommended Value |
|-----------|-------------|-------------------|
| `hubName` | Unique hub identifier (used in resource names) | Your company name + "-finops-hub" |
| `location` | Azure region | "westeurope" or your preferred region |
| `storageSku` | Storage tier | Premium_LRS (default) |
| `enablePublicAccess` | Allow public network access | true |

**Advanced Parameters** (leave as default for standard deployment):
- `exportRetentionInDays`: Raw export data retention (default: 0 = delete after processing)
- `ingestionRetentionInMonths`: Processed data retention (default: 13 months)
- `tags`: Custom tags for all resources

## 📖 Documentation

### 🌐 **[View Complete Documentation →](https://EuphoriaLux.github.io/finops-hub-deployment/)**

All documentation is available on our comprehensive documentation portal:

✅ **Complete deployment instructions**
✅ **Interactive Architecture Diagram** - Visualize component connections and data flow
✅ **Configuration Builder** - Generate pre-filled deployment parameters with cost estimates
✅ **Export Configuration Wizard** - Generate PowerShell scripts or portal instructions
✅ **Step-by-step export configuration guide**
✅ **CSP subscription considerations**
✅ **Troubleshooting and diagnostics**
✅ **Resource links and references**

### 🆕 Interactive Features

The documentation site now includes powerful interactive tools to help you deploy and configure FinOps Hub:

- **🏗️ Architecture Diagram** - Interactive visualization of all Azure components with clickable elements and animated data flow
- **⚙️ Configuration Builder** - Calculate costs, validate parameters, and generate customized deployment links
- **🧙 Export Wizard** - Automatically generate PowerShell scripts or step-by-step portal instructions for Cost Management exports

👉 **[Enable GitHub Pages](GITHUB-PAGES-SETUP.md)** - Instructions to publish the documentation site

## 📦 Deployed Resources

After deployment, you'll have these resources in your resource group:

1. **finopshub[uniqueid]** - Storage Account
   - `msexports` container - Raw Cost Management exports
   - `ingestion` container - Processed cost data

2. **finops-hub-engine-[uniqueid]** - Data Factory
   - Pre-configured pipelines for data processing
   - Managed Virtual Network for secure connections

3. **finopshub[uniqueid]_blobManager** - Managed Identity
   - For blob storage operations

4. **finops-hub-engine-[uniqueid]_triggerManager** - Managed Identity
   - For Data Factory trigger management

5. **finopshub[uniqueid]-[guid]** - Event Grid System Topic
   - For blob creation events
   - **⚠️ Only created if Microsoft.EventGrid provider is registered before deployment**

6. **Key Vault** - For secrets management (if configured)

## 🔒 Security Features

- ✅ Managed identities (no passwords)
- ✅ Key Vault for secrets
- ✅ Optional infrastructure encryption
- ✅ Private networking support
- ✅ RBAC-based access control

## 🐛 Troubleshooting

> **📋 First Time Setup:** If this is your first deployment, follow the [Post-Deployment Checklist](./POST-DEPLOYMENT-CHECKLIST.md) to verify all components are configured correctly.

### Deployment Script Failures (uploadSettings)

**Error**: `ResourceDeploymentFailure` for `uploadSettings` deployment script

**Most Common Cause**: RBAC propagation delay (90% of cases)

**Symptoms**:
- Deployment fails with "ResourceDeploymentFailure" for deployment script
- Error mentions "Authorization failed" or "Forbidden" (403)
- Happens during "UpdateSettings" phase

**Solution**:
1. **Wait 10-15 minutes** after the initial failure
2. **Retry the deployment** using the same parameters
3. The second attempt usually succeeds (RBAC roles have propagated)

**Why This Happens**:
Azure RBAC role assignments can take 5-10 minutes to propagate across Azure's infrastructure. The deployment creates a managed identity and assigns it permissions, but the deployment script runs immediately before permissions are fully active.

**Run Diagnostics**:
```powershell
# PowerShell
.\scripts\diagnose-deployment-failure.ps1 -ResourceGroupName "your-rg-name"
```

```bash
# Bash/Linux
./scripts/diagnose-deployment-failure.sh -g your-rg-name
```

These diagnostic scripts will check:
- User permissions (Contributor + User Access Administrator)
- Managed identity existence and role assignments
- RBAC propagation status
- Storage account accessibility
- Detailed deployment error logs

### "Insufficient permissions" error

**Required Role**:
- **Contributor** role - To create/modify resources

**Solution**:
- Request Contributor role from your Azure administrator

### Resource name conflicts
- Change the `hubName` parameter to a unique value
- The system adds a unique suffix to resource names automatically

### Event Grid System Topic is Missing

**Symptoms:**
- No automatic pipeline runs triggered when exports complete
- Event Grid System Topic not visible in resource group

**Cause:** Microsoft.EventGrid provider was not registered before deployment

**Solution:**
1. Register the Event Grid provider:
   ```powershell
   az provider register --namespace Microsoft.EventGrid
   ```
2. Create the Event Grid System Topic manually:
   ```powershell
   # Get your storage account resource ID
   $STORAGE_ID = az storage account show `
     --name <your-storage-account-name> `
     --resource-group <your-resource-group> `
     --query id --output tsv

   # Create Event Grid System Topic
   az eventgrid system-topic create `
     --name <storage-account-name>-events `
     --resource-group <your-resource-group> `
     --source $STORAGE_ID `
     --topic-type Microsoft.Storage.StorageAccounts `
     --location <your-region>
   ```
3. Verify trigger starts successfully:
   ```powershell
   az datafactory trigger start `
     --factory-name <your-data-factory-name> `
     --resource-group <your-resource-group> `
     --name msexports_ManifestAdded
   ```

See [Post-Deployment Checklist](./POST-DEPLOYMENT-CHECKLIST.md) for detailed verification steps.

### No cost data appearing after 24 hours
- Verify Cost Management exports were created (check Azure Portal → Cost Management → Exports)
- Check the `msexports` container in your storage account for data
- Verify managed identity has required permissions on your subscriptions
- **Check Event Grid System Topic exists** (see above)

### Network/Firewall Issues
If your storage account has network restrictions:
- Deployment scripts may not be able to access storage
- Temporarily allow public network access during deployment
- Or configure firewall rules to allow Azure services

[See full troubleshooting guide & diagnostic tools](./scripts/)

## 📚 Additional Resources

- [Microsoft FinOps Hub Documentation](https://aka.ms/finops/hub)
- [Azure Cost Management](https://aka.ms/costmgmt)
- [FinOps Framework](https://www.finops.org/)

## 💬 Support

For questions or issues:
- Open an [issue](../../issues) in this repository
- Review the [troubleshooting guide](DEPLOYMENT-GUIDE.md)

## 📄 License

This template is provided as-is. Please ensure compliance with Microsoft's licensing terms.

---

**Template Version:** 0.36.177.2456
**Last Updated:** 2025-11-10
**Generated From:** Bicep
