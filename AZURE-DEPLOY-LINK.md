# Azure "Deploy to Azure" Button Setup

## Overview

Instead of sending files, you can host your template and parameters online and provide customers a **one-click deployment link** that opens directly in Azure Portal.

## Option 1: GitHub-Hosted Deployment (Recommended)

### Step 1: Upload to GitHub Repository

1. Create a public GitHub repository (or use an existing one)
2. Upload these files:
   - `template.json`
   - `template.parameters.json`

### Step 2: Get Raw File URLs

After uploading to GitHub, get the "raw" URLs:

**Example:**
- Template: `https://raw.githubusercontent.com/YOUR-ORG/finops-hub/main/template.json`
- Parameters: `https://raw.githubusercontent.com/YOUR-ORG/finops-hub/main/template.parameters.json`

### Step 3: Create Deployment Link

Use this format:

```
https://portal.azure.com/#create/Microsoft.Template/uri/[ENCODED-TEMPLATE-URL]/createUIDefinitionUri/[ENCODED-PARAMETERS-URL]
```

**Simplified version (template only):**
```
https://portal.azure.com/#create/Microsoft.Template/uri/[ENCODED-TEMPLATE-URL]
```

### Step 4: URL Encode Your GitHub URLs

**Template URL (before encoding):**
```
https://raw.githubusercontent.com/YOUR-ORG/finops-hub/main/template.json
```

**After URL encoding:**
```
https%3A%2F%2Fraw.githubusercontent.com%2FYOUR-ORG%2Ffinops-hub%2Fmain%2Ftemplate.json
```

**Final Deploy Link:**
```
https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYOUR-ORG%2Ffinops-hub%2Fmain%2Ftemplate.json
```

### Step 5: Create Markdown Button

Add this to your README or documentation:

```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYOUR-ORG%2Ffinops-hub%2Fmain%2Ftemplate.json)
```

**Visual Button:**

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/YOUR-URL-HERE)

---

## Option 2: Azure Blob Storage Hosted (Private)

For private/confidential templates, host in Azure Blob Storage with SAS tokens.

### Step 1: Upload to Azure Storage

```bash
# Create storage account
az storage account create \
  --name stfinopstemplates \
  --resource-group rg-templates \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name templates \
  --account-name stfinopstemplates \
  --public-access blob

# Upload template
az storage blob upload \
  --account-name stfinopstemplates \
  --container-name templates \
  --name template.json \
  --file template.json

# Upload parameters
az storage blob upload \
  --account-name stfinopstemplates \
  --container-name templates \
  --name template.parameters.json \
  --file template.parameters.json
```

### Step 2: Generate SAS Token (Optional, for private access)

```bash
# Generate SAS token (valid for 1 year)
az storage blob generate-sas \
  --account-name stfinopstemplates \
  --container-name templates \
  --name template.json \
  --permissions r \
  --expiry 2026-12-31 \
  --https-only \
  --output tsv
```

### Step 3: Create Deployment Link

**Blob URL:**
```
https://stfinopstemplates.blob.core.windows.net/templates/template.json
```

**URL Encoded:**
```
https%3A%2F%2Fstfinopstemplates.blob.core.windows.net%2Ftemplates%2Ftemplate.json
```

**Final Link:**
```
https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fstfinopstemplates.blob.core.windows.net%2Ftemplates%2Ftemplate.json
```

---

## Option 3: Azure Template Specs (Most Professional)

**Template Specs** store templates directly in Azure for enterprise deployments.

### Step 1: Create Template Spec

```bash
# Create resource group for template specs
az group create \
  --name rg-template-specs \
  --location eastus

# Create template spec
az ts create \
  --name finops-hub-custom \
  --version "1.0" \
  --resource-group rg-template-specs \
  --location eastus \
  --template-file template.json \
  --display-name "FinOps Hub - Custom Deployment" \
  --description "Customized FinOps Hub deployment for enterprise customers"
```

