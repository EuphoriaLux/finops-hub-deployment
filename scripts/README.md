# FinOps Hub Deployment Scripts & Diagnostic Tools

This directory contains scripts to help diagnose and fix common FinOps Hub deployment issues.

---

## 🔧 Diagnostic Scripts

### `diagnose-deployment-failure.ps1` (PowerShell)

Comprehensive diagnostic tool for troubleshooting failed FinOps Hub deployments.

**Usage:**
```powershell
# Basic usage (auto-detects storage account)
.\diagnose-deployment-failure.ps1 -ResourceGroupName "finhub-rg"

# Specify storage account
.\diagnose-deployment-failure.ps1 `
  -ResourceGroupName "finhub-rg" `
  -StorageAccountName "finopshubstorage"

# Use different subscription
.\diagnose-deployment-failure.ps1 `
  -ResourceGroupName "finhub-rg" `
  -SubscriptionId "your-subscription-id"
```

**Requirements:**
- Azure PowerShell module (Az)
- Authenticated to Azure (`Connect-AzAccount`)

**What it checks:**
- ✅ User permissions (Contributor + User Access Administrator)
- ✅ Resource group and storage account existence
- ✅ Managed identity creation and role assignments
- ✅ RBAC propagation status
- ✅ Deployment script status and logs
- ✅ Network/firewall configuration
- ✅ Recent deployment history

---

### `diagnose-deployment-failure.sh` (Bash/Linux)

Same functionality as PowerShell version, but for Linux/macOS/WSL users.

**Usage:**
```bash
# Make executable (first time only)
chmod +x diagnose-deployment-failure.sh

# Basic usage
./diagnose-deployment-failure.sh -g finhub-rg

# Specify storage account
./diagnose-deployment-failure.sh -g finhub-rg -s finopshubstorage

# Use different subscription
./diagnose-deployment-failure.sh -g finhub-rg -sub your-subscription-id

# Show help
./diagnose-deployment-failure.sh -h
```

**Requirements:**
- Azure CLI (`az`) installed
- Authenticated to Azure (`az login`)
- jq (for JSON parsing) - optional but recommended

---

## 🛠️ Enhanced Deployment Script

### `uploadSettings-enhanced.ps1`

Enhanced version of the uploadSettings deployment script with retry logic and RBAC propagation delay handling.

**Features:**
- ⏰ Initial 60-second wait for RBAC propagation
- 🔄 Automatic retry with exponential backoff (5 attempts)
- 📊 Detailed progress and error messages
- 🔍 RBAC propagation detection
- 📖 Helpful troubleshooting guidance

**When to use:**
- After a failed deployment, for manual recovery
- As a reference for understanding the deployment process
- When customizing the deployment template

**Usage:**
```powershell
# Set required environment variables
$env:storageAccountName = "finopshubstorage"
$env:containerName = "config"
$env:scopes = "/subscriptions/sub-id-1|/subscriptions/sub-id-2"
$env:ftkVersion = "0.36"
$env:msexportRetentionInDays = "0"
$env:ingestionRetentionInMonths = "13"
$env:rawRetentionInDays = "0"
$env:finalRetentionInMonths = "13"

# Run the script
.\uploadSettings-enhanced.ps1
```

**Note**: For most users, simply waiting 10-15 minutes and retrying the deployment is simpler than running this script manually.

---

## 📚 Common Scenarios

### Scenario 1: Deployment Just Failed

**Recommended approach:**
1. ⏰ Wait 10-15 minutes (RBAC propagation)
2. 🔄 Retry the deployment with the same parameters
3. ✅ Should succeed

**Alternative (if you want to diagnose first):**
```powershell
.\diagnose-deployment-failure.ps1 -ResourceGroupName "your-rg"
```

---

### Scenario 2: Multiple Failed Retries

**Recommended approach:**
1. Run diagnostics to identify the issue:
```powershell
.\diagnose-deployment-failure.ps1 -ResourceGroupName "your-rg"
```

2. Review the output - it will identify:
   - Missing permissions
   - Network restrictions
   - RBAC propagation issues
   - Quota problems

3. Fix the identified issues

4. Retry deployment

---

### Scenario 3: Need to Manually Upload Settings

If deployment fails repeatedly and you need to manually configure:

```powershell
# Set environment variables (see uploadSettings-enhanced.ps1 for full list)
$env:storageAccountName = "finopshubstorage"
# ... set other variables ...

# Run enhanced script
.\uploadSettings-enhanced.ps1
```

---

## 🔍 Understanding Diagnostic Output

The diagnostic scripts provide color-coded output:

- 🟢 **[OK]** - Check passed, no issues
- 🟡 **[WARNING]** - Potential issue, may need attention
- 🔴 **[ERROR]** - Problem detected, needs fixing
- ⚪ **[INFO]** - Informational message

### Example Output

```
============================================
 User Permissions Check
============================================
[OK] Has Contributor (or Owner) role
[ERROR] Missing User Access Administrator role
[INFO] You need User Access Administrator or Owner role

============================================
 Managed Identity Check
============================================
[OK] Managed identity found
[OK] Has 'Storage Blob Data Contributor' role
[WARNING] RBAC permissions not yet propagated
[INFO] This is the MOST COMMON cause of deployment failures

Summary and Recommendations:
  - Wait 10-15 minutes for RBAC to propagate, then retry deployment
```

---

## 🆘 Troubleshooting the Diagnostic Scripts

### PowerShell Script Issues

**"Az module not installed"**
```powershell
Install-Module -Name Az -AllowClobber -Scope CurrentUser
```

**"Not authenticated"**
```powershell
Connect-AzAccount
```

**"Cannot find resource group"**
- Verify resource group name spelling
- Ensure you're in the correct subscription

---

### Bash Script Issues

**"Azure CLI not installed"**
```bash
# Install from: https://docs.microsoft.com/cli/azure/install-azure-cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**"Not authenticated"**
```bash
az login
```

**"jq: command not found"**
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Or run without jq (script will work but with less formatting)
```

---

## 📖 Additional Documentation

- [DEPLOYMENT-FIX-GUIDE.md](../DEPLOYMENT-FIX-GUIDE.md) - Complete troubleshooting guide
- [README.md](../README.md) - Main deployment documentation
- [CUSTOMER-CHECKLIST.md](../CUSTOMER-CHECKLIST.md) - Deployment checklist

---

## 💡 Tips

1. **Run diagnostics before asking for help** - The output provides valuable debugging information

2. **Save diagnostic output** - Useful when opening support tickets or issues

3. **Check Azure Service Health** - Sometimes issues are Azure-wide: https://status.azure.com/

4. **Be patient with RBAC** - 10-15 minute waits are normal for first-time deployments

5. **Keep scripts updated** - Pull latest changes from the repository periodically

---

## 🔄 Script Updates

These scripts are actively maintained. If you encounter issues:

1. Check for updated versions in the repository
2. Review the CHANGELOG (if available)
3. Open an issue if you find bugs or have suggestions

---

## 📜 License

Copyright (c) Microsoft Corporation.
Licensed under the MIT License.

See [LICENSE](../LICENSE) file in the repository root for full license information.

---

**Last Updated**: 2025-11-12
