/**
 * Export Configuration Wizard
 * Generates PowerShell scripts or portal instructions for Cost Management exports
 */

const ExportWizard = {
  // Initialize the wizard
  init: function() {
    this.setupEventListeners();
    this.loadSavedConfig();
  },

  // Setup event listeners
  setupEventListeners: function() {
    const generateBtn = document.getElementById('generateExportBtn');
    const copyBtn = document.getElementById('copyExportBtn');
    const hubNameInput = document.getElementById('wizardHubName');
    const subsInput = document.getElementById('wizardSubscriptionIds');

    if (generateBtn) {
      generateBtn.addEventListener('click', () => this.generateConfiguration());
    }

    if (copyBtn) {
      copyBtn.addEventListener('click', () => this.copyToClipboard());
    }

    // Real-time validation
    if (hubNameInput) {
      hubNameInput.addEventListener('input', FinOpsUtils.debounce(() => {
        this.validateHubName();
      }, 500));
    }

    if (subsInput) {
      subsInput.addEventListener('input', FinOpsUtils.debounce(() => {
        this.validateSubscriptions();
      }, 500));
    }

    // Radio button change
    const radioButtons = document.querySelectorAll('input[name="outputType"]');
    radioButtons.forEach(radio => {
      radio.addEventListener('change', () => {
        if (document.getElementById('wizardOutput').style.display !== 'none') {
          this.generateConfiguration();
        }
      });
    });
  },

  // Load saved configuration from localStorage
  loadSavedConfig: function() {
    try {
      const saved = localStorage.getItem('finops-wizard-config');
      if (saved) {
        const config = JSON.parse(saved);
        const hubNameInput = document.getElementById('wizardHubName');
        if (hubNameInput && config.hubName) {
          hubNameInput.value = config.hubName;
        }
      }
    } catch (e) {
      console.warn('Could not load saved config', e);
    }
  },

  // Save configuration to localStorage
  saveConfig: function(config) {
    try {
      localStorage.setItem('finops-wizard-config', JSON.stringify(config));
    } catch (e) {
      console.warn('Could not save config', e);
    }
  },

  // Validate hub name
  validateHubName: function() {
    const input = document.getElementById('wizardHubName');
    if (!input) return false;

    const result = FinOpsUtils.validateHubName(input.value);

    if (result.valid) {
      FinOpsUtils.showSuccess(input);
      return true;
    } else if (input.value.length > 0) {
      FinOpsUtils.showError(input, result.message);
      return false;
    } else {
      FinOpsUtils.clearError(input);
      return false;
    }
  },

  // Validate subscription IDs
  validateSubscriptions: function() {
    const input = document.getElementById('wizardSubscriptionIds');
    if (!input) return false;

    const subscriptions = FinOpsUtils.parseSubscriptionIds(input.value);

    if (subscriptions.length === 0 && input.value.length > 0) {
      FinOpsUtils.showError(input, 'No valid subscription IDs found');
      return false;
    }

    if (subscriptions.length > 0) {
      const invalidSubs = subscriptions.filter(sub => !FinOpsUtils.validateSubscriptionId(sub));

      if (invalidSubs.length > 0) {
        FinOpsUtils.showError(input, `${invalidSubs.length} invalid subscription ID(s)`);
        return false;
      }

      FinOpsUtils.showSuccess(input);
      return true;
    }

    FinOpsUtils.clearError(input);
    return false;
  },

  // Generate configuration based on user input
  generateConfiguration: function() {
    // Validate inputs
    const hubNameValid = this.validateHubName();
    const subsValid = this.validateSubscriptions();

    if (!hubNameValid || !subsValid) {
      alert('Please fix validation errors before generating configuration.');
      return;
    }

    // Get values
    const hubName = document.getElementById('wizardHubName').value.trim();
    const subscriptions = FinOpsUtils.parseSubscriptionIds(
      document.getElementById('wizardSubscriptionIds').value
    );
    const outputType = document.querySelector('input[name="outputType"]:checked').value;

    // Save config
    this.saveConfig({ hubName, subscriptions: subscriptions.length });

    // Generate output
    let output;
    if (outputType === 'powershell') {
      output = this.generatePowerShellScript(hubName, subscriptions);
    } else {
      output = this.generatePortalInstructions(hubName, subscriptions);
    }

    // Display output
    this.displayOutput(output, outputType);
  },

  // Generate PowerShell script
  generatePowerShellScript: function(hubName, subscriptions) {
    const storageAccountName = `${hubName.replace(/-/g, '')}stg`; // Remove hyphens for storage account
    const storageResourceId = `/subscriptions/{YOUR-SUBSCRIPTION}/resourceGroups/${hubName}-rg/providers/Microsoft.Storage/storageAccounts/${storageAccountName}`;

    const script = `# Cost Management Export Configuration Script
# FinOps Hub: ${hubName}
# Generated: ${new Date().toLocaleString()}
#
# PREREQUISITES:
# - Azure CLI installed and logged in (az login)
# - Contributor role on each subscription
# - Storage account already deployed (${storageAccountName})

# Configuration
$hubName = "${hubName}"
$storageAccountResourceId = "${storageResourceId}"
$storageContainer = "msexports"

# Subscriptions to configure (${subscriptions.length} total)
$subscriptions = @(
${subscriptions.map(sub => `    "${sub}"`).join(',\n')}
)

Write-Host "Configuring Cost Management exports for $($subscriptions.Count) subscription(s)..." -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($subscriptionId in $subscriptions) {
    $exportName = "ftk-$hubName-focus"
    $scope = "/subscriptions/$subscriptionId"

    Write-Host "Creating export '$exportName' for subscription $subscriptionId..." -ForegroundColor Yellow

    try {
        # Create the export using Azure CLI
        az costmanagement export create \`
            --name $exportName \`
            --scope $scope \`
            --storage-account-id $storageAccountResourceId \`
            --storage-container $storageContainer \`
            --storage-directory "subscriptions/$subscriptionId" \`
            --timeframe MonthToDate \`
            --type Usage \`
            --dataset-version "1.0" \`
            --dataset-configuration '{\"dataVersion\":\"1.0\",\"dataOverwrites\":true,\"exportFormat\":\"Parquet\",\"partitionData\":true}' \`
            --recurrence Daily \`
            --recurrence-period from="$(Get-Date -Format yyyy-MM-dd)" \`
            --schedule-status Active 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Export created successfully" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  ✗ Export creation failed" -ForegroundColor Red
            $failCount++
        }
    } catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        $failCount++
    }

    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Export Configuration Complete" -ForegroundColor Cyan
Write-Host "  Success: $successCount" -ForegroundColor Green
Write-Host "  Failed:  $failCount" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

if ($successCount -gt 0) {
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Wait 4-8 hours for the first export to run"
    Write-Host "2. Check the storage account for exported data"
    Write-Host "3. Verify Data Factory pipelines are processing the data"
    Write-Host ""
    Write-Host "Storage Account: ${storageAccountName}" -ForegroundColor Cyan
    Write-Host "Container: msexports" -ForegroundColor Cyan
}`;

    return script;
  },

  // Generate portal instructions
  generatePortalInstructions: function(hubName, subscriptions) {
    const storageAccountName = `${hubName.replace(/-/g, '')}stg`;

    const html = `<div class="portal-instructions">
<h3>Manual Export Configuration Instructions</h3>
<p class="info-box">These instructions are for CSP subscriptions or when automated scripts cannot be used. You'll need to repeat these steps for each subscription.</p>

<h4>Configuration Summary</h4>
<ul class="config-summary">
    <li><strong>Hub Name:</strong> ${FinOpsUtils.escapeHtml(hubName)}</li>
    <li><strong>Storage Account:</strong> ${FinOpsUtils.escapeHtml(storageAccountName)}</li>
    <li><strong>Container:</strong> msexports</li>
    <li><strong>Number of Subscriptions:</strong> ${subscriptions.length}</li>
</ul>

<h4>Step-by-Step Instructions</h4>

<div class="instruction-step">
    <div class="step-number">1</div>
    <div class="step-content">
        <h5>Navigate to Cost Management</h5>
        <p>For each subscription, open the Azure Portal and navigate to:</p>
        <code>Cost Management + Billing → Cost Management → Exports</code>
    </div>
</div>

<div class="instruction-step">
    <div class="step-number">2</div>
    <div class="step-content">
        <h5>Create New Export</h5>
        <p>Click <strong>"+ Add"</strong> to create a new export</p>
    </div>
</div>

<div class="instruction-step">
    <div class="step-number">3</div>
    <div class="step-content">
        <h5>Configure Export Settings</h5>
        <p>Use these exact values:</p>
        <table class="config-table">
            <tr>
                <th>Setting</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Export name</td>
                <td><code>ftk-${FinOpsUtils.escapeHtml(hubName)}-focus</code></td>
            </tr>
            <tr>
                <td>Export type</td>
                <td>Usage and Charges (actual cost)</td>
            </tr>
            <tr>
                <td>Dataset version</td>
                <td><strong>FOCUS 1.0</strong></td>
            </tr>
            <tr>
                <td>Export format</td>
                <td>Parquet</td>
            </tr>
            <tr>
                <td>Compression</td>
                <td>Snappy</td>
            </tr>
            <tr>
                <td>File partitioning</td>
                <td><strong>ON</strong></td>
            </tr>
            <tr>
                <td>Overwrite data</td>
                <td>ON</td>
            </tr>
        </table>
    </div>
</div>

<div class="instruction-step">
    <div class="step-number">4</div>
    <div class="step-content">
        <h5>Configure Storage Destination</h5>
        <table class="config-table">
            <tr>
                <th>Setting</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Storage account</td>
                <td>${FinOpsUtils.escapeHtml(storageAccountName)}</td>
            </tr>
            <tr>
                <td>Container</td>
                <td><code>msexports</code></td>
            </tr>
            <tr>
                <td>Directory</td>
                <td><code>subscriptions/SUBSCRIPTION-ID</code><br><small>(Azure will auto-fill the subscription ID)</small></td>
            </tr>
        </table>
    </div>
</div>

<div class="instruction-step">
    <div class="step-number">5</div>
    <div class="step-content">
        <h5>Set Schedule</h5>
        <table class="config-table">
            <tr>
                <th>Setting</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Frequency</td>
                <td>Daily export of month-to-date costs</td>
            </tr>
            <tr>
                <td>Start date</td>
                <td>Today's date</td>
            </tr>
            <tr>
                <td>Status</td>
                <td><strong>Active</strong></td>
            </tr>
        </table>
    </div>
</div>

<div class="instruction-step">
    <div class="step-number">6</div>
    <div class="step-content">
        <h5>Repeat for Each Subscription</h5>
        <p>Repeat steps 1-5 for all ${subscriptions.length} subscription(s):</p>
        <ul class="subscription-list">
${subscriptions.map(sub => `            <li><code>${FinOpsUtils.escapeHtml(sub)}</code></li>`).join('\n')}
        </ul>
        <p class="estimate">⏱️ <strong>Estimated time:</strong> ${subscriptions.length * 5} minutes (5 min per subscription)</p>
    </div>
</div>

<div class="alert-warning">
    <strong>⚠️ Important Notes:</strong>
    <ul>
        <li>First export will run within 4-8 hours after creation</li>
        <li>Data will appear in the storage account after the first successful export</li>
        <li>Data Factory pipelines will automatically process new exports</li>
        <li>Ensure you select <strong>FOCUS 1.0</strong> as the dataset version (critical!)</li>
        <li>File partitioning must be <strong>ON</strong> for proper processing</li>
    </ul>
</div>

<h4>Verification Steps</h4>
<ol>
    <li>After 4-8 hours, check the <code>${storageAccountName}</code> storage account</li>
    <li>Navigate to Containers → <code>msexports</code></li>
    <li>Look for folders named <code>subscriptions/[subscription-id]/</code></li>
    <li>Verify that Parquet files exist in the dated subfolders</li>
    <li>Check Data Factory → Monitor to see pipeline runs</li>
</ol>

</div>`;

    return html;
  },

  // Display generated output
  displayOutput: function(output, outputType) {
    const outputDiv = document.getElementById('wizardOutput');
    const codeElement = document.getElementById('wizardGeneratedCode');
    const copyBtn = document.getElementById('copyExportBtn');

    if (outputType === 'powershell') {
      codeElement.className = 'language-powershell';
      codeElement.textContent = output;
      copyBtn.style.display = 'inline-block';

      // Apply syntax highlighting if Prism is available
      if (typeof Prism !== 'undefined') {
        Prism.highlightElement(codeElement);
      }
    } else {
      codeElement.className = '';
      codeElement.innerHTML = output;
      copyBtn.style.display = 'none'; // Don't show copy for HTML instructions
    }

    outputDiv.style.display = 'block';

    // Smooth scroll to output
    setTimeout(() => {
      outputDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }, 100);
  },

  // Copy generated code to clipboard
  copyToClipboard: async function() {
    const codeElement = document.getElementById('wizardGeneratedCode');
    const copyBtn = document.getElementById('copyExportBtn');
    const text = codeElement.textContent;

    try {
      await FinOpsUtils.copyToClipboard(text);

      // Show success feedback
      const originalText = copyBtn.innerHTML;
      copyBtn.innerHTML = '✓ Copied!';
      copyBtn.classList.add('success');

      setTimeout(() => {
        copyBtn.innerHTML = originalText;
        copyBtn.classList.remove('success');
      }, 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
      alert('Failed to copy to clipboard. Please select and copy manually.');
    }
  }
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => ExportWizard.init());
} else {
  ExportWizard.init();
}
