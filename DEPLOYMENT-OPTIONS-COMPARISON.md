# Deployment Link Options - Quick Comparison

## Which Method Should You Use?

### 🎯 Quick Decision Guide

**Choose based on your scenario:**

| Your Situation | Best Method | Why |
|----------------|-------------|-----|
| Selling to **external customers** | **GitHub Public** | No Azure permissions needed |
| Working with **partners** (same org) | **Template Specs** | Better control, versioning |
| **Internal** company deployments | **Template Specs** | Enterprise features, governance |
| **Open source** / community | **GitHub Public** | Discoverability, contributions |
| Need **private** templates | **Blob Storage + SAS** | Controlled access with expiration |

---

## Method 1: GitHub Public Repository

### ✅ Pros
- **No customer permissions needed** - Anyone can use the link
- **Free** - GitHub hosting costs nothing
- **Easy to share** - Just send a URL
- **Version control** - Built-in Git history
- **Discoverable** - Appears in search engines
- **Standard practice** - Microsoft uses this for all quickstarts

### ❌ Cons
- **Template is public** - Anyone can see your template
- **No access control** - Can't restrict who deploys
- **Limited analytics** - Can't see who's using it

### 📋 Best For
- ✅ External customers (different companies)
- ✅ Sales/consulting where customers self-deploy
- ✅ Open-source projects
- ✅ Marketing/lead generation

### 🔗 Customer Experience
1. Click your link
2. Opens Azure Portal (must login)
3. Fill in parameters in their subscription
4. Deploy

**Customer sees:** Azure Portal with pre-loaded template
**Customer needs:** Only Azure subscription + permissions in their own tenant

---

## Method 2: Azure Template Specs

### ✅ Pros
- **Enterprise features** - Version management, RBAC
- **Private** - Only authorized users can access
- **Audit trail** - See who deployed what
- **Integrated** - Native Azure resource
- **No external hosting** - Everything in Azure

### ❌ Cons
- **Requires permissions** - Customer needs RBAC access to your subscription
- **Cross-tenant complexity** - Hard to share with external companies
- **Less discoverable** - Not indexed by search engines

### 📋 Best For
- ✅ Internal company deployments (same tenant)
- ✅ Partner deployments (B2B with Azure integration)
- ✅ Managed service providers (MSPs)
- ✅ Enterprise governance scenarios

### 🔗 Customer Experience
1. Click your link (or you deploy for them)
2. Opens Azure Portal (must login)
3. **Requires:** Guest access or permission to your subscription
4. Fill in parameters
5. Deploy

**Customer sees:** Azure Portal deployment
**Customer needs:** Azure subscription + RBAC permission to your Template Spec

---

## Method 3: Azure Blob Storage (Private)

### ✅ Pros
- **Private with control** - Use SAS tokens with expiration
- **No GitHub needed** - All in Azure
- **Temporary access** - SAS tokens expire
- **Cost effective** - Pennies per month

### ❌ Cons
- **Manual token management** - Need to generate/share SAS tokens
- **Token expiration** - Links stop working after expiry
- **No version control** - Manual file management

### 📋 Best For
- ✅ Temporary customer access (trial/POC)
- ✅ NDA/confidential templates
- ✅ Time-limited deployments
- ✅ Partners requiring private access

### 🔗 Customer Experience
1. Click your link (includes SAS token)
2. Opens Azure Portal
3. Fill in parameters
4. Deploy

**Customer sees:** Azure Portal with template
**Customer needs:** Azure subscription only (SAS token in URL provides access)

---

## Side-by-Side Comparison

| Feature | GitHub Public | Template Specs | Blob Storage |
|---------|--------------|----------------|--------------|
| **Setup Time** | 5 minutes | 2 minutes | 5 minutes |
| **Cost** | Free | Free | ~$0.50/month |
| **Customer Permissions** | None needed | RBAC required | None (SAS token) |
| **Cross-Tenant** | ✅ Easy | ❌ Complex | ✅ Easy |
| **Version Control** | ✅ Git | ✅ Azure versions | ❌ Manual |
| **Access Control** | ❌ Public | ✅ RBAC | ⚠️ SAS expiration |
| **Discoverability** | ✅ Search engines | ❌ Private | ❌ Private |
| **Link Expiration** | ✅ Never | ✅ Never | ⚠️ SAS token expiry |
| **Analytics** | ❌ Limited | ✅ Azure logs | ❌ Limited |
| **Audit Trail** | ⚠️ Git commits | ✅ Azure logs | ⚠️ Storage logs |

---

## Real-World Examples

### Example 1: Software Vendor Selling SaaS

