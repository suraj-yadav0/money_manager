/* Net Worth & Assets Management Screen Module (wealth items, liabilities, net worth cumulative charts) */
import { Chart } from 'chart.js';
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper } from '../utils/icons.js';

let networthChartInstance = null;

export const NetWorthPage = {
  activeAssetFilter: 'all', // 'all', 'assets', 'liabilities'

  render(state) {
    const data = this.calculateNetWorthData(state);
    const filteredAssets = this.getFilteredAssets(state);

    return `
      <div class="animate-fade-in" style="display:flex; flex-wrap:wrap; gap:24px; align-items:flex-start;">
        
        <!-- Left Column: Summary & Chart -->
        <div style="flex: 1 1 360px; max-width: 100%; display:flex; flex-direction:column; gap:24px; min-width:0;">
          
          <!-- Net Worth glass card -->
          <div class="glass-card balance-container" style="margin:0;">
            <div class="balance-title">Net Worth</div>
            <div class="balance-value" style="color: ${data.netWorth >= 0 ? 'var(--success)' : 'var(--error)'}; font-size:32px;">
              ${Formatters.currency(data.netWorth)}
            </div>
            
            <div class="balance-stats-row" style="margin-top:24px;">
              <div class="balance-stat-item">
                <div class="balance-stat-label">Total Assets</div>
                <div class="balance-stat-val" style="color: var(--success); font-size:16px;">${Formatters.currency(data.totalAssets)}</div>
              </div>
              <div class="balance-stat-item" style="text-align: right;">
                <div class="balance-stat-label">Total Liabilities</div>
                <div class="balance-stat-val" style="color: var(--error); font-size:16px;">${Formatters.currency(data.totalLiabilities)}</div>
              </div>
            </div>
          </div>

          <!-- Net Worth Trend Chart Card -->
          <div class="glass-card">
            <h3 style="font-size: 15px; margin-bottom: 16px;">Net Worth Trend</h3>
            <div style="position: relative; height: 180px; width: 100%;">
              <canvas id="networth-trend-chart"></canvas>
            </div>
          </div>
        </div>

        <!-- Right Column: Assets & Liabilities List -->
        <div style="flex: 1 1 500px; display:flex; flex-direction:column; gap:16px; min-width:0;">
          
          <!-- Filter Controls & Add Asset Button -->
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <div class="tab-bar" style="padding: 2px; border-radius: 20px;">
              <button class="tab-button ${this.activeAssetFilter === 'all' ? 'active' : ''}" 
                      style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                      id="asset-filter-all">All</button>
              <button class="tab-button ${this.activeAssetFilter === 'assets' ? 'active' : ''}" 
                      style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                      id="asset-filter-assets">Assets</button>
              <button class="tab-button ${this.activeAssetFilter === 'liabilities' ? 'active' : ''}" 
                      style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                      id="asset-filter-liabilities">Liabilities</button>
            </div>

            <button class="btn btn-primary" id="networth-add-asset-btn" style="width:auto; padding: 8px 16px; font-size:12px;">
              <span class="material-icons" style="font-size:16px;">add</span>
              Add Asset
            </button>
          </div>

          <!-- Assets List Card -->
          <div class="glass-card" style="padding: 10px 20px; min-height:400px;">
            ${filteredAssets.length === 0 ? `
              <div style="text-align: center; padding: 60px 0; color: var(--text-muted); font-size: 14px;">
                <span class="material-icons" style="font-size: 48px; opacity:0.3; margin-bottom:12px;">account_balance</span><br>
                No assets or liabilities found.
              </div>
            ` : filteredAssets.map(asset => this.renderAssetRow(asset)).join('')}
          </div>
        </div>

      </div>
    `;
  },

  renderAssetRow(asset) {
    const emoji = IconHelper.getAssetEmoji(asset.type);
    const label = IconHelper.getAssetLabel(asset.type);
    const valColor = asset.isLiability ? 'var(--error)' : 'var(--success)';
    const amount = (asset.isLiability ? '-' : '') + Formatters.currency(asset.value);

    return `
      <div class="transaction-row" style="cursor:default;">
        <div class="transaction-icon-box" style="background: rgba(255, 255, 255, 0.05); font-size: 20px;">
          ${emoji}
        </div>
        <div class="tx-details">
          <div class="tx-note" style="font-weight:600;">${asset.name}</div>
          <div class="tx-category">${label}</div>
        </div>
        <div style="display:flex; align-items:center; gap:16px;">
          <div style="text-align: right;">
            <div class="tx-amount" style="color: ${valColor}; font-weight:700;">${amount}</div>
            <div class="tx-date" style="font-size:10px;">${asset.note || ''}</div>
          </div>
          <button class="btn-icon delete-asset-row-btn" 
                  style="width:32px; height:32px; font-size:16px; border:none; background:rgba(239,68,68,0.1); color:var(--error);"
                  data-sync-id="${asset.sync_id}"
                  data-id="${asset.id || ''}">
            <span class="material-icons" style="font-size:16px;">delete_outline</span>
          </button>
        </div>
      </div>
    `;
  },

  calculateNetWorthData(state) {
    let totalIncome = 0;
    let totalExpenses = 0;

    for (const tx of state.transactions) {
      if (tx.type === 'income') totalIncome += tx.amount;
      else totalExpenses += tx.amount;
    }

    const cashflow = totalIncome - totalExpenses;

    let totalAssets = 0;
    let totalLiabilities = 0;

    for (const asset of state.assets) {
      if (asset.is_liability === true || asset.isLiability === true) {
        totalLiabilities += asset.value;
      } else {
        totalAssets += asset.value;
      }
    }

    const netWorth = cashflow + totalAssets - totalLiabilities;

    return {
      netWorth,
      totalAssets,
      totalLiabilities
    };
  },

  getFilteredAssets(state) {
    return state.assets.filter(asset => {
      const isL = asset.is_liability === true || asset.isLiability === true;
      if (this.activeAssetFilter === 'assets') return !isL;
      if (this.activeAssetFilter === 'liabilities') return isL;
      return true;
    });
  },

  bindEvents(state) {
    // Filter controls
    const filterAll = document.getElementById('asset-filter-all');
    if (filterAll) {
      filterAll.addEventListener('click', () => {
        this.activeAssetFilter = 'all';
        StateManager.notify();
      });
    }

    const filterAssets = document.getElementById('asset-filter-assets');
    if (filterAssets) {
      filterAssets.addEventListener('click', () => {
        this.activeAssetFilter = 'assets';
        StateManager.notify();
      });
    }

    const filterLiabilities = document.getElementById('asset-filter-liabilities');
    if (filterLiabilities) {
      filterLiabilities.addEventListener('click', () => {
        this.activeAssetFilter = 'liabilities';
        StateManager.notify();
      });
    }

    // Add Asset click
    const addAssetBtn = document.getElementById('networth-add-asset-btn');
    if (addAssetBtn) {
      addAssetBtn.addEventListener('click', () => {
        this.showAddAssetModal();
      });
    }

    // Delete asset row buttons
    const deleteBtns = document.querySelectorAll('.delete-asset-row-btn');
    deleteBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = parseInt(btn.getAttribute('data-id'), 10) || null;
        if (confirm('Are you sure you want to delete this asset?')) {
          await DbService.deleteAsset(syncId, localId);
        }
      });
    });

    // Render Net Worth trend chart
    this.renderTrendChart(state);
  },

  showAddAssetModal() {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1E1E2C;">
        <div class="modal-header">
          <h3 style="color:#FFF;">Add Wealth Asset</h3>
          <button class="modal-close" id="asset-modal-close">&times;</button>
        </div>
        
        <div class="form-group">
          <label class="form-label">Asset Name</label>
          <input type="text" class="form-input" id="asset-name-field" placeholder="SBI Savings, Gold chain, etc.">
        </div>
        
        <div class="form-group">
          <label class="form-label">Asset Type</label>
          <select class="form-input" id="asset-type-field" style="background:var(--input-bg); color:#FFF; border:1px solid var(--input-border);">
            <option value="savings">💰 Savings Account</option>
            <option value="investment">📈 Mutual Funds/Stocks</option>
            <option value="gold">🥇 Gold</option>
            <option value="property">🏠 Property / Real Estate</option>
            <option value="loan">💳 Loan / Debt Liability</option>
            <option value="other">📦 Other Asset</option>
          </select>
        </div>
        
        <div class="form-group">
          <label class="form-label">Current Value (₹)</label>
          <input type="number" class="form-input" id="asset-value-field" placeholder="10000">
        </div>
        
        <div class="form-group">
          <label class="form-label">Note (Optional)</label>
          <input type="text" class="form-input" id="asset-note-field" placeholder="Description">
        </div>
        
        <div style="display:flex; gap:12px; justify-content:flex-end; margin-top:20px;">
          <button class="btn btn-outline" id="asset-cancel-btn" style="width:auto; padding:10px 20px;">Cancel</button>
          <button class="btn btn-primary" id="asset-save-btn" style="width:auto; padding:10px 20px;">Add Asset</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      document.body.removeChild(overlay);
    };

    document.getElementById('asset-modal-close').addEventListener('click', closeModal);
    document.getElementById('asset-cancel-btn').addEventListener('click', closeModal);

    document.getElementById('asset-save-btn').addEventListener('click', async () => {
      const name = document.getElementById('asset-name-field').value.trim();
      const type = document.getElementById('asset-type-field').value;
      const value = parseFloat(document.getElementById('asset-value-field').value) || 0;
      const note = document.getElementById('asset-note-field').value.trim();

      if (!name) {
        alert('Please enter asset name.');
        return;
      }
      if (value <= 0) {
        alert('Please enter value amount.');
        return;
      }

      const isLiability = type === 'loan';

      await DbService.addAsset({
        name,
        type,
        value,
        isLiability,
        is_liability: isLiability,
        note: note || null
      });

      closeModal();
    });
  },

  renderTrendChart(state) {
    const canvas = document.getElementById('networth-trend-chart');
    if (!canvas) return;

    if (networthChartInstance) networthChartInstance.destroy();

    // Group transactions by month to construct networth trends (replicates monthlyNetWorthProvider)
    const monthlyNet = {};
    for (const tx of state.transactions) {
      const date = new Date(tx.timestamp);
      const key = `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}`;
      if (!monthlyNet[key]) {
        monthlyNet[key] = { income: 0, expenses: 0 };
      }
      if (tx.type === 'income') {
        monthlyNet[key].income += tx.amount;
      } else {
        monthlyNet[key].expenses += tx.amount;
      }
    }

    const sortedMonths = Object.keys(monthlyNet).sort();
    let cumulative = 0;
    
    // Add current assets/liabilities to all-time initial networth baseline
    let assetsNetVal = 0;
    for (const asset of state.assets) {
      const val = asset.value || 0;
      const isL = asset.is_liability === true || asset.isLiability === true;
      if (isL) assetsNetVal -= val;
      else assetsNetVal += val;
    }

    const data = [];
    const labels = [];

    for (const month of sortedMonths) {
      const net = monthlyNet[month].income - monthlyNet[month].expenses;
      cumulative += net;
      
      const parts = month.split('-');
      const date = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, 1);
      const label = date.toLocaleDateString('en-US', { month: 'short', year: '2-digit' });
      
      labels.push(label);
      data.push(cumulative + assetsNetVal);
    }

    // Default mock data if no transactions
    if (labels.length === 0) {
      labels.push('Now');
      data.push(assetsNetVal);
    }

    networthChartInstance = new Chart(canvas, {
      type: 'line',
      data: {
        labels,
        datasets: [{
          data,
          borderColor: '#00C6FF', // Chakra Blue
          backgroundColor: 'rgba(0, 198, 255, 0.1)',
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointRadius: 3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: 'rgba(255, 255, 255, 0.5)', font: { size: 9 } }, grid: { display: false } },
          y: { ticks: { color: 'rgba(255, 255, 255, 0.5)', font: { size: 9 } }, grid: { color: 'rgba(255, 255, 255, 0.05)' } }
        }
      }
    });
  }
};