**PowerShell:**
```powershell
# Create template spec
New-AzTemplateSpec `
  -Name finops-hub-custom `
  -Version "1.0" `
  -ResourceGroupName rg-template-specs `
  -Location eastus `
  -TemplateFile template.json `
  -DisplayName "FinOps Hub - Custom Deployment" `
  -Description "Customized FinOps Hub deployment for enterprise customers"
```

### Step 2: Get Template Spec ID

```bash
az ts show \
  --name finops-hub-custom \
  --version "1.0" \
  --resource-group rg-template-specs \
  --query id -o tsv
```

**Result:**
```
/subscriptions/YOUR-SUB-ID/resourceGroups/rg-template-specs/providers/Microsoft.Resources/templateSpecs/finops-hub-custom/versions/1.0
```

### Step 3: Create Deployment Link

**Format:**
```
https://portal.azure.com/#create/Microsoft.Template/templateSpecId/%2Fsubscriptions%2FYOUR-SUB-ID%2FresourceGroups%2Frg-template-specs%2Fproviders%2FMicrosoft.Resources%2FtemplateSpecs%2Ffinops-hub-custom%2Fversions%2F1.0
```

### Step 4: Deploy Template Spec (Customer)

**Azure CLI:**
```bash
az deployment group create \
  --name finops-hub-deployment \
  --resource-group rg-finops-hub-prod \
  --template-spec "/subscriptions/YOUR-SUB-ID/resourceGroups/rg-template-specs/providers/Microsoft.Resources/templateSpecs/finops-hub-custom/versions/1.0"
```

**PowerShell:**
```powershell
New-AzResourceGroupDeployment `
  -Name finops-hub-deployment `
  -ResourceGroupName rg-finops-hub-prod `
  -TemplateSpecId "/subscriptions/YOUR-SUB-ID/resourceGroups/rg-template-specs/providers/Microsoft.Resources/templateSpecs/finops-hub-custom/versions/1.0"
```

---

## Option 4: Custom Web Portal with ARM Links

Create a simple web page with multiple pre-configured deployment options.

### Example HTML Page

```html
<!DOCTYPE html>
<html>
<head>
    <title>FinOps Hub - Custom Deployments</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; }
        .deploy-option { border: 1px solid #ddd; padding: 20px; margin: 20px 0; border-radius: 5px; }
        .deploy-button { background: #0078d4; color: white; padding: 10px 20px; text-decoration: none; border-radius: 3px; display: inline-block; margin-top: 10px; }
        .deploy-button:hover { background: #106ebe; }
    </style>
</head>
<body>
    <h1>FinOps Hub - Custom Deployments</h1>

    <div class="deploy-option">
        <h2>🏢 Small Business (~$100K-$2M/month)</h2>
        <p>Basic deployment without Azure Data Explorer</p>
        <ul>
            <li>Storage + Data Factory + Key Vault</li>
            <li>Estimated cost: $75-255/month</li>
            <li>Deployment time: ~15 minutes</li>
        </ul>
        <a href="https://portal.azure.com/#create/Microsoft.Template/uri/YOUR-SMALL-TEMPLATE-URL" class="deploy-button">
            Deploy to Azure
        </a>
    </div>

    <div class="deploy-option">
        <h2>🏭 Medium Enterprise ($2M-$5M/month)</h2>
        <p>Deployment with Dev Azure Data Explorer</p>
        <ul>
            <li>Storage + Data Factory + Key Vault + Data Explorer (Dev)</li>
            <li>Estimated cost: $275-655/month</li>
            <li>Deployment time: ~30 minutes</li>
        </ul>
        <a href="https://portal.azure.com/#create/Microsoft.Template/uri/YOUR-MEDIUM-TEMPLATE-URL" class="deploy-button">
            Deploy to Azure
        </a>
    </div>

    <div class="deploy-option">
        <h2>🌐 Large Enterprise (>$5M/month)</h2>
        <p>Full deployment with Standard Azure Data Explorer</p>
        <ul>
            <li>Storage + Data Factory + Key Vault + Data Explorer (Standard)</li>
            <li>Estimated cost: $1,575-3,255/month</li>
            <li>Deployment time: ~45 minutes</li>
        </ul>
        <a href="https://portal.azure.com/#create/Microsoft.Template/uri/YOUR-LARGE-TEMPLATE-URL" class="deploy-button">
            Deploy to Azure
        </a>
    </div>

    <div class="deploy-option">
        <h2>🔒 High Security Deployment</h2>
        <p>Private networking with infrastructure encryption</p>
        <ul>
            <li>All resources + Private Endpoints + VNet</li>
            <li>Infrastructure encryption enabled</li>
            <li>No public access</li>
        </ul>
        <a href="https://portal.azure.com/#create/Microsoft.Template/uri/YOUR-SECURE-TEMPLATE-URL" class="deploy-button">
            Deploy to Azure
        </a>
    </div>
</body>
</html>
```

