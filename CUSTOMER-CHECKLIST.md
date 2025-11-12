# FinOps Hub Deployment - Customer Checklist

## Before You Deploy

### ✅ Prerequisites Check

- [ ] I have an active Azure subscription
- [ ] I have **Contributor** role on my target subscription or resource group
- [ ] I have **User Access Administrator** role (needed for managed exports)
- [ ] I have Azure CLI 2.50+ installed **OR** Azure PowerShell Az module 10.0+ installed
- [ ] I have reviewed the `template.parameters.json` file
- [ ] I have confirmed the deployment region is correct
- [ ] I have confirmed the hub name is unique

### ✅ Decision Points

#### 1. Do I need Azure Data Explorer?
- [ ] **NO** - My monthly Azure costs are under $2M → Leave `dataExplorerName` empty
- [ ] **YES (Dev)** - My costs are $2-5M/month → Use Dev SKU
- [ ] **YES (Prod)** - My costs are over $5M/month → Use Standard SKU

#### 2. What network security level do I need?
- [ ] **Public Access** - Standard deployment, internet accessible
- [ ] **Private Network** - Restricted access via VNet (set `enablePublicAccess: false`)

#### 3. What data retention do I need?
- [ ] **Default** - 13 months of cost data (recommended)
- [ ] **Custom** - Adjust retention parameters based on compliance needs

#### 4. What Azure scopes should be monitored?
- [ ] I have a list of subscription IDs to monitor
- [ ] I have billing account IDs (if applicable)
- [ ] I have added them to `scopesToMonitor` parameter

## Deployment Steps

### Step 1: Prepare Your Environment

**Azure CLI:**
```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "YOUR-SUBSCRIPTION-ID"

# Create resource group
az group create --name "rg-finops-hub-prod" --location "eastus"
```

**PowerShell:**
```powershell
# Login to Azure
Connect-AzAccount

# Set your subscription
Set-AzContext -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# Create resource group
New-AzResourceGroup -Name "rg-finops-hub-prod" -Location "eastus"
```

- [ ] Successfully logged in to Azure
- [ ] Subscription is set correctly
- [ ] Resource group is created

### Step 2: Review Parameters

Open `template.parameters.json` and verify:

- [ ] `hubName` is set to your desired value
- [ ] `location` matches your resource group location
- [ ] `tags` contain your organization's required tags
- [ ] `dataExplorerName` is configured (or empty if not needed)
- [ ] `scopesToMonitor` contains your subscription/billing IDs
- [ ] `enablePublicAccess` matches your security requirements

### Step 3: Deploy Template

**Option A - Azure CLI:**
```bash
az deployment group create \
  --name "finops-hub-deployment" \
  --resource-group "rg-finops-hub-prod" \
  --template-file "template.json" \
  --parameters "@template.parameters.json"
```

**Option B - PowerShell:**
```powershell
New-AzResourceGroupDeployment `
  -Name "finops-hub-deployment" `
  -ResourceGroupName "rg-finops-hub-prod" `
  -TemplateFile "template.json" `
  -TemplateParameterFile "template.parameters.json"
```

**Option C - Azure Portal:**
1. Go to portal.azure.com
2. Search "Deploy a custom template"
3. Upload `template.json`
4. Upload/paste `template.parameters.json`
5. Click Deploy

- [ ] Deployment command executed
- [ ] Deployment is running (check Azure Portal)
- [ ] Estimated wait time: 15-45 minutes

### Step 4: Monitor Deployment

Check deployment status:

**Azure CLI:**
```bash
az deployment group show \
  --name "finops-hub-deployment" \
  --resource-group "rg-finops-hub-prod" \
  --query "properties.provisioningState"
```

**PowerShell:**
```powershell
Get-AzResourceGroupDeployment `
  -ResourceGroupName "rg-finops-hub-prod" `
  -Name "finops-hub-deployment" |
  Select-Object ProvisioningState
```

- [ ] Deployment status is "Running"
- [ ] No errors in Azure Portal Activity Log
- [ ] Waiting for completion...

## Post-Deployment

### Step 5: Verify Resources

List deployed resources:

```bash
az resource list --resource-group "rg-finops-hub-prod" --output table
```

You should see:
- [ ] Storage Account (st*)
- [ ] Data Factory (adf-*)
- [ ] Key Vault (kv-*)
- [ ] Managed Identity
- [ ] Data Explorer (if enabled)
- [ ] Virtual Network (if private networking enabled)

### Step 6: Retrieve Deployment Outputs

**Azure CLI:**
```bash
az deployment group show \
  --name "finops-hub-deployment" \
  --resource-group "rg-finops-hub-prod" \
  --query properties.outputs
```

Save these values:
- [ ] `managedIdentityId` - _______________________________
- [ ] `managedIdentityTenantId` - _______________________________
- [ ] `storageAccountName` - _______________________________
- [ ] `dataFactoryName` - _______________________________

