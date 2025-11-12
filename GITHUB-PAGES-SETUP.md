# GitHub Pages Setup Guide

This guide will help you enable the documentation website for your FinOps Hub deployment repository.

## Quick Setup (5 minutes)

### Step 1: Push the docs folder to GitHub

```bash
# From your repository root
git add docs/
git commit -m "Add GitHub Pages documentation site"
git push origin main
```

### Step 2: Enable GitHub Pages

1. Go to your repository on GitHub: `https://github.com/[your-username]/finops-hub-deployment`
2. Click the **Settings** tab
3. In the left sidebar, click **Pages**
4. Under "Build and deployment":
   - **Source:** Select "Deploy from a branch"
   - **Branch:** Select `main`
   - **Folder:** Select `/docs`
5. Click **Save**

### Step 3: Wait for deployment

GitHub will automatically build and deploy your site. This takes 1-3 minutes.

You'll see a message at the top of the Pages settings:
> Your site is live at `https://[your-username].github.io/finops-hub-deployment/`

### Step 4: Update README links

Replace `[your-username]` in the following files with your actual GitHub username:

1. **README.md** - Line 91: Update the documentation site URL
2. **docs/index.html** - No changes needed (uses relative paths)

## Verification

1. Visit your live site: `https://[your-username].github.io/finops-hub-deployment/`
2. Verify all sections are visible:
   - Overview
   - Deployment
   - Export Setup
   - CSP Subscriptions
   - Troubleshooting
   - Resources
3. Test navigation links in the top menu
4. Test responsiveness on mobile devices

## Customization

### Update Site Content

Edit `docs/index.html` to customize:
- Subscription links (replace placeholders with actual subscription IDs)
- Organization-specific details
- Contact information
- Additional sections

### Change Color Scheme

Modify CSS variables in `docs/index.html` (lines 11-22):

```css
:root {
    --primary-color: #0078d4;      /* Change primary blue */
    --secondary-color: #50e6ff;    /* Change accent color */
    --success-color: #10893e;      /* Change success green */
    --warning-color: #faa21b;      /* Change warning orange */
    --danger-color: #e81123;       /* Change danger red */
}
```

### Add Custom Domain (Optional)

1. Purchase a domain from a registrar
2. In GitHub Pages settings, add your custom domain
3. Configure DNS with your registrar:
   - Add a CNAME record pointing to `[your-username].github.io`
4. GitHub will automatically provision SSL certificate

## Troubleshooting

### Site not appearing after 10 minutes

1. Check the **Actions** tab for build errors
2. Verify `/docs` folder exists in your `main` branch
3. Ensure `index.html` is directly in the `/docs` folder (not in a subfolder)

### 404 errors when accessing the site

- Verify you pushed the `docs/` folder to GitHub
- Check that the branch and folder settings in Pages are correct
- Wait a few more minutes (initial deployment can take up to 10 minutes)

### Changes not appearing

- GitHub Pages caches content for a few minutes
- Hard refresh your browser: `Ctrl + Shift + R` (Windows/Linux) or `Cmd + Shift + R` (Mac)
- Check the Actions tab to see if a new deployment is in progress

## Advanced: Jekyll Theme (Optional)

The site currently uses pure HTML. If you want to use Jekyll (GitHub's static site generator):

1. Edit `docs/_config.yml` to customize Jekyll settings
2. Convert `index.html` to `index.md` (Markdown format)
3. Use Jekyll layouts and includes for better organization

**Note:** The current HTML approach is simpler and doesn't require Jekyll knowledge.

## Maintenance

### Updating Documentation

1. Edit `docs/index.html` locally
2. Test changes by opening the file in a browser
3. Commit and push changes:
   ```bash
   git add docs/index.html
   git commit -m "Update documentation"
   git push origin main
   ```
4. GitHub automatically redeploys (takes 1-2 minutes)

### Analytics (Optional)

Add Google Analytics or other tracking:

1. Get your tracking code
2. Add it to `docs/index.html` before the closing `</head>` tag
3. Commit and push

## Security

- GitHub Pages sites are public by default
- Don't include sensitive information (credentials, internal URLs, etc.)
- The current documentation contains only public information

## Resources

- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Custom Domain Setup](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)
- [Jekyll Documentation](https://jekyllrb.com/docs/) (if using Jekyll)

---

**Need Help?**

- GitHub Pages issues: [GitHub Support](https://support.github.com/)
- Documentation content issues: Open an issue in this repository
