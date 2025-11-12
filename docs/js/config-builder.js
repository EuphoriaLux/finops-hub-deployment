/**
 * Deployment Configuration Builder
 * Interactive form for generating Azure deployment parameters
 */

const ConfigBuilder = {
  // Current configuration state
  config: {
    hubName: '',
    region: 'eastus',
    storageSku: 'Premium_LRS',
    exportRetention: 0,
    ingestionRetention: 13,
    enablePublicAccess: true,
    enableInfraEncryption: false,
    dataExplorerName: '',
    subscriptionCount: 1
  },

  // Initialize the builder
  init: function() {
    this.loadSavedConfig();
    this.setupEventListeners();
    this.updateCostEstimate();
  },

  // Load saved configuration
  loadSavedConfig: function() {
    try {
      const saved = localStorage.getItem('finops-config-builder');
      if (saved) {
        this.config = { ...this.config, ...JSON.parse(saved) };
        this.populateForm();
      }
    } catch (e) {
      console.warn('Could not load saved config', e);
    }
  },

  // Save configuration
  saveConfig: function() {
    try {
      localStorage.setItem('finops-config-builder', JSON.stringify(this.config));
    } catch (e) {
      console.warn('Could not save config', e);
    }
  },

  // Populate form with saved values
  populateForm: function() {
    const fields = [
      'hubName', 'region', 'storageSku', 'exportRetention',
      'ingestionRetention', 'enablePublicAccess', 'enableInfraEncryption',
      'dataExplorerName', 'subscriptionCount'
    ];

    fields.forEach(field => {
      const element = document.getElementById('config' + field.charAt(0).toUpperCase() + field.slice(1));
      if (element) {
        if (element.type === 'checkbox') {
          element.checked = this.config[field];
        } else {
          element.value = this.config[field];
        }
      }
    });
  },

  // Setup event listeners
  setupEventListeners: function() {
    // Hub name validation
    const hubNameInput = document.getElementById('configHubName');
    if (hubNameInput) {
      hubNameInput.addEventListener('input', FinOpsUtils.debounce(() => {
        this.validateAndUpdate('hubName', hubNameInput.value);
      }, 500));
    }

    // Region selection
    const regionSelect = document.getElementById('configRegion');
    if (regionSelect) {
      this.populateRegionSelect(regionSelect);
      regionSelect.addEventListener('change', () => {
        this.config.region = regionSelect.value;
        this.saveConfig();
        this.updateRecommendations();
      });
    }

    // Storage SKU
    const skuRadios = document.querySelectorAll('input[name="configStorageSku"]');
    skuRadios.forEach(radio => {
      radio.addEventListener('change', () => {
        this.config.storageSku = radio.value;
        this.saveConfig();
        this.updateCostEstimate();
        this.updateRecommendations();
      });
    });

    // Retention policies
    const exportRetention = document.getElementById('configExportRetention');
    if (exportRetention) {
      exportRetention.addEventListener('input', FinOpsUtils.debounce(() => {
        this.validateAndUpdate('exportRetention', parseInt(exportRetention.value) || 0);
      }, 500));
    }

    const ingestionRetention = document.getElementById('configIngestionRetention');
    if (ingestionRetention) {
      ingestionRetention.addEventListener('input', FinOpsUtils.debounce(() => {
        this.validateAndUpdate('ingestionRetention', parseInt(ingestionRetention.value) || 13);
      }, 500));
    }

    // Toggles
    const publicAccess = document.getElementById('configEnablePublicAccess');
    if (publicAccess) {
      publicAccess.addEventListener('change', () => {
        this.config.enablePublicAccess = publicAccess.checked;
        this.saveConfig();
        this.updateRecommendations();
      });
    }

    const infraEncryption = document.getElementById('configEnableInfraEncryption');
    if (infraEncryption) {
      infraEncryption.addEventListener('change', () => {
        this.config.enableInfraEncryption = infraEncryption.checked;
        this.saveConfig();
        this.updateCostEstimate();
      });
    }

    // Data Explorer
    const adxName = document.getElementById('configDataExplorerName');
    if (adxName) {
      adxName.addEventListener('input', FinOpsUtils.debounce(() => {
        this.config.dataExplorerName = adxName.value.trim();
        this.saveConfig();
        this.updateCostEstimate();
        this.updateRecommendations();
      }, 500));
    }

    // Subscription count
    const subCount = document.getElementById('configSubscriptionCount');
    if (subCount) {
      subCount.addEventListener('input', FinOpsUtils.debounce(() => {
        this.validateAndUpdate('subscriptionCount', parseInt(subCount.value) || 1);
      }, 500));
    }

    // Generate button
    const generateBtn = document.getElementById('generateDeployBtn');
    if (generateBtn) {
      generateBtn.addEventListener('click', () => this.generateDeployment());
    }

    // Advanced section toggle
    const advancedToggle = document.getElementById('toggleAdvanced');
    if (advancedToggle) {
      advancedToggle.addEventListener('click', () => {
        const advancedSection = document.getElementById('advancedOptions');
        if (advancedSection) {
          const isHidden = advancedSection.style.display === 'none';
          advancedSection.style.display = isHidden ? 'block' : 'none';
          advancedToggle.textContent = isHidden ? '▼ Hide Advanced Options' : '▶ Show Advanced Options';
        }
      });
    }
  },

  // Populate region dropdown
  populateRegionSelect: function(selectElement) {
    selectElement.innerHTML = '';

    // Add recommended regions first
    const recommendedOptGroup = document.createElement('optgroup');
    recommendedOptGroup.label = 'Recommended Regions';

    FinOpsUtils.azureRegions
      .filter(r => r.recommended)
      .forEach(region => {
        const option = document.createElement('option');
        option.value = region.value;
        option.textContent = region.label;
        recommendedOptGroup.appendChild(option);
      });

    selectElement.appendChild(recommendedOptGroup);

    // Add other regions
    const otherOptGroup = document.createElement('optgroup');
    otherOptGroup.label = 'Other Regions';

    FinOpsUtils.azureRegions
      .filter(r => !r.recommended)
      .forEach(region => {
        const option = document.createElement('option');
        option.value = region.value;
        option.textContent = region.label;
        otherOptGroup.appendChild(option);
      });

    selectElement.appendChild(otherOptGroup);

    // Set current value
    selectElement.value = this.config.region;
  },

  // Validate and update field
  validateAndUpdate: function(field, value) {
    const inputElement = document.getElementById('config' + field.charAt(0).toUpperCase() + field.slice(1));

    if (field === 'hubName') {
      const result = FinOpsUtils.validateHubName(value);
      if (result.valid) {
        FinOpsUtils.showSuccess(inputElement);
        this.config.hubName = value;
        this.saveConfig();
        this.updateResourceNames();
      } else if (value.length > 0) {
        FinOpsUtils.showError(inputElement, result.message);
      } else {
        FinOpsUtils.clearError(inputElement);
      }
    } else if (field === 'exportRetention') {
      if (value >= 0 && value <= 365) {
        FinOpsUtils.showSuccess(inputElement);
        this.config.exportRetention = value;
        this.saveConfig();
        this.updateCostEstimate();
      } else {
        FinOpsUtils.showError(inputElement, 'Must be between 0 and 365 days');
      }
    } else if (field === 'ingestionRetention') {
      if (value >= 1 && value <= 36) {
        FinOpsUtils.showSuccess(inputElement);
        this.config.ingestionRetention = value;
        this.saveConfig();
        this.updateCostEstimate();
        this.updateRecommendations();
      } else {
        FinOpsUtils.showError(inputElement, 'Must be between 1 and 36 months');
      }
    } else if (field === 'subscriptionCount') {
      if (value >= 1 && value <= 1000) {
        FinOpsUtils.showSuccess(inputElement);
        this.config.subscriptionCount = value;
        this.saveConfig();
        this.updateCostEstimate();
      } else {
        FinOpsUtils.showError(inputElement, 'Must be between 1 and 1000');
      }
    }
  },

  // Update cost estimate
  updateCostEstimate: function() {
    const costs = this.calculateCosts();
    const totalCost = costs.total;

    // Update total
    const totalElement = document.getElementById('estimatedCost');
    if (totalElement) {
      totalElement.textContent = FinOpsUtils.formatCurrency(totalCost, true);
    }

    // Update breakdown
    const breakdownElement = document.getElementById('costBreakdown');
    if (breakdownElement) {
      breakdownElement.innerHTML = `
        <div class="cost-item">
          <span>Storage Account:</span>
          <span>${FinOpsUtils.formatCurrency(costs.storage)}/mo</span>
        </div>
        <div class="cost-item">
          <span>Data Factory:</span>
          <span>${FinOpsUtils.formatCurrency(costs.dataFactory)}/mo</span>
        </div>
        <div class="cost-item">
          <span>Key Vault:</span>
          <span>${FinOpsUtils.formatCurrency(costs.keyVault)}/mo</span>
        </div>
        <div class="cost-item">
          <span>Event Grid:</span>
          <span>${FinOpsUtils.formatCurrency(costs.eventGrid)}/mo</span>
        </div>
        ${costs.dataExplorer > 0 ? `
        <div class="cost-item">
          <span>Data Explorer:</span>
          <span>${FinOpsUtils.formatCurrency(costs.dataExplorer)}/mo</span>
        </div>` : ''}
        <div class="cost-item">
          <span>Data Transfer:</span>
          <span>${FinOpsUtils.formatCurrency(costs.dataTransfer)}/mo</span>
        </div>
        <hr>
        <div class="cost-item cost-total">
          <span><strong>Total Monthly Cost:</strong></span>
          <span><strong>${FinOpsUtils.formatCurrency(costs.total)}/mo</strong></span>
        </div>
      `;
    }

    // Update ROI estimate
    this.updateROIEstimate(totalCost);
  },

  // Calculate costs
  calculateCosts: function() {
    const costs = {
      storage: 0,
      dataFactory: 2,
      keyVault: 0.5,
      eventGrid: 0.5,
      dataExplorer: 0,
      dataTransfer: 0,
      total: 0
    };

    // Storage cost (Premium tier)
    const baseStorageCost = this.config.storageSku === 'Premium_ZRS' ? 8 : 5;
    costs.storage = baseStorageCost + (this.config.subscriptionCount * 0.5); // Data volume estimate

    // Increase if keeping raw exports
    if (this.config.exportRetention > 0) {
      costs.storage += this.config.subscriptionCount * 0.3;
    }

    // Infrastructure encryption adds negligible cost
    if (this.config.enableInfraEncryption) {
      costs.storage += 0.5;
    }

    // Data Explorer (optional)
    if (this.config.dataExplorerName && this.config.dataExplorerName.length > 0) {
      costs.dataExplorer = 150; // Dev SKU estimate
    }

    // Data transfer (minimal for most scenarios)
    costs.dataTransfer = Math.min(this.config.subscriptionCount * 0.1, 2);

    // Calculate total
    costs.total = Object.values(costs).reduce((sum, cost) => sum + cost, 0);

    return costs;
  },

  // Update ROI estimate
  updateROIEstimate: function(monthlyCost) {
    const roiElement = document.getElementById('roiEstimate');
    if (!roiElement) return;

    // Rough estimate: 5-15% cost optimization
    const estimatedSavings = this.config.subscriptionCount * 20; // $20 per subscription per month (conservative)

    const roi = estimatedSavings - monthlyCost;
    const roiPercentage = monthlyCost > 0 ? ((estimatedSavings / monthlyCost) * 100).toFixed(0) : 0;

    roiElement.innerHTML = `
      <div class="roi-card">
        <h4>💰 Expected ROI</h4>
        <div class="roi-stats">
          <div class="roi-stat">
            <span class="roi-label">FinOps Hub Cost:</span>
            <span class="roi-value">${FinOpsUtils.formatCurrency(monthlyCost)}/mo</span>
          </div>
          <div class="roi-stat">
            <span class="roi-label">Expected Savings:</span>
            <span class="roi-value positive">+${FinOpsUtils.formatCurrency(estimatedSavings)}/mo</span>
          </div>
          <div class="roi-stat highlight">
            <span class="roi-label">Net Benefit:</span>
            <span class="roi-value ${roi > 0 ? 'positive' : 'negative'}">${roi > 0 ? '+' : ''}${FinOpsUtils.formatCurrency(roi)}/mo</span>
          </div>
          <div class="roi-stat">
            <span class="roi-label">ROI:</span>
            <span class="roi-value">${roiPercentage}%</span>
          </div>
        </div>
        <p class="roi-note">
          <small>💡 Based on industry averages of 5-15% Azure cost optimization through improved visibility and governance.</small>
        </p>
      </div>
    `;
  },

  // Update resource names preview
  updateResourceNames: function() {
    const previewElement = document.getElementById('resourceNamePreview');
    if (!previewElement || !this.config.hubName) return;

    const sanitized = this.config.hubName.replace(/-/g, '');
    const names = {
      resourceGroup: `${this.config.hubName}-rg`,
      storage: `${sanitized}stg`,
      dataFactory: `${this.config.hubName}-adf`,
      keyVault: `${sanitized}-kv`,
      identity: `${this.config.hubName}-mi`
    };

    previewElement.innerHTML = `
      <h4>📋 Resource Names Preview</h4>
      <ul class="resource-list">
        <li><strong>Resource Group:</strong> <code>${names.resourceGroup}</code></li>
        <li><strong>Storage Account:</strong> <code>${names.storage}</code></li>
        <li><strong>Data Factory:</strong> <code>${names.dataFactory}</code></li>
        <li><strong>Key Vault:</strong> <code>${names.keyVault}</code></li>
        <li><strong>Managed Identity:</strong> <code>${names.identity}</code></li>
      </ul>
    `;
  },

  // Update recommendations
  updateRecommendations: function() {
    const recElement = document.getElementById('configRecommendations');
    if (!recElement) return;

    const recommendations = [];

    // Storage SKU recommendation
    if (this.config.storageSku === 'Premium_LRS') {
      recommendations.push({
        type: 'info',
        message: '💡 Premium LRS is suitable for dev/test. Consider Premium ZRS for production workloads.'
      });
    }

    // Long retention recommendation
    if (this.config.ingestionRetention > 24) {
      recommendations.push({
        type: 'warning',
        message: '⚠️ Retention > 24 months recommended to use Azure Data Explorer for better query performance.'
      });
    }

    // Public access warning
    if (this.config.enablePublicAccess === false) {
      recommendations.push({
        type: 'info',
        message: '🔒 Private networking requires additional configuration (VNet, Private Endpoints).'
      });
    }

    // Data Explorer recommendation
    if (this.config.dataExplorerName && this.config.subscriptionCount < 10) {
      recommendations.push({
        type: 'info',
        message: '💡 Data Explorer adds ~$150/mo. Consider storage-only deployment for < 10 subscriptions.'
      });
    }

    // Display recommendations
    if (recommendations.length > 0) {
      recElement.innerHTML = recommendations.map(rec =>
        `<div class="recommendation ${rec.type}">${rec.message}</div>`
      ).join('');
      recElement.style.display = 'block';
    } else {
      recElement.style.display = 'none';
    }
  },

  // Generate deployment
  generateDeployment: function() {
    // Validate hub name
    if (!this.config.hubName || FinOpsUtils.validateHubName(this.config.hubName).valid === false) {
      alert('Please enter a valid hub name before generating deployment.');
      document.getElementById('configHubName').focus();
      return;
    }

    // Generate deploy URL
    const deployUrl = this.buildDeployUrl();

    // Show summary
    this.showDeploymentSummary(deployUrl);
  },

  // Build Azure deployment URL
  buildDeployUrl: function() {
    const baseUrl = 'https://portal.azure.com/#create/Microsoft.Template/uri/';
    const templateUri = 'https://raw.githubusercontent.com/EuphoriaLux/finops-hub-deployment/main/template.json';
    const uiDefUri = 'https://raw.githubusercontent.com/EuphoriaLux/finops-hub-deployment/main/createUiDefinition.json';

    // Build parameters
    const params = new URLSearchParams({
      hubName: this.config.hubName,
      location: this.config.region,
      storageSku: this.config.storageSku,
      exportRetentionInDays: this.config.exportRetention,
      ingestionRetentionInMonths: this.config.ingestionRetention,
      enablePublicAccess: this.config.enablePublicAccess,
      enableInfrastructureEncryption: this.config.enableInfraEncryption
    });

    if (this.config.dataExplorerName) {
      params.append('dataExplorerName', this.config.dataExplorerName);
    }

    const fullUrl = `${baseUrl}${encodeURIComponent(templateUri)}&createUIDefinitionUri=${encodeURIComponent(uiDefUri)}`;

    return fullUrl;
  },

  // Show deployment summary
  showDeploymentSummary: function(deployUrl) {
    const summaryElement = document.getElementById('deploymentSummary');
    if (!summaryElement) return;

    const costs = this.calculateCosts();

    summaryElement.innerHTML = `
      <h3>✅ Deployment Configuration Ready</h3>

      <div class="summary-section">
        <h4>Configuration Summary</h4>
        <table class="summary-table">
          <tr>
            <td><strong>Hub Name:</strong></td>
            <td><code>${this.config.hubName}</code></td>
          </tr>
          <tr>
            <td><strong>Region:</strong></td>
            <td>${FinOpsUtils.azureRegions.find(r => r.value === this.config.region)?.label || this.config.region}</td>
          </tr>
          <tr>
            <td><strong>Storage SKU:</strong></td>
            <td>${this.config.storageSku}</td>
          </tr>
          <tr>
            <td><strong>Retention (Ingestion):</strong></td>
            <td>${this.config.ingestionRetention} months</td>
          </tr>
          <tr>
            <td><strong>Estimated Monthly Cost:</strong></td>
            <td><strong>${FinOpsUtils.formatCurrency(costs.total)}</strong></td>
          </tr>
        </table>
      </div>

      <div class="summary-section">
        <h4>Next Steps</h4>
        <ol>
          <li>Click the button below to open Azure Portal</li>
          <li>Review the pre-filled parameters</li>
          <li>Select your Azure subscription and resource group</li>
          <li>Click "Review + Create" then "Create"</li>
          <li>Wait 15-20 minutes for deployment to complete</li>
        </ol>
      </div>

      <div class="deploy-button-container">
        <a href="${deployUrl}" target="_blank" class="deploy-to-azure-btn">
          <img src="https://aka.ms/deploytoazurebutton" alt="Deploy to Azure" />
        </a>
      </div>

      <div class="alert-info">
        <strong>ℹ️ Note:</strong> After deployment, you'll need to manually configure Cost Management exports (use the Export Wizard above).
      </div>
    `;

    summaryElement.style.display = 'block';

    // Scroll to summary
    setTimeout(() => {
      summaryElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 100);
  }
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => ConfigBuilder.init());
} else {
  ConfigBuilder.init();
}
