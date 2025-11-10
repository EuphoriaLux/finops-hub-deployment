# FinOps Hub - Azure Deployment

Deploy a streamlined FinOps Hub solution to your Azure subscription for cost management and optimization.

## 🚀 Quick Deploy

Click the button below to deploy to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FEuphoriaLux%2Ffinops-hub-deployment%2Fmain%2Ftemplate.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FEuphoriaLux%2Ffinops-hub-deployment%2Fmain%2FcreateUiDefinition.json)

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
- **Storage Account:** ~$50-150/month (depends on data volume)
- **Azure Data Factory:** ~$20-100/month (depends on pipeline runs)
- **Key Vault:** ~$5/month
- **Event Grid:** ~$1-5/month
- **Total:** ~$75-260/month

**Note:** Actual costs depend on your data volume, pipeline execution frequency, and retention settings.

## ✅ Prerequisites

Before deploying, ensure you have:

- ✅ Active Azure subscription
- ✅ **Contributor** role on target subscription/resource group
- ✅ **User Access Administrator** role (if using managed exports)
- ✅ 15-45 minutes for deployment

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
| `enableManagedExports` | Auto-create Cost Management exports | true (recommended) |
| `enablePublicAccess` | Allow public network access | true |
| `scopesToMonitor` | Azure subscription IDs to monitor | Your subscription IDs (array) |

**Advanced Parameters** (leave as default for standard deployment):
- `exportRetentionInDays`: Raw export data retention (default: 0 = delete after processing)
- `ingestionRetentionInMonths`: Processed data retention (default: 13 months)
- `tags`: Custom tags for all resources

## 📖 Documentation

- **[Deployment Guide](DEPLOYMENT-GUIDE.md)** - Complete deployment instructions
- **[Customer Checklist](CUSTOMER-CHECKLIST.md)** - Step-by-step deployment checklist

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

6. **Key Vault** - For secrets management (if configured)

## 🔒 Security Features

- ✅ Managed identities (no passwords)
- ✅ Key Vault for secrets
- ✅ Optional infrastructure encryption
- ✅ Private networking support
- ✅ RBAC-based access control

## 🐛 Troubleshooting

### "Insufficient permissions" error
- Ensure you have both **Contributor** + **User Access Administrator** roles
- Or disable managed exports: set `enableManagedExports` to `false` during deployment

### Resource name conflicts
- Change the `hubName` parameter to a unique value
- The system adds a unique suffix to resource names automatically

### No cost data appearing after 24 hours
- Verify Cost Management exports were created (check Azure Portal → Cost Management → Exports)
- Check the `msexports` container in your storage account for data
- Verify managed identity has required permissions on your subscriptions

[See full troubleshooting guide](DEPLOYMENT-GUIDE.md)

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