**Scenario:** You sell FinOps Hub to 100+ external customers

**Recommended:** GitHub Public
- One link works for everyone
- No permission management
- Customers self-deploy in their tenants
- Free to operate

**Link:** `https://portal.azure.com/#create/Microsoft.Template/uri/...`

---

### Example 2: Consulting Firm with Partners

**Scenario:** You deploy for 10-20 partner companies regularly

**Recommended:** Template Specs
- Store multiple versions (dev/prod)
- Control who can deploy
- Audit who deployed what
- Enterprise governance

**Link:** `https://portal.azure.com/#create/Microsoft.Template/templateSpecId/...`

---

### Example 3: POC for Prospect Under NDA

**Scenario:** Prospect wants to try FinOps Hub, but you can't share publicly

**Recommended:** Blob Storage + SAS
- Generate 30-day SAS token
- Send private link
- Link expires automatically
- Template remains confidential

**Link:** `https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fstorage.blob.core.windows.net%2F...%3Fsv=2023...`

---

## Security Comparison

### GitHub Public
- ⚠️ Template is visible to everyone
- ✅ No credentials exposed (template has no secrets)
- ✅ Customer deploys in their own tenant
- ✅ No access to customer resources

### Template Specs
- ✅ Template is private
- ⚠️ Customer needs guest access to your tenant (or you deploy for them)
- ✅ Full RBAC control
- ✅ Azure AD integrated

### Blob Storage
- ✅ Template is private (with SAS)
- ✅ Customer doesn't need access to your tenant
- ⚠️ SAS token in URL could leak
- ⚠️ Anyone with URL can access (until expiry)

---

## Cost Comparison

### GitHub Public
```
Cost: $0/month (free)
```

### Template Specs
```
Cost: $0/month (just metadata, negligible storage)
```

### Blob Storage
```
Storage Account: $0.018/GB/month
Template file (2.3MB): ~$0.00004/month
Transactions: ~$0.01/month
Total: ~$0.01-0.50/month
```

---

## My Recommendation for Your Use Case

Based on your question ("send link to customer for custom deployment"):

### 🏆 **Use GitHub Public Repository**

**Why:**
1. ✅ External customers don't need access to your Azure
2. ✅ One link works for all customers
3. ✅ Free and easy to maintain
4. ✅ Standard practice (Microsoft does this)
5. ✅ Customers can review template before deploying

**How:**
1. Create public GitHub repo
2. Upload `template.json`
3. Get raw URL
4. Encode it
5. Create: `https://portal.azure.com/#create/Microsoft.Template/uri/[ENCODED-URL]`
6. Share link with customers

### Template is Already Safe to Share
Your `template.json`:
- ✅ No customer data
- ✅ No secrets or keys
- ✅ No subscription IDs
- ✅ Just infrastructure definition
- ✅ Customers fill in their own parameters

---

## Quick Start Commands

### GitHub (Recommended)

```bash
# 1. Create repo on GitHub.com (via web interface)

# 2. Push your template
cd "c:\GitHub\FinOps Hub"
git init
git add template.json README.md
git commit -m "FinOps Hub deployment"
git remote add origin https://github.com/YOUR-USER/finops-hub-deploy.git
git push -u origin main

# 3. Get raw URL (via GitHub web interface)
# 4. Encode URL at https://www.urlencoder.org/
# 5. Create link:
#    https://portal.azure.com/#create/Microsoft.Template/uri/[ENCODED-URL]
```

### Template Specs (For Internal Use)

```bash
# One command
az ts create \
  --name finops-hub-custom \
  --version "1.0" \
  --resource-group rg-template-specs \
  --location eastus \
  --template-file template.json
```

### Blob Storage (For Private/NDA)

```bash
# Create storage
az storage account create --name stfinopstemplates --resource-group rg-templates --sku Standard_LRS

# Upload
az storage blob upload --account-name stfinopstemplates --container-name templates --name template.json --file template.json

# Generate SAS (30 days)
az storage blob generate-sas --account-name stfinopstemplates --container-name templates --name template.json --permissions r --expiry 2025-12-31 --https-only
```

---

## Need Help Deciding?

Ask yourself:

1. **Are customers in different Azure tenants?**
   - YES → GitHub Public
   - NO → Template Specs

2. **Is template confidential?**
   - YES → Blob Storage + SAS or Template Specs
   - NO → GitHub Public

3. **Need access control?**
   - YES → Template Specs
   - NO → GitHub Public

4. **Selling to many customers?**
   - YES → GitHub Public
   - NO → Any method works

**90% of the time: GitHub Public is the right answer.**
