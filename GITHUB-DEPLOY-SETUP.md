# GitHub Deployment Setup Guide

## Why GitHub for External Customers?

✅ **Public Access** - Anyone can use the deployment link
✅ **No Permissions Needed** - Customers don't need access to your Azure
✅ **Free** - GitHub hosting is free
✅ **Version Control** - Track changes over time
✅ **Standard Practice** - Most Azure quickstart templates use this method

## Step-by-Step Setup

### Step 1: Create GitHub Repository

1. Go to https://github.com
2. Click "New repository"
3. Name: `finops-hub-deployment` (or your choice)
4. Make it **Public** (required for Deploy to Azure button)
5. Click "Create repository"

### Step 2: Upload Your Files

**Option A: Via GitHub Web Interface**

1. In your new repo, click "Add file" → "Upload files"
2. Upload these files:
   - `template.json`
   - `README.md`
   - `DEPLOYMENT-GUIDE.md`
3. Click "Commit changes"

**Option B: Via Git Command Line**

```bash
cd "c:\GitHub\FinOps Hub"

# Initialize git (if not already done)
git init

# Add your files
git add template.json README.md DEPLOYMENT-GUIDE.md

# Commit
git commit -m "Initial FinOps Hub deployment template"

# Connect to GitHub (replace with your repo URL)
git remote add origin https://github.com/YOUR-USERNAME/finops-hub-deployment.git

# Push
git branch -M main
git push -u origin main
```

### Step 3: Get the Raw URL

1. Go to your file on GitHub: `template.json`
2. Click the "Raw" button (top right of file viewer)
3. Copy the URL from your browser

**Example:**
```
https://raw.githubusercontent.com/YOUR-USERNAME/finops-hub-deployment/main/template.json
```

### Step 4: Create Deployment Link

#### **Method 1: Use Online URL Encoder**

1. Go to: https://www.urlencoder.org/
2. Paste your raw URL
3. Click "Encode"
4. Copy the encoded result

**Example:**

**Original:**
```
https://raw.githubusercontent.com/john-doe/finops-hub-deployment/main/template.json
```

**Encoded:**
```
https%3A%2F%2Fraw.githubusercontent.com%2Fjohn-doe%2Ffinops-hub-deployment%2Fmain%2Ftemplate.json
```

#### **Method 2: Manual Encoding (Quick Reference)**

Replace these characters:
- `:` → `%3A`
- `/` → `%2F`
- `.` → `.` (no change)
- `-` → `-` (no change)
- `_` → `_` (no change)

### Step 5: Build Final Deployment URL

```
https://portal.azure.com/#create/Microsoft.Template/uri/[YOUR-ENCODED-URL]
```

**Full Example:**
```
https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjohn-doe%2Ffinops-hub-deployment%2Fmain%2Ftemplate.json
```

### Step 6: Test Your Link

1. Open the link in your browser
2. You should see Azure Portal login
3. After login, template should load
4. Verify parameters appear correctly

### Step 7: Create Customer-Facing Page

Update your GitHub README.md with a "Deploy to Azure" button:

```markdown
# FinOps Hub Deployment

Deploy FinOps Hub to your Azure subscription with one click.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYOUR-USERNAME%2Ffinops-hub-deployment%2Fmain%2Ftemplate.json)

## What Gets Deployed

- Storage Account (Data Lake Gen2)
- Azure Data Factory
- Key Vault
- Managed Identity
- Optional: Azure Data Explorer

## Prerequisites

- Azure subscription
- Contributor + User Access Administrator roles
- 15-45 minutes for deployment

## Cost Estimate

- Basic: ~$75-255/month
- With Data Explorer (Dev): ~$275-655/month
- With Data Explorer (Standard): ~$1,575-3,255/month

## Support

For questions, open an issue in this repository.
```

---

## Create Multiple Deployment Options

### Scenario 1: Small, Medium, Large Options

Create different parameter files:

**Files:**
- `template.parameters.small.json` - No Data Explorer
- `template.parameters.medium.json` - Dev Data Explorer
- `template.parameters.large.json` - Standard Data Explorer

**In your README.md:**

```markdown
# FinOps Hub Deployment Options

## Small Business (<$2M/month costs)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/[ENCODED-TEMPLATE-URL])

**Includes:** Storage + Data Factory + Key Vault
**Cost:** ~$75-255/month

---

## Medium Enterprise ($2-5M/month costs)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/[ENCODED-TEMPLATE-URL])

**Includes:** Small + Dev Data Explorer
**Cost:** ~$275-655/month

---

## Large Enterprise (>$5M/month costs)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/[ENCODED-TEMPLATE-URL])

**Includes:** Small + Standard Data Explorer
**Cost:** ~$1,575-3,255/month
```

---

## Share with Customers

### Method 1: Direct Link via Email

```
Hi [Customer],

Deploy FinOps Hub to your Azure subscription:

https://portal.azure.com/#create/Microsoft.Template/uri/[YOUR-ENCODED-URL]

Prerequisites:
- Azure subscription
- Contributor + User Access Administrator roles

Estimated deployment time: 15-45 minutes

Questions? Reply to this email.

Best regards
```

### Method 2: GitHub Repository Link

```
Hi [Customer],

Access FinOps Hub deployment here:

https://github.com/YOUR-USERNAME/finops-hub-deployment

Click the "Deploy to Azure" button to start.

Documentation included in the repository.

Best regards
```

### Method 3: Custom Landing Page

Host a simple HTML page (on GitHub Pages, Azure Static Web Apps, etc.):

```
https://your-company.com/finops-hub-deploy
```

---

## Maintenance & Updates

### Update Your Template

1. Edit `template.json` or parameters files
2. Commit and push to GitHub
3. **Deployment link stays the same!**
4. Customers always get latest version

### Version Control

For major changes, use branches or tags:

```bash
# Create a v1.0 tag
git tag v1.0
git push origin v1.0

# URL for specific version
https://raw.githubusercontent.com/USER/REPO/v1.0/template.json
```

---

## Security Considerations

### ✅ Safe to Share Publicly

- Template file (no secrets)
- Parameter structure
- Documentation

### ❌ Never Include in Public Repo

- Customer names or data
- Subscription IDs
- Storage account keys
- Connection strings
- Any actual secrets

### 🔒 For Private Templates

If you need to keep templates private:

1. **Private GitHub Repo** - Use GitHub Packages or Releases
2. **Azure Blob Storage** - With SAS tokens
3. **Your Own Web Server** - With authentication

---

## Comparison: GitHub vs Template Specs

| Feature | GitHub (Public) | Template Specs |
|---------|----------------|----------------|
| **Customer Access** | Anyone with link | Requires RBAC permission |
| **Cost** | Free | Free (just Azure storage) |
| **Setup Complexity** | Easy | Medium |
| **Best For** | External customers | Internal/partner deployments |
| **Version Control** | Git built-in | Azure versions |
| **Discovery** | Search engines | Azure Portal only |

---

## Real-World Example

**Microsoft's own quickstart templates:**
https://github.com/Azure/azure-quickstart-templates

They use GitHub + "Deploy to Azure" buttons for all their official templates.

**Example Button in Action:**
![Deploy to Azure Button](https://aka.ms/deploytoazurebutton)

---

## Next Steps

1. ✅ Create GitHub repository
2. ✅ Upload template.json
3. ✅ Get raw URL
4. ✅ Create deployment link
5. ✅ Test the link
6. ✅ Share with customers

Need help with any step? Check the documentation or open an issue.
