# FinOps Hub - Azure Deployment

Deploy a complete FinOps Hub solution to your Azure subscription for cost management and optimization.

## 🚀 Quick Deploy

Click the button below to deploy to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FEuphoriaLux%2Ffinops-hub-deployment%2Fmain%2Ftemplate.json)

## 📋 What Gets Deployed

This template deploys a complete FinOps Hub infrastructure:

- **Storage Account** (Data Lake Gen2) - For cost data storage
- **Azure Data Factory** - ETL pipelines for data processing
- **Key Vault** - Secure secrets management
- **Managed Identity** - Service authentication
- **Optional: Azure Data Explorer** - Advanced analytics (for >$2M/month costs)
- **Optional: Virtual Network** - Private networking with endpoints

## 📊 Deployment Options

### Small Business (<$2M/month costs)
- No Azure Data Explorer
- **Cost:** ~$75-255/month
- **Time:** ~15 minutes

### Medium Enterprise ($2-5M/month costs)
- Dev Azure Data Explorer
- **Cost:** ~$275-655/month
- **Time:** ~30 minutes

### Large Enterprise (>$5M/month costs)
- Standard Azure Data Explorer
- **Cost:** ~$1,575-3,255/month
- **Time:** ~45 minutes

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

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hubName` | Unique hub identifier | Required |
| `location` | Azure region | Resource group location |
| `storageSku` | Storage tier (Premium_LRS/Premium_ZRS) | Premium_LRS |
| `enableManagedExports` | Auto-create Cost Management exports | true |
| `dataExplorerName` | Azure Data Explorer cluster name | "" (disabled) |
| `enablePublicAccess` | Allow public network access | true |

## 📖 Documentation

- **[Deployment Guide](DEPLOYMENT-GUIDE.md)** - Complete deployment instructions
- **[Customer Checklist](CUSTOMER-CHECKLIST.md)** - Step-by-step deployment checklist
- **[Deployment Options](DEPLOYMENT-OPTIONS-COMPARISON.md)** - Compare deployment methods

## 💰 Cost Estimation

### Base Configuration (No Data Explorer)
- Storage Account: ~$50-150/month
- Data Factory: ~$20-100/month
- Key Vault: ~$5/month
- **Total: ~$75-255/month**

### With Data Explorer (Dev SKU)
- Base + Dev Data Explorer: ~$200-400/month
- **Total: ~$275-655/month**

### With Data Explorer (Standard SKU)
- Base + Standard Data Explorer: ~$1,500-3,000/month
- **Total: ~$1,575-3,255/month**

> Actual costs depend on data volume, pipeline runs, and retention settings.

## 🔒 Security Features

- ✅ Managed identities (no passwords)
- ✅ Key Vault for secrets
- ✅ Optional infrastructure encryption
- ✅ Private networking support
- ✅ RBAC-based access control

## 🐛 Troubleshooting

### "Insufficient permissions" error
- Ensure you have both Contributor + User Access Administrator roles
- Or disable managed exports: set `enableManagedExports` to `false`

### Resource name conflicts
- Change the `hubName` parameter to ensure unique names

### No cost data appearing
- Wait at least 24 hours (exports run daily)
- Verify Cost Management exports are created
- Check managed identity has required permissions

[See full troubleshooting guide](DEPLOYMENT-GUIDE.md#troubleshooting)

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