### Step 7: Configure Cost Management Exports (if using managed exports)

1. [ ] Go to Azure Cost Management
2. [ ] Navigate to Exports
3. [ ] Verify exports were automatically created (if `enableManagedExports: true`)
4. [ ] If exports weren't created, grant the managed identity permissions manually

### Step 8: Verify Data Ingestion

Wait 24-48 hours, then check:

- [ ] Storage account has data in `msexports` container
- [ ] Data Factory pipelines have run successfully
- [ ] `ingestion` container contains processed data
- [ ] Data Explorer has data (if enabled)

## Troubleshooting

### Common Issues

**Deployment Script Failure (uploadSettings) - MOST COMMON:**

Symptoms:
- Error: `ResourceDeploymentFailure` for deployment script
- Error message mentions "Authorization failed", "Forbidden", or "403"
- Happens during "UpdateSettings" or "Storage" phase

Solution:
- [ ] **Wait 10-15 minutes** after the initial failure
- [ ] **Retry the deployment** with the same parameters
- [ ] The second attempt usually succeeds (RBAC roles have propagated)

Why: Azure RBAC role assignments take 5-10 minutes to propagate. The deployment creates a managed identity and assigns permissions, but the script runs before they're fully active.

**Run Diagnostics:**
```powershell
# PowerShell - from the scripts directory
.\diagnose-deployment-failure.ps1 -ResourceGroupName "rg-finops-hub-prod"
```

```bash
# Bash/Linux - from the scripts directory
./diagnose-deployment-failure.sh -g rg-finops-hub-prod
```

The diagnostic script will check:
- [ ] User has required permissions (Contributor + User Access Administrator)
- [ ] Managed identity was created successfully
- [ ] Role assignments are in place
- [ ] RBAC permissions have propagated
- [ ] Storage account is accessible
- [ ] Detailed error logs

**Deployment fails with permission error:**
- [ ] Verified I have **Contributor** role
- [ ] Verified I have **User Access Administrator** role
- [ ] Both roles are required for managed identity role assignments
- [ ] Alternative: Set `enableManagedExports: false` and create exports manually

**Resource name already exists:**
- [ ] Changed `hubName` parameter to a unique value
- [ ] Re-run deployment

**Data Explorer deployment fails:**
- [ ] Verified subscription has quota for Data Explorer
- [ ] Requested quota increase if needed
- [ ] Alternative: Deploy without Data Explorer initially

**Network/Firewall Restrictions:**
- [ ] Storage account firewall may block deployment scripts
- [ ] Temporarily allow public access during deployment
- [ ] Add Azure service IPs to firewall allowlist
- [ ] Check if private networking is causing issues

**No cost data appearing:**
- [ ] Waited at least 24 hours (exports run daily)
- [ ] Verified `scopesToMonitor` contains correct scope IDs
- [ ] Checked Cost Management exports are created and running
- [ ] Verified managed identity has required permissions

## Cost Monitoring

### Expected Monthly Costs

Based on your configuration:

**Basic (No Data Explorer):**
- Storage: ~$50-150
- Data Factory: ~$20-100
- Key Vault: ~$5
- **Total: ~$75-255/month**

**With Dev Data Explorer:**
- Add: ~$200-400
- **Total: ~$275-655/month**

**With Standard Data Explorer:**
- Add: ~$1,500-3,000
- **Total: ~$1,575-3,255/month**

- [ ] I understand the expected costs
- [ ] I have set up Azure budget alerts
- [ ] I have configured cost allocation tags

## Next Steps

### Week 1
- [ ] Monitor resource deployment and health
- [ ] Verify first cost data export completes
- [ ] Check Data Factory pipeline runs
- [ ] Review Azure Monitor logs for errors

### Week 2-4
- [ ] Validate data accuracy against Azure Cost Management
- [ ] Configure Power BI reports (if using Data Explorer)
- [ ] Set up alerting for pipeline failures
- [ ] Document any custom configurations

### Month 2+
- [ ] Review data retention settings
- [ ] Optimize Data Explorer queries
- [ ] Implement cost allocation strategies
- [ ] Train team on FinOps Hub usage

## Support & Documentation

- [ ] I have read the `DEPLOYMENT-GUIDE.md`
- [ ] I have bookmarked https://aka.ms/finops/hub
- [ ] I know who to contact for support
- [ ] I have documented my custom configuration

## Sign-Off

**Deployment Information:**
- Deployment Date: _______________
- Resource Group: _______________
- Hub Name: _______________
- Deployed By: _______________

**Validation:**
- [ ] All resources deployed successfully
- [ ] Cost data is flowing correctly
- [ ] Team has been trained
- [ ] Documentation is complete

---

**Need Help?** Refer to `DEPLOYMENT-GUIDE.md` or contact your solution provider.
