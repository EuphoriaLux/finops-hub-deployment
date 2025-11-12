/**
 * Utility Functions for FinOps Hub Deployment Interactive Features
 * Shared validation, formatting, and helper functions
 */

const FinOpsUtils = {
  /**
   * Validates Azure hub name format
   * Rules: 3-24 characters, lowercase letters and numbers only
   * @param {string} hubName - The hub name to validate
   * @returns {Object} {valid: boolean, message: string}
   */
  validateHubName: function(hubName) {
    if (!hubName || hubName.length === 0) {
      return { valid: false, message: 'Hub name is required' };
    }
    if (hubName.length < 3 || hubName.length > 24) {
      return { valid: false, message: 'Hub name must be 3-24 characters' };
    }
    if (!/^[a-z0-9]+$/.test(hubName)) {
      return { valid: false, message: 'Only lowercase letters and numbers allowed' };
    }
    return { valid: true, message: 'Valid hub name' };
  },

  /**
   * Validates Azure subscription ID (GUID format)
   * @param {string} subscriptionId - The subscription ID to validate
   * @returns {boolean} True if valid GUID format
   */
  validateSubscriptionId: function(subscriptionId) {
    const guidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return guidRegex.test(subscriptionId.trim());
  },

  /**
   * Parses multiple subscription IDs from textarea input
   * Supports comma-separated, newline-separated, or space-separated
   * @param {string} input - Raw input string
   * @returns {Array} Array of trimmed subscription IDs
   */
  parseSubscriptionIds: function(input) {
    if (!input) return [];

    // Split by newlines, commas, or spaces
    return input
      .split(/[\n,\s]+/)
      .map(id => id.trim())
      .filter(id => id.length > 0);
  },

  /**
   * Formats currency with proper symbol and decimals
   * @param {number} amount - Amount to format
   * @param {boolean} includeDecimals - Include decimal places
   * @returns {string} Formatted currency string
   */
  formatCurrency: function(amount, includeDecimals = true) {
    if (includeDecimals) {
      return `$${amount.toFixed(2)}`;
    }
    return `$${Math.round(amount)}`;
  },

  /**
   * Copies text to clipboard using modern Clipboard API
   * Falls back to legacy method if needed
   * @param {string} text - Text to copy
   * @returns {Promise} Resolves when copy is successful
   */
  copyToClipboard: async function(text) {
    if (navigator.clipboard && window.isSecureContext) {
      // Modern async clipboard API
      return navigator.clipboard.writeText(text);
    } else {
      // Fallback for older browsers
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      textArea.style.left = '-999999px';
      document.body.appendChild(textArea);
      textArea.select();
      try {
        document.execCommand('copy');
        document.body.removeChild(textArea);
        return Promise.resolve();
      } catch (err) {
        document.body.removeChild(textArea);
        return Promise.reject(err);
      }
    }
  },

  /**
   * Shows a temporary success message
   * @param {HTMLElement} element - Element to show message in
   * @param {string} message - Message text
   * @param {number} duration - Duration in milliseconds
   */
  showSuccessMessage: function(element, message, duration = 3000) {
    const originalContent = element.innerHTML;
    element.innerHTML = `<span class="success-message">✓ ${message}</span>`;
    element.classList.add('success');

    setTimeout(() => {
      element.innerHTML = originalContent;
      element.classList.remove('success');
    }, duration);
  },

  /**
   * Shows validation error on form field
   * @param {HTMLElement} element - Input element
   * @param {string} message - Error message
   */
  showError: function(element, message) {
    // Remove any existing error
    this.clearError(element);

    // Add error class to input
    element.classList.add('error');

    // Create and append error message
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.textContent = message;
    element.parentNode.insertBefore(errorDiv, element.nextSibling);
  },

  /**
   * Clears validation error from form field
   * @param {HTMLElement} element - Input element
   */
  clearError: function(element) {
    element.classList.remove('error');
    const errorMsg = element.parentNode.querySelector('.error-message');
    if (errorMsg) {
      errorMsg.remove();
    }
  },

  /**
   * Shows validation success on form field
   * @param {HTMLElement} element - Input element
   */
  showSuccess: function(element) {
    this.clearError(element);
    element.classList.add('valid');
  },

  /**
   * Debounces a function call
   * @param {Function} func - Function to debounce
   * @param {number} wait - Wait time in milliseconds
   * @returns {Function} Debounced function
   */
  debounce: function(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  },

  /**
   * Escapes HTML special characters
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml: function(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  },

  /**
   * Formats Azure resource name for display
   * @param {string} name - Resource name
   * @returns {string} Formatted name
   */
  formatResourceName: function(name) {
    return name
      .split('-')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  },

  /**
   * Generates a random ID for elements
   * @returns {string} Random ID string
   */
  generateId: function() {
    return 'id-' + Math.random().toString(36).substr(2, 9);
  },

  /**
   * Smooth scroll to element
   * @param {string} elementId - ID of element to scroll to
   */
  smoothScrollTo: function(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  },

  /**
   * Checks if element is in viewport
   * @param {HTMLElement} element - Element to check
   * @returns {boolean} True if in viewport
   */
  isInViewport: function(element) {
    const rect = element.getBoundingClientRect();
    return (
      rect.top >= 0 &&
      rect.left >= 0 &&
      rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
      rect.right <= (window.innerWidth || document.documentElement.clientWidth)
    );
  },

  /**
   * Azure region display names
   */
  azureRegions: [
    { value: 'eastus', label: 'East US', recommended: true },
    { value: 'eastus2', label: 'East US 2', recommended: true },
    { value: 'westus', label: 'West US', recommended: false },
    { value: 'westus2', label: 'West US 2', recommended: true },
    { value: 'westus3', label: 'West US 3', recommended: false },
    { value: 'centralus', label: 'Central US', recommended: true },
    { value: 'northcentralus', label: 'North Central US', recommended: false },
    { value: 'southcentralus', label: 'South Central US', recommended: false },
    { value: 'westcentralus', label: 'West Central US', recommended: false },
    { value: 'northeurope', label: 'North Europe', recommended: true },
    { value: 'westeurope', label: 'West Europe', recommended: true },
    { value: 'uksouth', label: 'UK South', recommended: true },
    { value: 'ukwest', label: 'UK West', recommended: false },
    { value: 'francecentral', label: 'France Central', recommended: false },
    { value: 'germanywestcentral', label: 'Germany West Central', recommended: false },
    { value: 'swedencentral', label: 'Sweden Central', recommended: false },
    { value: 'southeastasia', label: 'Southeast Asia', recommended: true },
    { value: 'eastasia', label: 'East Asia', recommended: false },
    { value: 'australiaeast', label: 'Australia East', recommended: true },
    { value: 'australiasoutheast', label: 'Australia Southeast', recommended: false },
    { value: 'japaneast', label: 'Japan East', recommended: true },
    { value: 'japanwest', label: 'Japan West', recommended: false },
    { value: 'koreacentral', label: 'Korea Central', recommended: false },
    { value: 'canadacentral', label: 'Canada Central', recommended: true },
    { value: 'brazilsouth', label: 'Brazil South', recommended: false },
    { value: 'southafricanorth', label: 'South Africa North', recommended: false },
    { value: 'uaenorth', label: 'UAE North', recommended: false },
    { value: 'switzerlandnorth', label: 'Switzerland North', recommended: false }
  ],

  /**
   * Storage SKU options with details
   */
  storageSKUs: [
    {
      value: 'Premium_LRS',
      label: 'Premium LRS (Locally Redundant)',
      description: 'Single datacenter redundancy - Lower cost',
      costMultiplier: 1.0,
      recommended: 'dev/test'
    },
    {
      value: 'Premium_ZRS',
      label: 'Premium ZRS (Zone Redundant)',
      description: 'Zone-redundant storage - Higher availability',
      costMultiplier: 1.6,
      recommended: 'production'
    }
  ]
};

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FinOpsUtils;
}