Host this on:
- GitHub Pages (free)
- Azure Static Web Apps (free tier)
- Azure Blob Storage with static website hosting

---

## Comparison: Which Option to Use?

| Option | Pros | Cons | Best For |
|--------|------|------|----------|
| **GitHub** | Free, simple, public | Files are public | Open-source, community |
| **Blob Storage** | Private with SAS, cheap | Requires storage account | Private templates |
| **Template Specs** | Enterprise-grade, versioning | Requires Azure subscription | Multi-customer deployments |
| **Custom Portal** | Professional, multiple options | Requires web hosting | Sales/consulting firms |

---

## Quick Start: GitHub Method (5 minutes)

### 1. Create GitHub Repo

```bash
# Initialize repo
cd "c:\GitHub\FinOps Hub"
git init
git add template.json template.parameters.json README.md
git commit -m "FinOps Hub deployment templates"

# Push to GitHub
git remote add origin https://github.com/YOUR-USERNAME/finops-hub-deploy.git
git push -u origin main
```

### 2. Get Raw URL

Go to your file on GitHub, click "Raw", copy URL:
```
https://raw.githubusercontent.com/YOUR-USERNAME/finops-hub-deploy/main/template.json
```

### 3. URL Encode

Use online tool: https://www.urlencoder.org/
Or use PowerShell:
```powershell
$url = "https://raw.githubusercontent.com/YOUR-USERNAME/finops-hub-deploy/main/template.json"
[System.Web.HttpUtility]::UrlEncode($url)
```

### 4. Create Deploy Link

```
https://portal.azure.com/#create/Microsoft.Template/uri/[YOUR-ENCODED-URL]
```

### 5. Share with Customer

**Via Email:**
```
Click here to deploy FinOps Hub to your Azure subscription:
https://portal.azure.com/#create/Microsoft.Template/uri/...
```

**Via Markdown:**
```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](YOUR-DEPLOY-LINK)
```

---

## Advanced: Pre-fill Parameters in URL

You can also pre-fill parameter values in the URL (less common):

```
https://portal.azure.com/#create/Microsoft.Template/uri/[TEMPLATE-URL]/parameters/%7B%22hubName%22%3A%7B%22value%22%3A%22customer-hub%22%7D%7D
```

However, this gets complex. Better to create multiple parameter files for different customer sizes.

---

## Security Considerations

### Public GitHub
- ✅ Template is safe to share (no secrets)
- ❌ Don't include customer-specific data
- ❌ Don't include secure strings or keys

### Private Storage
- ✅ Use SAS tokens with expiration
- ✅ Enable HTTPS only
- ✅ Limit permissions to read-only

### Template Specs
- ✅ Built-in RBAC
- ✅ Version control
- ✅ Audit trail
- ⚠️ Customer needs permission to your subscription

---

## Example: Complete GitHub Setup

I can help you set this up now. Would you like me to:

1. ✅ Create a GitHub repository structure
2. ✅ Generate the Deploy to Azure button
3. ✅ Create a landing page with deployment options
4. ✅ Set up multiple parameter files for different scenarios

Let me know and I'll create everything you need!
