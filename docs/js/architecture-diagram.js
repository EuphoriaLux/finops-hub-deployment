/**
 * Interactive Architecture Diagram
 * Handles interactivity for the FinOps Hub architecture visualization
 */

const ArchitectureDiagram = {
  // Component details
  components: {
    storage: {
      name: 'Storage Account (Data Lake Gen2)',
      description: 'Azure Data Lake Storage Gen2 account that stores raw Cost Management exports in the <code>msexports</code> container and processed data in the <code>ingestion</code> container. Premium tier with hierarchical namespace enabled.',
      cost: '$5-10/month',
      features: [
        'Hierarchical namespace for file/folder structure',
        'Premium performance tier',
        'Lifecycle management policies',
        'Supports Parquet format (FOCUS 1.0)'
      ],
      icon: '💾'
    },
    dataFactory: {
      name: 'Azure Data Factory',
      description: 'Orchestration service that processes raw cost exports through pipelines. Triggered automatically when new exports arrive via Event Grid.',
      cost: '$2-5/month',
      features: [
        'Event-driven pipeline execution',
        'Data transformation and enrichment',
        'Managed Virtual Network',
        'Automated triggers and schedules'
      ],
      icon: '🏭'
    },
    keyVault: {
      name: 'Key Vault',
      description: 'Secure storage for secrets, connection strings, and configuration. Accessed by Data Factory and managed identities for secure authentication.',
      cost: '$0.50/month',
      features: [
        'Centralized secret management',
        'Access policies for managed identities',
        'Audit logging',
        'Optional private endpoint support'
      ],
      icon: '🔐'
    },
    eventGrid: {
      name: 'Event Grid System Topic',
      description: 'Monitors blob creation events in the storage account and triggers Data Factory pipelines when new cost exports arrive.',
      cost: '$0.50/month',
      features: [
        'Real-time event processing',
        'Blob creation event subscriptions',
        'Reliable delivery to ADF',
        'No code required'
      ],
      icon: '⚡'
    },
    managedIdentity: {
      name: 'Managed Identities',
      description: 'Three managed identities provide secure, password-less authentication: Blob Manager (storage operations), Trigger Manager (ADF trigger management), and Data Factory system identity.',
      cost: 'Free',
      features: [
        'No credentials to manage',
        'Automatic lifecycle management',
        'RBAC-based access control',
        'Azure AD integrated'
      ],
      icon: '🔑'
    },
    dataExplorer: {
      name: 'Azure Data Explorer (Optional)',
      description: 'High-performance analytics engine for querying large volumes of cost data. Recommended for organizations with >$2M monthly Azure spend or 24+ months retention.',
      cost: '$150+/month',
      features: [
        'Fast KQL queries over large datasets',
        'Columnar storage compression',
        'Time-series optimizations',
        'Direct Power BI integration'
      ],
      icon: '📊'
    },
    costManagement: {
      name: 'Cost Management (Azure)',
      description: 'Built-in Azure service that generates FOCUS 1.0 exports. Runs daily to export month-to-date cost data to the storage account.',
      cost: 'Free',
      features: [
        'FOCUS 1.0 format exports',
        'Daily automated execution',
        'Parquet with Snappy compression',
        'Per-subscription configuration'
      ],
      icon: '💰'
    },
    powerBI: {
      name: 'Power BI',
      description: 'Business intelligence tool that connects to processed data in storage or Data Explorer. Use FinOps toolkit reports for pre-built dashboards.',
      cost: 'Separate license',
      features: [
        'Direct Query to storage/ADX',
        'Pre-built FinOps reports',
        'Custom dashboards',
        'Scheduled refresh'
      ],
      icon: '📈'
    }
  },

  // Data flow steps
  dataFlow: [
    {
      from: 'costManagement',
      to: 'storage',
      label: 'Export',
      description: 'Daily FOCUS 1.0 exports (Parquet)'
    },
    {
      from: 'storage',
      to: 'eventGrid',
      label: 'Event',
      description: 'Blob creation event notification'
    },
    {
      from: 'eventGrid',
      to: 'dataFactory',
      label: 'Trigger',
      description: 'Activate pipeline'
    },
    {
      from: 'dataFactory',
      to: 'storage',
      label: 'Process',
      description: 'Transform and enrich data'
    },
    {
      from: 'dataFactory',
      to: 'dataExplorer',
      label: 'Ingest',
      description: 'Load to analytics engine (optional)'
    },
    {
      from: 'storage',
      to: 'powerBI',
      label: 'Query',
      description: 'Direct Query for visualization'
    },
    {
      from: 'dataExplorer',
      to: 'powerBI',
      label: 'Query',
      description: 'KQL queries for large datasets'
    }
  ],

  // State
  currentComponent: null,
  showDataExplorer: false,
  animationRunning: false,
  animationFrame: null,

  // Initialize
  init: function() {
    this.setupEventListeners();
    this.updateDiagramVisibility();
  },

  // Setup event listeners
  setupEventListeners: function() {
    // Component click handlers - use class selector that exists in HTML
    document.querySelectorAll('.arch-component').forEach(element => {
      element.addEventListener('click', (e) => {
        const componentId = element.getAttribute('data-component');
        this.showComponentDetails(componentId);
      });

      // Add hover effect
      element.addEventListener('mouseenter', () => {
        element.classList.add('hover');
      });
      element.addEventListener('mouseleave', () => {
        element.classList.remove('hover');
      });
    });

    // Toggle Data Explorer
    const adxToggle = document.getElementById('toggleDataExplorer');
    if (adxToggle) {
      adxToggle.addEventListener('change', () => {
        this.showDataExplorer = adxToggle.checked;
        this.updateDiagramVisibility();
      });
    }

    // Animation controls
    const playBtn = document.getElementById('playAnimation');
    if (playBtn) {
      playBtn.addEventListener('click', () => {
        if (this.animationRunning) {
          this.stopAnimation();
          playBtn.textContent = '▶ Play Data Flow';
        } else {
          this.playAnimation();
          playBtn.textContent = '⏸ Pause';
        }
      });
    }

    // Close detail panel
    const closeBtn = document.getElementById('closeDetailPanel');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        this.hideComponentDetails();
      });
    }

    // Click outside to close
    const detailPanel = document.getElementById('componentDetailPanel');
    if (detailPanel) {
      document.addEventListener('click', (e) => {
        if (this.currentComponent &&
            !detailPanel.contains(e.target) &&
            !e.target.closest('.architecture-component')) {
          this.hideComponentDetails();
        }
      });
    }
  },

  // Show component details in side panel
  showComponentDetails: function(componentId) {
    const component = this.components[componentId];
    if (!component) return;

    this.currentComponent = componentId;

    const panel = document.getElementById('componentDetailPanel');
    const content = document.getElementById('componentDetailContent');

    if (!panel || !content) return;

    // Build content
    content.innerHTML = `
      <div class="component-icon">${component.icon}</div>
      <h3>${component.name}</h3>
      <p class="component-description">${component.description}</p>

      <div class="component-cost">
        <strong>💵 Cost:</strong> ${component.cost}
      </div>

      <h4>Key Features:</h4>
      <ul class="component-features">
        ${component.features.map(f => `<li>${f}</li>`).join('')}
      </ul>
    `;

    // Show panel
    panel.classList.add('visible');

    // Highlight the component
    document.querySelectorAll('.arch-component').forEach(el => {
      el.classList.remove('selected');
    });

    const componentElement = document.querySelector(`.arch-component[data-component="${componentId}"]`);
    if (componentElement) {
      componentElement.classList.add('selected');
    }
  },

  // Hide component details
  hideComponentDetails: function() {
    const panel = document.getElementById('componentDetailPanel');
    if (panel) {
      panel.classList.remove('visible');
    }

    document.querySelectorAll('.arch-component').forEach(el => {
      el.classList.remove('selected');
    });

    this.currentComponent = null;
  },

  // Update diagram visibility (show/hide Data Explorer)
  updateDiagramVisibility: function() {
    const adxElements = document.querySelectorAll('.optional-adx');
    const adxFlows = document.querySelectorAll('.flow-to-adx, .flow-adx-to-powerbi');

    adxElements.forEach(el => {
      el.style.display = this.showDataExplorer ? 'block' : 'none';
    });

    adxFlows.forEach(el => {
      el.style.display = this.showDataExplorer ? 'block' : 'none';
    });

    // Update cost estimate
    this.updateTotalCost();
  },

  // Update total architecture cost
  updateTotalCost: function() {
    const costElement = document.getElementById('architectureCost');
    if (!costElement) return;

    let baseCost = 8.5; // Storage + ADF + KV + EventGrid
    if (this.showDataExplorer) {
      baseCost += 150; // Add ADX cost
    }

    costElement.textContent = `$${baseCost.toFixed(0)}-${(baseCost + 20).toFixed(0)}/month`;
  },

  // Play data flow animation
  playAnimation: function() {
    this.animationRunning = true;
    let step = 0;

    const flows = this.dataFlow.filter(flow => {
      // Filter out ADX flows if not shown
      if (!this.showDataExplorer && (flow.to === 'dataExplorer' || flow.from === 'dataExplorer')) {
        return false;
      }
      return true;
    });

    const animate = () => {
      if (!this.animationRunning) return;

      // Clear previous highlights
      document.querySelectorAll('.arch-component').forEach(el => {
        el.classList.remove('flow-highlight');
      });

      // Highlight current step - highlight both source and destination
      const currentFlow = flows[step % flows.length];

      // Highlight source component
      const fromElement = document.querySelector(`.arch-component[data-component="${currentFlow.from}"]`);
      if (fromElement) {
        fromElement.classList.add('flow-highlight');
      }

      // After short delay, highlight destination
      setTimeout(() => {
        const toElement = document.querySelector(`.arch-component[data-component="${currentFlow.to}"]`);
        if (toElement) {
          toElement.classList.add('flow-highlight');
        }
      }, 500);

      // Show flow description
      this.showFlowDescription(currentFlow);

      step++;

      // Continue animation
      this.animationFrame = setTimeout(animate, 2500); // 2.5 seconds per step
    };

    animate();
  },

  // Stop animation
  stopAnimation: function() {
    this.animationRunning = false;
    if (this.animationFrame) {
      clearTimeout(this.animationFrame);
      this.animationFrame = null;
    }

    // Clear highlights
    document.querySelectorAll('.arch-component').forEach(el => {
      el.classList.remove('flow-highlight');
    });

    // Hide flow description
    const flowDesc = document.getElementById('flowDescription');
    if (flowDesc) {
      flowDesc.style.display = 'none';
    }
  },

  // Show flow description
  showFlowDescription: function(flow) {
    const flowDesc = document.getElementById('flowDescription');
    if (!flowDesc) return;

    const fromComp = this.components[flow.from];
    const toComp = this.components[flow.to];

    flowDesc.innerHTML = `
      <strong>${flow.label}:</strong>
      ${fromComp.name} → ${toComp.name}
      <br>
      <small>${flow.description}</small>
    `;

    flowDesc.style.display = 'block';
  },

  // Export diagram as image (future feature)
  exportDiagram: function() {
    // This would use html2canvas or similar library
    alert('Export feature coming soon!');
  }
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => ArchitectureDiagram.init());
} else {
  ArchitectureDiagram.init();
}
