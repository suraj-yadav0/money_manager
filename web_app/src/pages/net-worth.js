/* Modern Net Worth & Asset Intelligence Module */
import { Chart, registerables } from 'chart.js';
import { StateManager } from '../state.js';
import { DbService, reconcileInvestmentAssets } from '../db.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';
import { getTheme, isLightTheme, getThemePalette, hexToRgba } from '../utils/theme.js';

Chart.register(...registerables);

let trajectoryChartInstance = null;
let allocationChartInstance = null;
let projectionChartInstance = null;
let structureChartInstance = null;

const categoryIcons = {
  savings: 'account_balance',
  investment: 'trending_up',
  real_estate: 'domain',
  crypto: 'currency_bitcoin',
  vehicle: 'directions_car',
  loan: 'request_quote',
  credit_card: 'credit_card',
  other: 'category'
};

export const NetWorthPage = {
  selectedTimeframe: '6M',
  selectedAllocationView: 'class',
  selectedProjectionHorizon: '10Y',

  getTotals(state) {
    const assets = state.assets || [];
    const bankAccounts = state.bankAccounts || [];

    let totalAssets = 0;
    let totalLiabilities = 0;

    assets.forEach(a => {
      const val = Math.abs(Number(a.value || 0));
      if (a.is_liability || a.isLiability) {
        totalLiabilities += val;
      } else {
        totalAssets += val;
      }
    });

    bankAccounts.forEach(acc => {
      const bal = Number(acc.balance || 0);
      if (acc.account_type === 'credit_card' || acc.accountType === 'credit_card') {
        totalLiabilities += Math.abs(bal);
      } else {
        totalAssets += Math.max(0, bal);
      }
    });

    const netWorth = totalAssets - totalLiabilities;
    const debtRatio = totalAssets > 0 ? Math.round((totalLiabilities / totalAssets) * 100) : 0;
    const solvencyTier = debtRatio < 30 ? 'Pristine' : debtRatio < 60 ? 'Moderate' : 'Leveraged';

    return { totalAssets, totalLiabilities, netWorth, debtRatio, solvencyTier };
  },

  getTrajectoryData(state, timeframe = '6M') {
    const { netWorth: currentNetWorth } = this.getTotals(state);
    const now = new Date();

    let monthCount = 6;
    if (timeframe === '1Y') {
      monthCount = 12;
    } else if (timeframe === 'ALL') {
      const timestamps = (state.transactions || [])
        .map(t => new Date(t.timestamp).getTime())
        .filter(t => !isNaN(t));

      if (timestamps.length > 0) {
        const earliest = new Date(Math.min(...timestamps));
        const diff = (now.getFullYear() - earliest.getFullYear()) * 12 + (now.getMonth() - earliest.getMonth()) + 1;
        monthCount = Math.min(36, Math.max(6, diff));
      } else {
        monthCount = 6;
      }
    }

    const months = [];
    for (let i = monthCount - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      const label = d.toLocaleDateString('en-US', { month: 'short', year: monthCount > 6 ? '2-digit' : undefined });
      const fullLabel = d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
      months.push({ key, label, fullLabel, date: d });
    }

    const monthlyStats = {};
    months.forEach(m => {
      monthlyStats[m.key] = { inflow: 0, outflow: 0, net: 0 };
    });

    (state.transactions || []).forEach(tx => {
      if (!tx.timestamp) return;
      const d = new Date(tx.timestamp);
      if (isNaN(d.getTime())) return;
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      if (monthlyStats[key]) {
        const amt = Number(tx.amount || 0);
        if (tx.type === 'income') {
          monthlyStats[key].inflow += amt;
        } else {
          monthlyStats[key].outflow += amt;
        }
        monthlyStats[key].net = monthlyStats[key].inflow - monthlyStats[key].outflow;
      }
    });

    // Anchor to current net worth at the latest month and back-propagate
    const values = new Array(monthCount);
    values[monthCount - 1] = currentNetWorth;

    for (let i = monthCount - 1; i > 0; i--) {
      const currentKey = months[i].key;
      const currentNet = monthlyStats[currentKey] ? monthlyStats[currentKey].net : 0;
      values[i - 1] = values[i] - currentNet;
    }

    const startNetWorth = values[0];
    const endNetWorth = values[monthCount - 1];
    const periodDelta = endNetWorth - startNetWorth;
    const periodDeltaPercent = startNetWorth !== 0
      ? ((periodDelta / Math.abs(startNetWorth)) * 100).toFixed(1)
      : (periodDelta > 0 ? 100 : periodDelta < 0 ? -100 : 0);
    const avgMonthlyGain = Math.round(periodDelta / Math.max(1, monthCount - 1));
    const peakNetWorth = Math.max(...values);

    return {
      months,
      labels: months.map(m => m.label),
      fullLabels: months.map(m => m.fullLabel),
      values,
      monthlyStats,
      summary: {
        startNetWorth,
        endNetWorth,
        periodDelta,
        periodDeltaPercent,
        avgMonthlyGain,
        peakNetWorth
      }
    };
  },

  getAllocationData(state, viewType = 'class') {
    const totals = this.getTotals(state);
    const { totalAssets, totalLiabilities, netWorth, debtRatio } = totals;

    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = isLightTheme(activeTheme);
    const palette = getThemePalette(activeTheme);

    if (viewType === 'solvency') {
      const equity = Math.max(0, netWorth);
      const liabilities = totalLiabilities;
      const total = equity + liabilities;

      const equityPct = total > 0 ? Math.round((equity / total) * 100) : 100;
      const debtPct = total > 0 ? 100 - equityPct : 0;

      const items = [
        {
          name: 'Net Equity',
          value: equity,
          percent: equityPct,
          color: palette[0],
          icon: 'verified_user'
        },
        {
          name: 'Total Liabilities',
          value: liabilities,
          percent: debtPct,
          color: palette[3],
          icon: 'credit_card'
        }
      ];

      return {
        viewType: 'solvency',
        total,
        centerLabel: 'Debt Ratio',
        centerValue: `${debtRatio}%`,
        labels: items.map(i => i.name),
        values: items.map(i => i.value),
        colors: items.map(i => i.color),
        items
      };
    }

    const categoryLabels = {
      savings: 'Cash & Liquid',
      investment: 'Investments',
      real_estate: 'Real Estate',
      crypto: 'Crypto Assets',
      vehicle: 'Vehicles',
      other: 'Other Holdings'
    };

    const categoryTotals = {
      savings: 0,
      investment: 0,
      real_estate: 0,
      crypto: 0,
      vehicle: 0,
      other: 0
    };

    const categoryHoldings = {
      savings: [],
      investment: [],
      real_estate: [],
      crypto: [],
      vehicle: [],
      other: []
    };

    (state.bankAccounts || []).forEach(acc => {
      const isCredit = acc.account_type === 'credit_card' || acc.accountType === 'credit_card';
      if (!isCredit) {
        const bal = Number(acc.balance || 0);
        categoryTotals.savings += bal;
        categoryHoldings.savings.push({
          isBank: true,
          data: acc,
          name: acc.name,
          subtitle: acc.account_type || 'Liquid Cash / Bank',
          value: bal
        });
      }
    });

    (state.assets || []).forEach(a => {
      const isLiab = a.is_liability || a.isLiability;
      if (!isLiab) {
        const val = Number(a.value || 0);
        const type = a.type || 'other';
        const targetType = categoryTotals[type] !== undefined ? type : 'other';
        categoryTotals[targetType] += val;
        categoryHoldings[targetType].push({
          isBank: false,
          data: a,
          name: a.name,
          subtitle: a.classification || a.category || 'Asset Holding',
          value: val
        });
      }
    });

    const activeEntries = Object.entries(categoryTotals)
      .filter(([_, val]) => val > 0)
      .sort((a, b) => b[1] - a[1]);

    const items = activeEntries.map(([key, val], idx) => {
      const name = categoryLabels[key] || categoryLabels.other;
      const percent = totalAssets > 0 ? Math.round((val / totalAssets) * 100) : 0;
      return {
        key,
        name,
        icon: categoryIcons[key] || 'category',
        value: val,
        percent,
        color: palette[idx % palette.length],
        holdings: categoryHoldings[key] || []
      };
    });

    return {
      viewType: 'class',
      total: totalAssets,
      centerLabel: 'Gross Assets',
      centerValue: Formatters.compactCurrency(totalAssets),
      labels: items.map(i => i.name),
      values: items.map(i => i.value),
      colors: items.map(i => i.color),
      items
    };
  },

  render(state) {
    reconcileInvestmentAssets(state);
    const totals = this.getTotals(state);
    const { totalAssets, totalLiabilities, netWorth, debtRatio, solvencyTier } = totals;

    const rawAssets = state.assets || [];
    const bankAccounts = state.bankAccounts || [];

    const formatTypeLabel = (type) => {
      const map = {
        savings: 'Savings',
        cash: 'Cash Wallet',
        checking: 'Checking',
        credit_card: 'Credit Card',
        investment: 'Investment',
        real_estate: 'Real Estate',
        crypto: 'Crypto',
        vehicle: 'Vehicle',
        loan: 'Personal Loan',
        other: 'Other'
      };
      return map[type] || (type ? type.charAt(0).toUpperCase() + type.slice(1).replace(/_/g, ' ') : 'Asset');
    };

    const assetItems = [
      ...bankAccounts
        .filter(acc => acc.account_type !== 'credit_card' && acc.accountType !== 'credit_card')
        .map(acc => ({
          name: acc.name || 'Bank Account',
          typeLabel: formatTypeLabel(acc.account_type || acc.accountType || 'savings'),
          icon: 'account_balance',
          value: Number(acc.balance || 0),
          isBank: true,
          sync_id: acc.sync_id || '',
          id: acc.id || ''
        })),
      ...rawAssets
        .filter(a => !(a.is_liability || a.isLiability))
        .map(a => ({
          ...a,
          typeLabel: formatTypeLabel(a.type),
          icon: categoryIcons[a.type] || 'account_balance_wallet',
          isBank: false
        }))
    ];

    const liabilityItems = [
      ...bankAccounts
        .filter(acc => acc.account_type === 'credit_card' || acc.accountType === 'credit_card')
        .map(acc => ({
          name: acc.name || 'Credit Card',
          typeLabel: 'Credit Card',
          icon: 'credit_card',
          value: Math.abs(Number(acc.balance || 0)),
          isBank: true,
          sync_id: acc.sync_id || '',
          id: acc.id || ''
        })),
      ...rawAssets
        .filter(a => a.is_liability || a.isLiability)
        .map(a => ({
          ...a,
          value: Math.abs(Number(a.value || 0)),
          typeLabel: formatTypeLabel(a.type || 'loan'),
          icon: categoryIcons[a.type] || 'request_quote',
          isBank: false
        }))
    ];

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 24px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Net Worth & Wealth Matrix</h1>
              <p class="hero-subtitle">Holistic balance sheet evaluation, capital assets, investment portfolios, and liability exposure.</p>
            </div>
            
            <button class="btn-primary" id="add-asset-btn" style="align-self: flex-start;">
              <span class="material-icons" style="font-size: 18px;">add</span> Add Asset / Debt
            </button>
          </div>

          <!-- Net Worth KPI Stat Cards -->
          <div class="kpi-grid">
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Consolidated Net Worth</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">account_balance</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(netWorth)}</div>
              <div class="kpi-footer">
                <span class="kpi-badge positive">
                  ${debtRatio}% Debt Ratio
                </span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Gross Capital Assets</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">trending_up</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(totalAssets)}</div>
              <div class="kpi-footer">
                <span>${assetItems.length} Holdings</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Liabilities</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">trending_down</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(totalLiabilities)}</div>
              <div class="kpi-footer">
                <span>${liabilityItems.length} Active Debts</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Solvency Status</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">verified</span>
                </div>
              </div>
              <div class="kpi-value">${solvencyTier}</div>
              <div class="kpi-footer">
                <span>Leverage tier</span>
              </div>
            </div>
          </div>
        </section>

        <!-- Net Worth Visual Analytics and Charts -->
        <div class="nw-charts-grid">
          
          <!-- Net Worth Trajectory Chart Card -->
          <div class="fintech-card nw-chart-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">show_chart</span>
                <span>Net Worth Trajectory</span>
              </div>
              <div class="card-header-actions">
                <span class="kpi-badge neutral drilldown-hint" style="font-size: 11px; font-weight: 600;" title="Click to drill down">
                  <span class="material-icons" style="font-size: 12px; margin-right: 3px;">touch_app</span><span class="hint-text">Click to drill down</span>
                </span>
                <div class="filter-group" style="padding: 2px;">
                  <button class="filter-chip ${this.selectedTimeframe === '6M' ? 'active' : ''}" data-nw-timeframe="6M">6M</button>
                  <button class="filter-chip ${this.selectedTimeframe === '1Y' ? 'active' : ''}" data-nw-timeframe="1Y">1Y</button>
                  <button class="filter-chip ${this.selectedTimeframe === 'ALL' ? 'active' : ''}" data-nw-timeframe="ALL">ALL</button>
                </div>
              </div>
            </div>

            <!-- Dynamic Trajectory Metric Bar -->
            <div id="nw-trajectory-metrics" class="nw-stats-bar"></div>

            <div style="position: relative; height: 260px; width: 100%; max-width: 100%; min-width: 0; overflow: hidden;">
              <canvas id="networth-trend-canvas"></canvas>
            </div>
          </div>

          <!-- Asset Allocation & Capital Structure Card -->
          <div class="fintech-card nw-chart-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">pie_chart</span>
                <span id="nw-allocation-title">${this.selectedAllocationView === 'solvency' ? 'Capital Solvency' : 'Asset Allocation'}</span>
              </div>
              <div class="card-header-actions">
                <span class="kpi-badge neutral drilldown-hint" style="font-size: 11px; font-weight: 600;" title="Click to drill down">
                  <span class="material-icons" style="font-size: 12px; margin-right: 3px;">touch_app</span><span class="hint-text">Click to drill down</span>
                </span>
                <div class="filter-group" style="padding: 2px;">
                  <button class="filter-chip ${this.selectedAllocationView === 'class' ? 'active' : ''}" data-nw-alloc-view="class">Asset Mix</button>
                  <button class="filter-chip ${this.selectedAllocationView === 'solvency' ? 'active' : ''}" data-nw-alloc-view="solvency">Solvency</button>
                </div>
              </div>
            </div>

            <!-- Dynamic Donut Chart & Legend -->
            <div id="nw-allocation-content" style="display: flex; flex-direction: column; flex: 1; justify-content: center;"></div>
          </div>
        </div>

        <!-- Forward Wealth Intelligence & Capital Structure Grid -->
        <div class="nw-charts-grid" style="margin-top: 2px;">
          <!-- 1. Compound Wealth Growth Simulator -->
          <div class="fintech-card nw-chart-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">auto_graph</span>
                <span>Compound Wealth Simulator</span>
              </div>
              <div class="card-header-actions">
                <div class="filter-group" style="padding: 2px;" id="nw-projection-horizon-group">
                  <button class="filter-chip ${this.selectedProjectionHorizon === '5Y' ? 'active' : ''}" data-horizon="5Y">5 Years</button>
                  <button class="filter-chip ${this.selectedProjectionHorizon === '10Y' ? 'active' : ''}" data-horizon="10Y">10 Years</button>
                  <button class="filter-chip ${this.selectedProjectionHorizon === '20Y' ? 'active' : ''}" data-horizon="20Y">20 Years</button>
                </div>
              </div>
            </div>

            <!-- Dynamic Projection Metric Badges -->
            <div id="nw-projection-metrics" class="nw-stats-bar" style="grid-template-columns: repeat(3, 1fr);"></div>

            <div style="position: relative; height: 260px; width: 100%; max-width: 100%; min-width: 0; overflow: hidden;">
              <canvas id="networth-projection-canvas"></canvas>
            </div>
          </div>

          <!-- 2. Capital Structure & Liquidity Coverage -->
          <div class="fintech-card nw-chart-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">account_balance_wallet</span>
                <span>Capital Structure & Liquidity Runway</span>
              </div>
              <div class="card-header-actions">
                <span class="kpi-badge neutral" id="nw-runway-badge" style="font-size: 11px; font-weight: 600;">
                  Calculating runway...
                </span>
              </div>
            </div>

            <!-- Dynamic Liquidity Metric Bar -->
            <div id="nw-structure-metrics" class="nw-stats-bar" style="grid-template-columns: repeat(3, 1fr);"></div>

            <div style="position: relative; height: 260px; width: 100%; max-width: 100%; min-width: 0; overflow: hidden;">
              <canvas id="networth-structure-canvas"></canvas>
            </div>
          </div>
        </div>

        <!-- Assets & Liabilities Holdings Detail Grid -->
        <div class="dashboard-split-grid">
          
          <!-- Assets Column -->
          <div class="fintech-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">account_balance_wallet</span>
                <span>Assets & Holdings (${Formatters.currency(totalAssets)})</span>
              </div>
            </div>

            <div class="assets-grid">
              ${assetItems.length === 0 ? `
                <div style="grid-column: 1 / -1; text-align: center; padding: 28px 0; color: var(--text-muted); font-size: 13px;">
                  No asset records added yet. Add bank accounts, investments, or properties.
                </div>
              ` : assetItems.map(a => `
                <div class="asset-card" data-is-bank="${a.isBank ? 'true' : 'false'}" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}">
                  <div class="asset-card-left">
                    <div class="asset-card-icon-box">
                      <span class="material-icons" style="font-size: 19px; color: var(--text-primary);">${a.icon}</span>
                    </div>
                    <div class="asset-card-info">
                      <div class="asset-card-name" title="${a.name}">${a.name}</div>
                      <div class="asset-card-meta">
                        <span class="asset-category-pill">${a.typeLabel}</span>
                        ${a.isBank ? `<span class="asset-account-pill">Account</span>` : ''}
                      </div>
                    </div>
                  </div>
                  <div class="asset-card-right">
                    <div class="asset-card-value">${Formatters.currency(a.value)}</div>
                    <div class="asset-card-actions">
                      <button class="btn-icon btn-icon-sm edit-holding-btn" data-is-bank="${a.isBank ? 'true' : 'false'}" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Edit holding">
                        <span class="material-icons" style="font-size: 16px;">edit</span>
                      </button>
                      ${!a.isBank ? `
                        <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Delete asset">
                          <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                        </button>
                      ` : `
                        <button class="btn-icon btn-icon-sm delete-bank-btn" data-sync-id="${a.sync_id || a.id || ''}" title="Delete account">
                          <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                        </button>
                      `}
                    </div>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- Liabilities Column -->
          <div class="fintech-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">credit_card</span>
                <span>Liabilities & Debts (${Formatters.currency(totalLiabilities)})</span>
              </div>
            </div>

            <div class="assets-grid">
              ${liabilityItems.length === 0 ? `
                <div style="grid-column: 1 / -1; text-align: center; padding: 28px 0; color: var(--text-muted); font-size: 13px;">
                  Zero liabilities recorded. You have a 100% debt-free profile!
                </div>
              ` : liabilityItems.map(a => `
                <div class="asset-card" data-is-bank="${a.isBank ? 'true' : 'false'}" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}">
                  <div class="asset-card-left">
                    <div class="asset-card-icon-box">
                      <span class="material-icons" style="font-size: 19px; color: var(--text-secondary);">${a.icon}</span>
                    </div>
                    <div class="asset-card-info">
                      <div class="asset-card-name" title="${a.name}">${a.name}</div>
                      <div class="asset-card-meta">
                        <span class="asset-category-pill">${a.typeLabel}</span>
                        ${a.isBank ? `<span class="asset-account-pill">Card</span>` : ''}
                      </div>
                    </div>
                  </div>
                  <div class="asset-card-right">
                    <div class="asset-card-value" style="color: var(--text-secondary);">${Formatters.currency(a.value)}</div>
                    <div class="asset-card-actions">
                      <button class="btn-icon btn-icon-sm edit-holding-btn" data-is-bank="${a.isBank ? 'true' : 'false'}" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Edit holding">
                        <span class="material-icons" style="font-size: 16px;">edit</span>
                      </button>
                      ${!a.isBank ? `
                        <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Delete liability">
                          <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                        </button>
                      ` : `
                        <button class="btn-icon btn-icon-sm delete-bank-btn" data-sync-id="${a.sync_id || a.id || ''}" title="Delete account">
                          <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                        </button>
                      `}
                    </div>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

        </div>
      </div>
    `;
  },

  bindEvents(state) {
    document.getElementById('add-asset-btn')?.addEventListener('click', () => {
      this.showAddAssetModal();
    });

    const deleteBtns = document.querySelectorAll('.delete-asset-btn');
    deleteBtns.forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const syncId = btn.getAttribute('data-sync-id');
        const localId = btn.getAttribute('data-id');
        if (confirm('Delete this asset/liability entry?')) {
          await DbService.deleteAsset(syncId, localId);
        }
      });
    });

    const deleteBankBtns = document.querySelectorAll('.delete-bank-btn');
    deleteBankBtns.forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const syncId = btn.getAttribute('data-sync-id');
        if (confirm('Delete this account/card entry?')) {
          await DbService.deleteBankAccount(syncId);
        }
      });
    });

    const handleEditHolding = (targetEl) => {
      const isBank = targetEl.getAttribute('data-is-bank') === 'true';
      const syncId = targetEl.getAttribute('data-sync-id');
      const localId = targetEl.getAttribute('data-id');

      if (isBank) {
        const bankAcc = (state.bankAccounts || []).find(a => 
          (syncId && String(a.sync_id) === String(syncId)) || (localId && String(a.id) === String(localId))
        );
        if (bankAcc) {
          this.showEditBankModal(bankAcc);
        }
      } else {
        const asset = (state.assets || []).find(a => 
          (syncId && String(a.sync_id) === String(syncId)) || (localId && String(a.id) === String(localId))
        );
        if (asset) {
          this.showEditAssetModal(asset);
        }
      }
    };

    document.querySelectorAll('.edit-holding-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        handleEditHolding(btn);
      });
    });

    document.querySelectorAll('.asset-card').forEach(card => {
      card.addEventListener('click', (e) => {
        if (e.target.closest('button')) return;
        handleEditHolding(card);
      });
    });

    // Timeframe selector for trajectory chart
    const timeframeChips = document.querySelectorAll('.filter-chip[data-nw-timeframe]');
    timeframeChips.forEach(chip => {
      chip.addEventListener('click', () => {
        const tf = chip.getAttribute('data-nw-timeframe');
        this.selectedTimeframe = tf;
        timeframeChips.forEach(c => c.classList.toggle('active', c === chip));
        this.renderTrajectoryChart(state);
      });
    });

    // Allocation view selector
    const allocChips = document.querySelectorAll('.filter-chip[data-nw-alloc-view]');
    allocChips.forEach(chip => {
      chip.addEventListener('click', () => {
        const view = chip.getAttribute('data-nw-alloc-view');
        this.selectedAllocationView = view;
        allocChips.forEach(c => c.classList.toggle('active', c === chip));
        const titleEl = document.getElementById('nw-allocation-title');
        if (titleEl) {
          titleEl.textContent = view === 'solvency' ? 'Capital Solvency' : 'Asset Allocation';
        }
        this.renderAllocationChart(state);
      });
    });

    // Projection horizon selector
    const horizonChips = document.querySelectorAll('#nw-projection-horizon-group [data-horizon]');
    horizonChips.forEach(chip => {
      chip.addEventListener('click', () => {
        const horizon = chip.getAttribute('data-horizon');
        this.selectedProjectionHorizon = horizon;
        horizonChips.forEach(c => c.classList.toggle('active', c === chip));
        this.renderWealthProjectionChart(state);
      });
    });

    this.renderCharts(state);
  },

  renderCharts(state) {
    this.renderTrajectoryChart(state);
    this.renderAllocationChart(state);
    this.renderWealthProjectionChart(state);
    this.renderCapitalStructureChart(state);
  },

  renderTrajectoryChart(state) {
    const canvas = document.getElementById('networth-trend-canvas');
    if (!canvas) return;

    if (trajectoryChartInstance) {
      trajectoryChartInstance.destroy();
      trajectoryChartInstance = null;
    }

    const trajectory = this.getTrajectoryData(state, this.selectedTimeframe);

    const metricsEl = document.getElementById('nw-trajectory-metrics');
    if (metricsEl) {
      const isPositive = trajectory.summary.periodDelta >= 0;
      const sign = isPositive ? '+' : '';
      metricsEl.innerHTML = `
        <div class="nw-stat-item">
          <span class="nw-stat-label">Period Growth</span>
          <span class="nw-stat-val" style="color: ${isPositive ? 'var(--text-primary)' : 'var(--text-secondary)'};">
            <span class="material-icons" style="font-size: 15px;">${isPositive ? 'trending_up' : 'trending_down'}</span>
            ${sign}${Formatters.currency(trajectory.summary.periodDelta)} (${sign}${trajectory.summary.periodDeltaPercent}%)
          </span>
        </div>
        <div class="nw-stat-item">
          <span class="nw-stat-label">Monthly Velocity</span>
          <span class="nw-stat-val">
            ${sign}${Formatters.currency(trajectory.summary.avgMonthlyGain)}/mo
          </span>
        </div>
        <div class="nw-stat-item">
          <span class="nw-stat-label">Period Peak</span>
          <span class="nw-stat-val">
            ${Formatters.currency(trajectory.summary.peakNetWorth)}
          </span>
        </div>
      `;
    }

    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = isLightTheme(activeTheme);
    const themeObj = getTheme(activeTheme);
    const primaryColor = themeObj.primary || (isLight ? '#0F172A' : '#FFFFFF');
    const textColor = isLight ? '#475569' : '#94A3B8';
    const gridColor = isLight ? 'rgba(0, 0, 0, 0.05)' : 'rgba(255, 255, 255, 0.05)';
    const tooltipBg = isLight ? '#FFFFFF' : (themeObj.surface || '#11141E');
    const tooltipTitle = isLight ? '#0F172A' : (themeObj.primary || '#FFFFFF');
    const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)';
    const lineColor = primaryColor;

    const ctx = canvas.getContext('2d');
    const gradient = ctx.createLinearGradient(0, 0, 0, 240);
    gradient.addColorStop(0, hexToRgba(primaryColor, isLight ? 0.14 : 0.22));
    gradient.addColorStop(1, 'transparent');

    const allIdentical = trajectory.values.length > 0 &&
      trajectory.values.every(v => v === trajectory.values[0]);

    trajectoryChartInstance = new Chart(canvas, {
      type: 'line',
      data: {
        labels: trajectory.labels,
        datasets: [{
          label: 'Net Worth',
          data: trajectory.values,
          borderColor: lineColor,
          backgroundColor: gradient,
          borderWidth: 2.2,
          tension: 0.35,
          fill: true,
          pointRadius: trajectory.labels.length > 18 ? 0 : 3.5,
          pointHoverRadius: 6,
          pointBackgroundColor: lineColor,
          pointBorderColor: isLight ? '#FFFFFF' : '#111215',
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        onHover: (event, activeElements) => {
          if (event.native && event.native.target) {
            event.native.target.style.cursor = activeElements.length ? 'pointer' : 'default';
          }
        },
        onClick: (event, elements) => {
          if (!elements || !elements.length) return;
          const idx = elements[0].index;
          const month = trajectory.months[idx];
          const fullLabel = trajectory.fullLabels[idx] || trajectory.labels[idx];
          const netWorthVal = trajectory.values[idx];
          const stat = trajectory.monthlyStats[month?.key];
          this.showTrajectoryDrillDown(fullLabel, month, netWorthVal, stat, state);
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: tooltipBg,
            titleColor: tooltipTitle,
            bodyColor: textColor,
            borderColor: tooltipBorder,
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              title: (items) => {
                if (!items.length) return '';
                const idx = items[0].dataIndex;
                return trajectory.fullLabels[idx] || items[0].label;
              },
              label: (ctx) => ` Consolidated Net Worth: ${Formatters.currency(ctx.parsed.y)}`,
              afterLabel: (ctx) => {
                const idx = ctx.dataIndex;
                const month = trajectory.months[idx];
                if (!month) return '';
                const stat = trajectory.monthlyStats[month.key];
                if (!stat) return '';
                if (stat.inflow === 0 && stat.outflow === 0) return '';
                const sign = stat.net >= 0 ? '+' : '';
                return ` Monthly Delta: ${sign}${Formatters.currency(stat.net)}\n Inflows: ${Formatters.currency(stat.inflow)} | Outflows: ${Formatters.currency(stat.outflow)}`;
              }
            }
          }
        },
        scales: {
          x: {
            grid: { color: gridColor },
            ticks: {
              color: textColor,
              font: { family: 'Plus Jakarta Sans', size: 11 },
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 8
            }
          },
          y: {
            grid: { color: gridColor },
            suggestedMin: allIdentical
              ? (trajectory.values[0] > 0 ? trajectory.values[0] * 0.85 : (trajectory.values[0] === 0 ? 0 : trajectory.values[0] * 1.15))
              : undefined,
            suggestedMax: allIdentical
              ? (trajectory.values[0] > 0 ? trajectory.values[0] * 1.15 : (trajectory.values[0] === 0 ? 10000 : trajectory.values[0] * 0.85))
              : undefined,
            ticks: {
              color: textColor,
              font: { family: 'Plus Jakarta Sans', size: 11 },
              callback: (val) => Formatters.compactCurrency(val)
            }
          }
        }
      }
    });
  },

  renderAllocationChart(state) {
    const contentEl = document.getElementById('nw-allocation-content');
    if (!contentEl) return;

    if (allocationChartInstance) {
      allocationChartInstance.destroy();
      allocationChartInstance = null;
    }

    const data = this.getAllocationData(state, this.selectedAllocationView);

    if (data.items.length === 0 || data.total === 0) {
      contentEl.innerHTML = `
        <div style="text-align: center; padding: 40px 16px; color: var(--text-muted);">
          <div style="width: 44px; height: 44px; border-radius: 50%; background: var(--bg-surface-subtle); display: flex; align-items: center; justify-content: center; margin: 0 auto 12px;">
            <span class="material-icons" style="font-size: 22px; opacity: 0.6;">pie_chart</span>
          </div>
          <div style="font-size: 13.5px; font-weight: 700; color: var(--text-primary); margin-bottom: 4px;">No capital assets recorded</div>
          <div style="font-size: 12px; margin-bottom: 16px;">Add bank accounts, investments, or physical assets to visualize distribution.</div>
          <button class="btn-primary btn-sm" id="empty-add-asset-btn" style="width: auto; margin: 0 auto; display: inline-flex; align-items: center; gap: 6px;">
            <span class="material-icons" style="font-size: 15px;">add</span> Add Asset
          </button>
        </div>
      `;
      document.getElementById('empty-add-asset-btn')?.addEventListener('click', () => {
        this.showAddAssetModal();
      });
      return;
    }

    contentEl.innerHTML = `
      <div class="nw-donut-container">
        <canvas id="networth-allocation-canvas"></canvas>
        <div class="nw-donut-center">
          <div class="nw-donut-center-label">${data.centerLabel}</div>
          <div class="nw-donut-center-val">${data.centerValue}</div>
        </div>
      </div>

      <div class="nw-legend-list">
        ${data.items.map(item => `
          <div class="nw-legend-row">
            <div class="nw-legend-left">
              <span class="nw-color-dot" style="background: ${item.color};"></span>
              <span class="nw-legend-name">${item.name}</span>
            </div>
            <div class="nw-legend-right">
              <span class="nw-legend-val">${Formatters.currency(item.value)}</span>
              <span class="nw-legend-pct">${item.percent}%</span>
            </div>
          </div>
        `).join('')}
      </div>
    `;

    const canvas = document.getElementById('networth-allocation-canvas');
    if (!canvas) return;

    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = isLightTheme(activeTheme);
    const themeObj = getTheme(activeTheme);
    const textColor = isLight ? '#475569' : '#94A3B8';
    const tooltipBg = isLight ? '#FFFFFF' : (themeObj.surface || '#11141E');
    const tooltipTitle = isLight ? '#0F172A' : (themeObj.primary || '#FFFFFF');
    const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)';

    allocationChartInstance = new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: data.labels,
        datasets: [{
          data: data.values,
          backgroundColor: data.colors,
          borderWidth: 0,
          hoverOffset: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '72%',
        onHover: (event, activeElements) => {
          if (event.native && event.native.target) {
            event.native.target.style.cursor = activeElements.length ? 'pointer' : 'default';
          }
          const centerLabelEl = contentEl.querySelector('.nw-donut-center-label');
          const centerValEl = contentEl.querySelector('.nw-donut-center-val');
          const legendRows = contentEl.querySelectorAll('.nw-legend-row');

          if (activeElements && activeElements.length > 0) {
            const idx = activeElements[0].index;
            const item = data.items[idx];
            if (item) {
              if (centerLabelEl) centerLabelEl.textContent = `${item.name} (${item.percent}%)`;
              if (centerValEl) centerValEl.textContent = Formatters.currency(item.value);
              legendRows.forEach((row, rIdx) => {
                const active = rIdx === idx;
                row.style.background = active ? 'var(--bg-surface-hover)' : 'var(--bg-surface-subtle)';
                row.style.borderColor = active ? item.color : 'var(--glass-border)';
              });
              return;
            }
          }

          if (centerLabelEl) centerLabelEl.textContent = data.centerLabel;
          if (centerValEl) centerValEl.textContent = data.centerValue;
          legendRows.forEach(row => {
            row.style.background = 'var(--bg-surface-subtle)';
            row.style.borderColor = 'var(--glass-border)';
          });
        },
        onClick: (event, elements) => {
          if (!elements || !elements.length) return;
          const idx = elements[0].index;
          const item = data.items[idx];
          if (item) {
            this.showAllocationDrillDown(item, state);
          }
        },
        plugins: {
          legend: { display: false },
          tooltip: { enabled: false }
        }
      }
    });

    canvas.addEventListener('mouseleave', () => {
      const centerLabelEl = contentEl.querySelector('.nw-donut-center-label');
      const centerValEl = contentEl.querySelector('.nw-donut-center-val');
      if (centerLabelEl) centerLabelEl.textContent = data.centerLabel;
      if (centerValEl) centerValEl.textContent = data.centerValue;
      const legendRows = contentEl.querySelectorAll('.nw-legend-row');
      legendRows.forEach(row => {
        row.style.background = 'var(--bg-surface-subtle)';
        row.style.borderColor = 'var(--glass-border)';
      });
    });

    // Interactive bidirectional link from legend rows to doughnut slices
    const legendRows = contentEl.querySelectorAll('.nw-legend-row');
    legendRows.forEach((row, idx) => {
      row.style.cursor = 'pointer';
      row.title = 'Click to drill down into this asset class';
      row.addEventListener('click', () => {
        const item = data.items[idx];
        if (item) {
          this.showAllocationDrillDown(item, state);
        }
      });
      row.addEventListener('mouseenter', () => {
        const item = data.items[idx];
        if (!item) return;
        const centerLabelEl = contentEl.querySelector('.nw-donut-center-label');
        const centerValEl = contentEl.querySelector('.nw-donut-center-val');
        if (centerLabelEl) centerLabelEl.textContent = `${item.name} (${item.percent}%)`;
        if (centerValEl) centerValEl.textContent = Formatters.currency(item.value);
        row.style.background = 'var(--bg-surface-hover)';
        row.style.borderColor = item.color;
        if (allocationChartInstance) {
          allocationChartInstance.setActiveElements([{ datasetIndex: 0, index: idx }]);
          allocationChartInstance.update();
        }
      });

      row.addEventListener('mouseleave', () => {
        const centerLabelEl = contentEl.querySelector('.nw-donut-center-label');
        const centerValEl = contentEl.querySelector('.nw-donut-center-val');
        if (centerLabelEl) centerLabelEl.textContent = data.centerLabel;
        if (centerValEl) centerValEl.textContent = data.centerValue;
        row.style.background = 'var(--bg-surface-subtle)';
        row.style.borderColor = 'var(--glass-border)';
        if (allocationChartInstance) {
          allocationChartInstance.setActiveElements([]);
          allocationChartInstance.update();
        }
      });
    });
  },

  renderWealthProjectionChart(state) {
    const canvas = document.getElementById('networth-projection-canvas');
    if (!canvas) return;

    if (projectionChartInstance) {
      projectionChartInstance.destroy();
      projectionChartInstance = null;
    }

    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = isLightTheme(activeTheme);
    const themeObj = getTheme(activeTheme);
    const primaryColor = themeObj.primary || (isLight ? '#0F172A' : '#FFFFFF');
    const textColor = isLight ? '#475569' : '#94A3B8';
    const gridColor = isLight ? 'rgba(0, 0, 0, 0.05)' : 'rgba(255, 255, 255, 0.05)';
    const tooltipBg = isLight ? '#FFFFFF' : (themeObj.surface || '#11141E');
    const tooltipTitle = isLight ? '#0F172A' : (themeObj.primary || '#FFFFFF');
    const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)';

    const totals = this.getTotals(state);
    const currentPrincipal = Math.max(0, totals.netWorth);

    // Compute monthly net savings contribution
    const trajectory = this.getTrajectoryData(state, '6M');
    let avgMonthlySavings = 0;
    if (trajectory && trajectory.summary && trajectory.summary.avgMonthlyGain > 0) {
      avgMonthlySavings = trajectory.summary.avgMonthlyGain;
    } else {
      const monthlyIncome = state.userSettings?.monthlyIncome || 0;
      avgMonthlySavings = monthlyIncome > 0 ? monthlyIncome * 0.2 : 1000;
    }

    const horizon = this.selectedProjectionHorizon || '10Y';
    const maxYears = horizon === '5Y' ? 5 : horizon === '20Y' ? 20 : 10;
    const yearPoints = [];
    const step = maxYears === 20 ? 2 : 1;
    for (let y = 0; y <= maxYears; y += step) {
      yearPoints.push(y);
    }

    const calculateFv = (principal, annualRate, monthlyPmt, years) => {
      if (years === 0) return principal;
      const rm = annualRate / 12;
      const n = years * 12;
      return Math.round(principal * Math.pow(1 + rm, n) + monthlyPmt * ((Math.pow(1 + rm, n) - 1) / rm));
    };

    const labels = yearPoints.map(y => (y === 0 ? 'Now' : `Yr ${y}`));
    const conservativeData = yearPoints.map(y => calculateFv(currentPrincipal, 0.06, avgMonthlySavings, y));
    const balancedData = yearPoints.map(y => calculateFv(currentPrincipal, 0.10, avgMonthlySavings, y));
    const aggressiveData = yearPoints.map(y => calculateFv(currentPrincipal, 0.14, avgMonthlySavings, y));

    const finalConservative = conservativeData[conservativeData.length - 1];
    const finalBalanced = balancedData[balancedData.length - 1];
    const finalAggressive = aggressiveData[aggressiveData.length - 1];

    const metricsEl = document.getElementById('nw-projection-metrics');
    if (metricsEl) {
      metricsEl.innerHTML = `
        <div class="nw-stat-cell">
          <span class="nw-stat-cell-label">Conservative (6% p.a.)</span>
          <span class="nw-stat-cell-value" style="color: var(--text-secondary);">${Formatters.compactCurrency(finalConservative)}</span>
        </div>
        <div class="nw-stat-cell">
          <span class="nw-stat-cell-label">Balanced (10% p.a.)</span>
          <span class="nw-stat-cell-value" style="color: ${primaryColor};">${Formatters.compactCurrency(finalBalanced)}</span>
        </div>
        <div class="nw-stat-cell">
          <span class="nw-stat-cell-label">Accelerated (14% p.a.)</span>
          <span class="nw-stat-cell-value" style="color: var(--success);">${Formatters.compactCurrency(finalAggressive)}</span>
        </div>
      `;
    }

    projectionChartInstance = new Chart(canvas, {
      type: 'line',
      data: {
        labels,
        datasets: [
          {
            label: 'Accelerated (14%)',
            data: aggressiveData,
            borderColor: isLight ? '#16A34A' : '#10B981',
            backgroundColor: isLight ? 'rgba(22, 163, 74, 0.08)' : 'rgba(16, 185, 129, 0.08)',
            borderWidth: 2,
            borderDash: [5, 4],
            pointRadius: 3,
            pointHoverRadius: 6,
            tension: 0.3
          },
          {
            label: 'Balanced (10%)',
            data: balancedData,
            borderColor: primaryColor,
            backgroundColor: hexToRgba(primaryColor, 0.15),
            fill: true,
            borderWidth: 2.5,
            pointRadius: 4,
            pointHoverRadius: 7,
            tension: 0.3
          },
          {
            label: 'Conservative (6%)',
            data: conservativeData,
            borderColor: isLight ? '#64748B' : '#94A3B8',
            borderWidth: 1.8,
            borderDash: [2, 2],
            pointRadius: 3,
            pointHoverRadius: 6,
            tension: 0.3
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 11, weight: '600' } }
          },
          y: {
            grid: { color: gridColor },
            ticks: {
              color: textColor,
              font: { family: 'JetBrains Mono', size: 10 },
              callback: (v) => Formatters.compactCurrency(v)
            }
          }
        },
        plugins: {
          legend: {
            display: true,
            position: 'top',
            align: 'end',
            labels: {
              boxWidth: 10,
              boxHeight: 10,
              usePointStyle: true,
              pointStyle: 'circle',
              color: textColor,
              font: { family: 'Plus Jakarta Sans', size: 10.5 }
            }
          },
          tooltip: {
            backgroundColor: tooltipBg,
            titleColor: tooltipTitle,
            bodyColor: textColor,
            borderColor: tooltipBorder,
            borderWidth: 1,
            padding: 10,
            callbacks: {
              label: (ctx) => `${ctx.dataset.label}: ${Formatters.currency(ctx.parsed.y)}`
            }
          }
        }
      }
    });
  },

  renderCapitalStructureChart(state) {
    const canvas = document.getElementById('networth-structure-canvas');
    if (!canvas) return;

    if (structureChartInstance) {
      structureChartInstance.destroy();
      structureChartInstance = null;
    }

    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = isLightTheme(activeTheme);
    const themeObj = getTheme(activeTheme);
    const primaryColor = themeObj.primary || (isLight ? '#0F172A' : '#FFFFFF');
    const textColor = isLight ? '#475569' : '#94A3B8';
    const gridColor = isLight ? 'rgba(0, 0, 0, 0.05)' : 'rgba(255, 255, 255, 0.05)';
    const tooltipBg = isLight ? '#FFFFFF' : (themeObj.surface || '#11141E');
    const tooltipTitle = isLight ? '#0F172A' : (themeObj.primary || '#FFFFFF');
    const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)';

    const bankAccounts = state.bankAccounts || [];
    const assets = state.assets || [];

    // Liquid reserves: checking, savings, cash
    let liquidReserves = 0;
    let investmentPortfolios = 0;
    let tangibleAssets = 0;
    let shortTermDebt = 0;
    let longTermDebt = 0;

    bankAccounts.forEach(acc => {
      const bal = Number(acc.balance || 0);
      const accType = (acc.account_type || acc.accountType || '').toLowerCase();
      if (accType === 'credit_card') {
        shortTermDebt += Math.abs(bal);
      } else {
        liquidReserves += Math.max(0, bal);
      }
    });

    assets.forEach(a => {
      const val = Math.abs(Number(a.value || 0));
      const isLiab = a.is_liability || a.isLiability;
      const type = (a.type || '').toLowerCase();
      if (isLiab) {
        if (type === 'credit_card') {
          shortTermDebt += val;
        } else {
          longTermDebt += val;
        }
      } else {
        if (['investment', 'crypto'].includes(type)) {
          investmentPortfolios += val;
        } else if (['savings', 'cash', 'checking'].includes(type)) {
          liquidReserves += val;
        } else {
          tangibleAssets += val;
        }
      }
    });

    // Calculate monthly expense run rate from past 3 months
    const now = new Date();
    const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, 1);
    const recentExpenses = (state.transactions || [])
      .filter(t => t.type === 'expense' && new Date(t.timestamp) >= threeMonthsAgo)
      .reduce((sum, t) => sum + Number(t.amount || 0), 0);
    const monthlyBurn = recentExpenses > 0 ? recentExpenses / 3 : (state.userSettings?.monthlyIncome ? state.userSettings.monthlyIncome * 0.7 : 2000);

    const runwayMonths = monthlyBurn > 0 ? (liquidReserves / monthlyBurn).toFixed(1) : '∞';

    const runwayBadge = document.getElementById('nw-runway-badge');
    if (runwayBadge) {
      runwayBadge.innerHTML = `
        <span class="material-icons" style="font-size: 13px; margin-right: 3px;">timer</span>
        <span>${runwayMonths} Mos Liquid Runway</span>
      `;
      runwayBadge.className = `kpi-badge ${Number(runwayMonths) >= 6 ? 'positive' : Number(runwayMonths) >= 3 ? 'neutral' : 'negative'}`;
    }

    const metricsEl = document.getElementById('nw-structure-metrics');
    if (metricsEl) {
      metricsEl.innerHTML = `
        <div class="nw-stat-cell">
          <span class="nw-stat-cell-label">Liquid Buffer</span>
          <span class="nw-stat-cell-value" style="color: var(--success);">${Formatters.currency(liquidReserves)}</span>
        </div>
        <div class="nw-stat-cell">
          <span class="nw-stat-cell-label">Capital Assets</span>
          <span class="nw-stat-cell-value" style="color: ${primaryColor};">${Formatters.currency(investmentPortfolios + tangibleAssets)}</span>
        </div>
        <div class="nw-stat-cell">
          <span class="nw-stat-cell-label">Debt Exposure</span>
          <span class="nw-stat-cell-value" style="color: var(--error);">${Formatters.currency(shortTermDebt + longTermDebt)}</span>
        </div>
      `;
    }

    structureChartInstance = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: ['Liquid Buffer', 'Investments', 'Tangible Fixed', 'Short-Term Debt', 'Long-Term Debt'],
        datasets: [{
          label: 'Capital Volume',
          data: [liquidReserves, investmentPortfolios, tangibleAssets, shortTermDebt, longTermDebt],
          backgroundColor: [
            isLight ? '#16A34A' : '#10B981',
            primaryColor,
            hexToRgba(primaryColor, 0.45),
            isLight ? '#DC2626' : '#F43F5E',
            isLight ? 'rgba(220, 38, 38, 0.5)' : 'rgba(244, 63, 94, 0.5)'
          ],
          borderRadius: 6,
          maxBarThickness: 34
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: tooltipBg,
            titleColor: tooltipTitle,
            bodyColor: textColor,
            borderColor: tooltipBorder,
            borderWidth: 1,
            padding: 10,
            callbacks: {
              label: (ctx) => `Amount: ${Formatters.currency(ctx.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 10.5, weight: '600' } }
          },
          y: {
            grid: { color: gridColor },
            ticks: {
              color: textColor,
              font: { family: 'JetBrains Mono', size: 10 },
              callback: (v) => Formatters.compactCurrency(v)
            }
          }
        }
      }
    });
  },

  showAddAssetModal() {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 500px; padding: 34px 30px;">
        <div class="modal-header" style="margin-bottom: 24px; padding-bottom: 16px;">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary); font-size: 24px;">account_balance</span>
            <span>New Asset / Liability</span>
          </div>
          <button class="modal-close-btn" id="modal-close-asset" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Name / Asset Description</label>
          <input type="text" class="form-control" id="asset-name-field" placeholder="e.g. HDFC Salary Account, Nifty Index Fund, Home Loan" autofocus>
        </div>

        <!-- Classification Toggle (Pill Capsule) -->
        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Classification</label>
          <div class="filter-group" style="width: 100%; display: flex; padding: 4px;">
            <button type="button" class="filter-chip active" id="asset-class-asset-btn" style="flex: 1; text-align: center; padding: 8px 12px; font-size: 13px; font-weight: 600;">
              Asset (Positive Capital)
            </button>
            <button type="button" class="filter-chip" id="asset-class-liability-btn" style="flex: 1; text-align: center; padding: 8px 12px; font-size: 13px; font-weight: 600;">
              Liability / Debt
            </button>
          </div>
        </div>

        <!-- Category Selector (Interactive Pills Grid) -->
        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Category / Instrument</label>
          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px;" id="asset-type-grid">
            ${[
              { id: 'savings', name: 'Cash / Bank', icon: 'account_balance' },
              { id: 'investment', name: 'Investments', icon: 'trending_up' },
              { id: 'real_estate', name: 'Real Estate', icon: 'domain' },
              { id: 'crypto', name: 'Crypto', icon: 'currency_bitcoin' },
              { id: 'vehicle', name: 'Vehicle', icon: 'directions_car' },
              { id: 'loan', name: 'Personal Loan', icon: 'request_quote' },
              { id: 'credit_card', name: 'Credit Card', icon: 'credit_card' },
              { id: 'other', name: 'Other Asset', icon: 'category' }
            ].map(item => `
              <div class="category-select-pill asset-type-pill ${item.id === 'savings' ? 'active' : ''}" 
                   data-type="${item.id}"
                   style="display: flex; align-items: center; gap: 8px; padding: 10px 12px; border-radius: var(--radius-md); background: ${item.id === 'savings' ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)'}; border: 1px solid ${item.id === 'savings' ? 'var(--primary)' : 'var(--glass-border)'}; cursor: pointer; transition: var(--transition-fast);">
                <span class="material-icons" style="font-size: 18px; color: ${item.id === 'savings' ? 'var(--text-primary)' : 'var(--text-muted)'};">${item.icon}</span>
                <span style="font-size: 12px; font-weight: 600; color: ${item.id === 'savings' ? 'var(--text-primary)' : 'var(--text-secondary)'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${item.name}</span>
              </div>
            `).join('')}
          </div>
        </div>

        <div class="form-group" style="margin-bottom: 24px;">
          <label class="form-label" style="margin-bottom: 8px;">Current Valuation / Principal (₹)</label>
          <div style="display: flex; align-items: center; gap: 8px;">
            <button type="button" class="btn-icon" id="asset-val-minus" title="Decrease by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">remove</span>
            </button>
            <div style="position: relative; display: flex; align-items: center; flex: 1;">
              <span style="position: absolute; left: 16px; font-size: 18px; font-weight: 700; color: var(--text-muted);">₹</span>
              <input type="number" step="500" min="0" class="form-control" id="asset-val-field" placeholder="50000" style="padding-left: 36px; font-size: 18px; font-weight: 700; text-align: right;">
            </div>
            <button type="button" class="btn-icon" id="asset-val-plus" title="Increase by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">add</span>
            </button>
          </div>
        </div>

        <!-- Quick Valuation Increment Chips -->
        <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 20px;">
          ${[5000, 10000, 25000, 50000, 100000, 500000].map(val => `
            <button type="button" class="filter-chip asset-val-preset-chip" data-val="${val}" style="padding: 6px 10px; font-size: 11.5px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border);">
              +₹${val.toLocaleString()}
            </button>
          `).join('')}
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="modal-cancel-asset" style="width: auto; padding: 10px 20px;">Cancel</button>
          <button class="btn-primary" id="modal-submit-asset" style="width: auto; padding: 10px 22px;">Save Record</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
    let isLiability = false;
    let selectedType = 'savings';

    const valInput = overlay.querySelector('#asset-val-field');

    overlay.querySelector('#asset-val-minus')?.addEventListener('click', () => {
      const cur = parseFloat(valInput.value) || 0;
      valInput.value = Math.max(0, cur - 500);
    });

    overlay.querySelector('#asset-val-plus')?.addEventListener('click', () => {
      const cur = parseFloat(valInput.value) || 0;
      valInput.value = cur + 500;
    });

    overlay.querySelectorAll('.asset-val-preset-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const delta = parseFloat(chip.getAttribute('data-val')) || 0;
        const cur = parseFloat(valInput.value) || 0;
        valInput.value = cur + delta;
      });
    });

    const assetBtn = document.getElementById('asset-class-asset-btn');
    const liabilityBtn = document.getElementById('asset-class-liability-btn');

    assetBtn?.addEventListener('click', () => {
      isLiability = false;
      assetBtn.classList.add('active');
      liabilityBtn?.classList.remove('active');
    });

    liabilityBtn?.addEventListener('click', () => {
      isLiability = true;
      liabilityBtn.classList.add('active');
      assetBtn?.classList.remove('active');
    });

    // Category Type Pill selection
    const typePills = overlay.querySelectorAll('.asset-type-pill');
    typePills.forEach(pill => {
      pill.addEventListener('click', () => {
        selectedType = pill.getAttribute('data-type');
        typePills.forEach(p => {
          const active = p === pill;
          p.style.background = active ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)';
          p.style.borderColor = active ? 'var(--primary)' : 'var(--glass-border)';
          const icon = p.querySelector('.material-icons');
          if (icon) icon.style.color = active ? 'var(--text-primary)' : 'var(--text-muted)';
          const text = p.querySelector('span:last-child');
          if (text) text.style.color = active ? 'var(--text-primary)' : 'var(--text-secondary)';
        });
      });
    });

    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };

    document.getElementById('modal-close-asset')?.addEventListener('click', closeModal);
    document.getElementById('modal-cancel-asset')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    document.getElementById('modal-submit-asset')?.addEventListener('click', async () => {
      const name = document.getElementById('asset-name-field').value.trim();
      const val = parseFloat(document.getElementById('asset-val-field').value);

      if (!name || isNaN(val) || val <= 0) {
        alert('Please enter a valid asset name and valuation.');
        return;
      }

      await DbService.addAsset({
        name,
        value: val,
        isLiability,
        is_liability: isLiability,
        type: selectedType
      });

      closeModal();
      StateManager.notify();
    });
  },

  showEditAssetModal(asset) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    let isLiability = asset.isLiability !== undefined ? Boolean(asset.isLiability) : Boolean(asset.is_liability);
    let selectedType = asset.type || (isLiability ? 'loan' : 'savings');
    const initialVal = Math.abs(Number(asset.value || 0));

    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 500px; padding: 34px 30px;">
        <div class="modal-header" style="margin-bottom: 24px; padding-bottom: 16px;">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary); font-size: 24px;">edit_note</span>
            <span>Edit Asset / Holding</span>
          </div>
          <button class="modal-close-btn" id="modal-close-edit-asset" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Name / Asset Description</label>
          <input type="text" class="form-control" id="edit-asset-name-field" value="${asset.name || ''}" placeholder="Asset Name" autofocus>
        </div>

        <!-- Classification Toggle -->
        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Classification</label>
          <div class="filter-group" style="width: 100%; display: flex; padding: 4px;">
            <button type="button" class="filter-chip ${!isLiability ? 'active' : ''}" id="edit-asset-class-asset-btn" style="flex: 1; text-align: center; padding: 8px 12px; font-size: 13px; font-weight: 600;">
              Asset (Positive Capital)
            </button>
            <button type="button" class="filter-chip ${isLiability ? 'active' : ''}" id="edit-asset-class-liability-btn" style="flex: 1; text-align: center; padding: 8px 12px; font-size: 13px; font-weight: 600;">
              Liability / Debt
            </button>
          </div>
        </div>

        <!-- Category Selector -->
        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Category / Instrument</label>
          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px;" id="edit-asset-type-grid">
            ${[
              { id: 'savings', name: 'Cash / Bank', icon: 'account_balance' },
              { id: 'investment', name: 'Investments', icon: 'trending_up' },
              { id: 'real_estate', name: 'Real Estate', icon: 'domain' },
              { id: 'crypto', name: 'Crypto', icon: 'currency_bitcoin' },
              { id: 'vehicle', name: 'Vehicle', icon: 'directions_car' },
              { id: 'loan', name: 'Personal Loan', icon: 'request_quote' },
              { id: 'credit_card', name: 'Credit Card', icon: 'credit_card' },
              { id: 'other', name: 'Other Asset', icon: 'category' }
            ].map(item => `
              <div class="category-select-pill edit-asset-type-pill ${item.id === selectedType ? 'active' : ''}" 
                   data-type="${item.id}"
                   style="display: flex; align-items: center; gap: 8px; padding: 10px 12px; border-radius: var(--radius-md); background: ${item.id === selectedType ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)'}; border: 1px solid ${item.id === selectedType ? 'var(--primary)' : 'var(--glass-border)'}; cursor: pointer; transition: var(--transition-fast);">
                <span class="material-icons" style="font-size: 18px; color: ${item.id === selectedType ? 'var(--text-primary)' : 'var(--text-muted)'};">${item.icon}</span>
                <span style="font-size: 12px; font-weight: 600; color: ${item.id === selectedType ? 'var(--text-primary)' : 'var(--text-secondary)'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${item.name}</span>
              </div>
            `).join('')}
          </div>
        </div>

        <div class="form-group" style="margin-bottom: 24px;">
          <label class="form-label" style="margin-bottom: 8px;">Valuation / Principal (₹)</label>
          <div style="display: flex; align-items: center; gap: 8px;">
            <button type="button" class="btn-icon" id="edit-asset-val-minus" title="Decrease by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">remove</span>
            </button>
            <div style="position: relative; display: flex; align-items: center; flex: 1;">
              <span style="position: absolute; left: 16px; font-size: 18px; font-weight: 700; color: var(--text-muted);">₹</span>
              <input type="number" step="500" min="0" class="form-control" id="edit-asset-val-field" value="${initialVal}" placeholder="50000" style="padding-left: 36px; font-size: 18px; font-weight: 700; text-align: right;">
            </div>
            <button type="button" class="btn-icon" id="edit-asset-val-plus" title="Increase by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">add</span>
            </button>
          </div>
        </div>

        <!-- Quick Preset Chips -->
        <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 20px;">
          ${[5000, 10000, 25000, 50000, 100000, 500000].map(val => `
            <button type="button" class="filter-chip edit-asset-val-preset-chip" data-val="${val}" style="padding: 6px 10px; font-size: 11.5px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border);">
              +₹${val.toLocaleString()}
            </button>
          `).join('')}
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--glass-border);">
          <button class="btn-ghost" id="edit-asset-delete-btn" style="color: var(--error); padding: 10px 14px; font-size: 13px;">
            <span class="material-icons" style="font-size: 16px;">delete_outline</span> Delete
          </button>
          <div style="display: flex; gap: 12px;">
            <button class="btn-secondary" id="edit-asset-cancel-btn" style="width: auto; padding: 10px 20px;">Cancel</button>
            <button class="btn-primary" id="edit-asset-save-btn" style="width: auto; padding: 10px 22px;">Save Changes</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const valInput = overlay.querySelector('#edit-asset-val-field');

    overlay.querySelector('#edit-asset-val-minus')?.addEventListener('click', () => {
      const cur = parseFloat(valInput.value) || 0;
      valInput.value = Math.max(0, cur - 500);
    });

    overlay.querySelector('#edit-asset-val-plus')?.addEventListener('click', () => {
      const cur = parseFloat(valInput.value) || 0;
      valInput.value = cur + 500;
    });

    overlay.querySelectorAll('.edit-asset-val-preset-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const delta = parseFloat(chip.getAttribute('data-val')) || 0;
        const cur = parseFloat(valInput.value) || 0;
        valInput.value = cur + delta;
      });
    });

    const assetBtn = overlay.querySelector('#edit-asset-class-asset-btn');
    const liabilityBtn = overlay.querySelector('#edit-asset-class-liability-btn');

    assetBtn?.addEventListener('click', () => {
      isLiability = false;
      assetBtn.classList.add('active');
      liabilityBtn?.classList.remove('active');
    });

    liabilityBtn?.addEventListener('click', () => {
      isLiability = true;
      liabilityBtn.classList.add('active');
      assetBtn?.classList.remove('active');
    });

    const typePills = overlay.querySelectorAll('.edit-asset-type-pill');
    typePills.forEach(pill => {
      pill.addEventListener('click', () => {
        selectedType = pill.getAttribute('data-type');
        typePills.forEach(p => {
          const active = p === pill;
          p.style.background = active ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)';
          p.style.borderColor = active ? 'var(--primary)' : 'var(--glass-border)';
          const icon = p.querySelector('.material-icons');
          if (icon) icon.style.color = active ? 'var(--text-primary)' : 'var(--text-muted)';
          const text = p.querySelector('span:last-child');
          if (text) text.style.color = active ? 'var(--text-primary)' : 'var(--text-secondary)';
        });
      });
    });

    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };

    overlay.querySelector('#modal-close-edit-asset')?.addEventListener('click', closeModal);
    overlay.querySelector('#edit-asset-cancel-btn')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    overlay.querySelector('#edit-asset-delete-btn')?.addEventListener('click', async () => {
      if (confirm('Delete this asset/liability record?')) {
        await DbService.deleteAsset(asset.sync_id, asset.id);
        closeModal();
      }
    });

    overlay.querySelector('#edit-asset-save-btn')?.addEventListener('click', async () => {
      const name = overlay.querySelector('#edit-asset-name-field').value.trim();
      const val = parseFloat(overlay.querySelector('#edit-asset-val-field').value);

      if (!name || isNaN(val) || val < 0) {
        alert('Please enter a valid asset name and valuation.');
        return;
      }

      await DbService.updateAsset(asset.sync_id, {
        name,
        value: val,
        isLiability,
        is_liability: isLiability,
        type: selectedType
      }, asset.id);

      closeModal();
    });
  },

  showEditBankModal(account) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    let selectedType = account.account_type || account.accountType || 'savings';
    const isCreditCard = selectedType === 'credit_card';
    const initialVal = Math.abs(Number(account.balance || 0));

    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 480px; padding: 34px 30px;">
        <div class="modal-header" style="margin-bottom: 24px; padding-bottom: 16px;">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary); font-size: 24px;">${isCreditCard ? 'credit_card' : 'account_balance'}</span>
            <span>Edit Account / Card</span>
          </div>
          <button class="modal-close-btn" id="modal-close-edit-bank" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Account Name / Label</label>
          <input type="text" class="form-control" id="edit-bank-name-field" value="${account.name || ''}" placeholder="e.g. HDFC Salary, ICICI Amazon Card" autofocus>
        </div>

        <!-- Account Type Selector -->
        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Account Category</label>
          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px;" id="edit-bank-type-grid">
            ${[
              { id: 'savings', name: 'Savings Account', icon: 'account_balance' },
              { id: 'checking', name: 'Current / Checking', icon: 'payments' },
              { id: 'credit_card', name: 'Credit Card', icon: 'credit_card' },
              { id: 'cash', name: 'Cash Wallet', icon: 'wallet' }
            ].map(item => `
              <div class="category-select-pill edit-bank-type-pill ${item.id === selectedType ? 'active' : ''}" 
                   data-type="${item.id}"
                   style="display: flex; align-items: center; gap: 8px; padding: 10px 12px; border-radius: var(--radius-md); background: ${item.id === selectedType ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)'}; border: 1px solid ${item.id === selectedType ? 'var(--primary)' : 'var(--glass-border)'}; cursor: pointer; transition: var(--transition-fast);">
                <span class="material-icons" style="font-size: 18px; color: ${item.id === selectedType ? 'var(--text-primary)' : 'var(--text-muted)'};">${item.icon}</span>
                <span style="font-size: 12px; font-weight: 600; color: ${item.id === selectedType ? 'var(--text-primary)' : 'var(--text-secondary)'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${item.name}</span>
              </div>
            `).join('')}
          </div>
        </div>

        <div class="form-group" style="margin-bottom: 24px;">
          <label class="form-label" style="margin-bottom: 8px;">${selectedType === 'credit_card' ? 'Outstanding Balance / Debt (₹)' : 'Current Available Balance (₹)'}</label>
          <div style="display: flex; align-items: center; gap: 8px;">
            <button type="button" class="btn-icon" id="edit-bank-val-minus" title="Decrease by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">remove</span>
            </button>
            <div style="position: relative; display: flex; align-items: center; flex: 1;">
              <span style="position: absolute; left: 16px; font-size: 18px; font-weight: 700; color: var(--text-muted);">₹</span>
              <input type="number" step="500" class="form-control" id="edit-bank-val-field" value="${initialVal}" placeholder="10000" style="padding-left: 36px; font-size: 18px; font-weight: 700; text-align: right;">
            </div>
            <button type="button" class="btn-icon" id="edit-bank-val-plus" title="Increase by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">add</span>
            </button>
          </div>
        </div>

        <!-- Quick Preset Chips -->
        <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 20px;">
          ${[1000, 5000, 10000, 25000, 50000, 100000].map(val => `
            <button type="button" class="filter-chip edit-bank-val-preset-chip" data-val="${val}" style="padding: 6px 10px; font-size: 11.5px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border);">
              +₹${val.toLocaleString()}
            </button>
          `).join('')}
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--glass-border);">
          <button class="btn-ghost" id="edit-bank-delete-btn" style="color: var(--error); padding: 10px 14px; font-size: 13px;">
            <span class="material-icons" style="font-size: 16px;">delete_outline</span> Delete
          </button>
          <div style="display: flex; gap: 12px;">
            <button class="btn-secondary" id="edit-bank-cancel-btn" style="width: auto; padding: 10px 20px;">Cancel</button>
            <button class="btn-primary" id="edit-bank-save-btn" style="width: auto; padding: 10px 22px;">Save Changes</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const valInput = overlay.querySelector('#edit-bank-val-field');

    overlay.querySelector('#edit-bank-val-minus')?.addEventListener('click', () => {
      const cur = parseFloat(valInput.value) || 0;
      valInput.value = Math.max(0, cur - 500);
    });

    overlay.querySelector('#edit-bank-val-plus')?.addEventListener('click', () => {
      const cur = parseFloat(valInput.value) || 0;
      valInput.value = cur + 500;
    });

    overlay.querySelectorAll('.edit-bank-val-preset-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const delta = parseFloat(chip.getAttribute('data-val')) || 0;
        const cur = parseFloat(valInput.value) || 0;
        valInput.value = cur + delta;
      });
    });

    const typePills = overlay.querySelectorAll('.edit-bank-type-pill');
    typePills.forEach(pill => {
      pill.addEventListener('click', () => {
        selectedType = pill.getAttribute('data-type');
        typePills.forEach(p => {
          const active = p === pill;
          p.style.background = active ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)';
          p.style.borderColor = active ? 'var(--primary)' : 'var(--glass-border)';
          const icon = p.querySelector('.material-icons');
          if (icon) icon.style.color = active ? 'var(--text-primary)' : 'var(--text-muted)';
          const text = p.querySelector('span:last-child');
          if (text) text.style.color = active ? 'var(--text-primary)' : 'var(--text-secondary)';
        });
      });
    });

    const closeModal = () => { if (document.body.contains(overlay)) document.body.removeChild(overlay); };

    overlay.querySelector('#modal-close-edit-bank')?.addEventListener('click', closeModal);
    overlay.querySelector('#edit-bank-cancel-btn')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    overlay.querySelector('#edit-bank-delete-btn')?.addEventListener('click', async () => {
      if (confirm('Delete this account/card record?')) {
        await DbService.deleteBankAccount(account.sync_id || account.id);
        closeModal();
      }
    });

    overlay.querySelector('#edit-bank-save-btn')?.addEventListener('click', async () => {
      const name = overlay.querySelector('#edit-bank-name-field').value.trim();
      const rawVal = parseFloat(overlay.querySelector('#edit-bank-val-field').value);

      if (!name || isNaN(rawVal) || rawVal < 0) {
        alert('Please enter a valid account name and balance.');
        return;
      }

      await DbService.updateBankAccount(account.sync_id || account.id, {
        name,
        balance: rawVal,
        account_type: selectedType,
        accountType: selectedType
      });

      closeModal();
    });
  },

  showAllocationDrillDown(item, state) {
    const holdings = item.holdings || [];
    const totalVal = item.value || 0;

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog drilldown-dialog animate-scale-up">
        <div class="modal-header" style="margin-bottom: 18px; padding-bottom: 14px;">
          <div class="modal-title" style="font-size: 18px;">
            <div class="tx-icon-box" style="width: 38px; height: 38px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border); color: ${item.color || 'var(--primary)'};">
              <span class="material-icons" style="font-size: 20px;">${item.icon || 'pie_chart'}</span>
            </div>
            <div>
              <div style="color: var(--text-primary); font-weight: 800;">${item.name} Breakdown</div>
              <div style="font-size: 12px; font-weight: 500; color: var(--text-muted); margin-top: 2px;">
                ${holdings.length} ${holdings.length === 1 ? 'holding' : 'holdings'} • ${item.percent}% of gross assets
              </div>
            </div>
          </div>
          <button class="modal-close-btn" id="drilldown-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 18px;">close</span>
          </button>
        </div>

        <div class="drilldown-summary-grid" style="grid-template-columns: repeat(2, 1fr);">
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Total Asset Value</div>
            <div class="drilldown-stat-value" style="color: var(--text-primary);">${Formatters.currency(totalVal)}</div>
          </div>
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Portfolio Share</div>
            <div class="drilldown-stat-value" style="color: ${item.color || 'var(--text-primary)'};">${item.percent}%</div>
          </div>
        </div>

        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
          <div style="font-size: 13px; font-weight: 700; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
            <span class="material-icons" style="font-size: 16px; color: var(--primary);">account_balance</span>
            <span>Comprising Accounts & Assets</span>
          </div>
          <span style="font-size: 11.5px; color: var(--text-muted);">Click edit to update balance</span>
        </div>

        <div class="drilldown-tx-list">
          ${holdings.length === 0 ? `
            <div style="text-align: center; padding: 40px 16px; color: var(--text-muted); font-size: 13px;">
              No holdings found in this category.
            </div>
          ` : holdings.map((h, i) => `
            <div class="drilldown-tx-row" style="cursor: default;">
              <div style="display: flex; align-items: center; gap: 12px; min-width: 0;">
                <div class="tx-icon-box" style="width: 36px; height: 36px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border); color: ${item.color || 'var(--primary)'};">
                  <span class="material-icons" style="font-size: 18px;">${h.isBank ? 'account_balance' : (item.icon || 'inventory_2')}</span>
                </div>
                <div style="min-width: 0;">
                  <div style="font-size: 13.5px; font-weight: 700; color: var(--text-primary); text-overflow: ellipsis; overflow: hidden; white-space: nowrap;">
                    ${h.name}
                  </div>
                  <div style="font-size: 11.5px; color: var(--text-muted); margin-top: 2px;">
                    ${h.subtitle}
                  </div>
                </div>
              </div>
              <div style="display: flex; align-items: center; gap: 12px; flex-shrink: 0; margin-left: 12px;">
                <div style="font-size: 14.5px; font-weight: 800; color: var(--text-primary);">
                  ${Formatters.currency(h.value)}
                </div>
                <button class="btn-ghost btn-sm drilldown-edit-holding-btn" data-holding-index="${i}" title="Edit holding" style="padding: 4px 8px; font-size: 11.5px;">
                  <span class="material-icons" style="font-size: 14px;">edit</span>
                </button>
              </div>
            </div>
          `).join('')}
        </div>

        <div style="display: flex; justify-content: flex-end; align-items: center; margin-top: 22px; padding-top: 14px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="drilldown-dismiss-btn" style="width: auto; padding: 8px 18px; font-size: 12.5px;">
            Done
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      if (document.body.contains(overlay)) {
        document.body.removeChild(overlay);
      }
    };

    overlay.querySelector('#drilldown-close-btn')?.addEventListener('click', closeModal);
    overlay.querySelector('#drilldown-dismiss-btn')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) closeModal();
    });

    overlay.querySelectorAll('.drilldown-edit-holding-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const hIdx = parseInt(btn.getAttribute('data-holding-index'), 10);
        const h = holdings[hIdx];
        if (h) {
          closeModal();
          if (h.isBank) {
            this.showEditBankModal(h.data);
          } else {
            this.showEditAssetModal(h.data);
          }
        }
      });
    });
  },

  showTrajectoryDrillDown(fullLabel, month, netWorthVal, stat, state) {
    const inflow = stat ? stat.inflow : 0;
    const outflow = stat ? stat.outflow : 0;
    const delta = stat ? stat.net : 0;

    let targetYear = new Date().getFullYear();
    let targetMonth = new Date().getMonth();
    if (month && month.key) {
      const parts = month.key.split('-');
      targetYear = parseInt(parts[0], 10);
      targetMonth = parseInt(parts[1], 10) - 1;
    }

    const monthTx = (state.transactions || [])
      .filter(t => {
        const d = new Date(t.timestamp);
        return d.getFullYear() === targetYear && d.getMonth() === targetMonth;
      })
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog drilldown-dialog animate-scale-up">
        <div class="modal-header" style="margin-bottom: 18px; padding-bottom: 14px;">
          <div class="modal-title" style="font-size: 18px;">
            <div class="tx-icon-box" style="width: 38px; height: 38px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border); color: var(--primary);">
              <span class="material-icons" style="font-size: 20px;">insights</span>
            </div>
            <div>
              <div style="color: var(--text-primary); font-weight: 800;">${fullLabel} Snapshot</div>
              <div style="font-size: 12px; font-weight: 500; color: var(--text-muted); margin-top: 2px;">
                Net Worth: ${Formatters.currency(netWorthVal)} • ${monthTx.length} transactions
              </div>
            </div>
          </div>
          <button class="modal-close-btn" id="drilldown-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 18px;">close</span>
          </button>
        </div>

        <div class="drilldown-summary-grid">
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Inflows</div>
            <div class="drilldown-stat-value" style="color: var(--primary);">+${Formatters.currency(inflow)}</div>
          </div>
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Outflows</div>
            <div class="drilldown-stat-value" style="color: var(--error);">-${Formatters.currency(outflow)}</div>
          </div>
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Monthly Delta</div>
            <div class="drilldown-stat-value" style="color: ${delta >= 0 ? 'var(--primary)' : 'var(--error)'};">
              ${delta >= 0 ? '+' : ''}${Formatters.currency(delta)}
            </div>
          </div>
        </div>

        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
          <div style="font-size: 13px; font-weight: 700; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
            <span class="material-icons" style="font-size: 16px; color: var(--primary);">calendar_month</span>
            <span>Recorded Activity in ${month?.label || fullLabel}</span>
          </div>
          <span style="font-size: 11.5px; color: var(--text-muted);">Sorted by date</span>
        </div>

        <div class="drilldown-tx-list">
          ${monthTx.length === 0 ? `
            <div style="text-align: center; padding: 40px 16px; color: var(--text-muted); font-size: 13px;">
              No cash flow transactions recorded in this month.
            </div>
          ` : monthTx.map(tx => {
            const isIncome = tx.type === 'income';
            const cat = findCategory(state.categories, tx.categoryId || tx.category_id);
            const iconName = cat ? cat.icon : 'category';
            const catName = cat ? cat.name : 'General';
            const d = new Date(tx.timestamp);
            const dateStr = d.toLocaleDateString('en-US', { day: '2-digit', month: 'short' });
            const timeStr = d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });

            return `
              <div class="drilldown-tx-row" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}">
                <div style="display: flex; align-items: center; gap: 12px; min-width: 0;">
                  <div class="tx-icon-box" style="width: 36px; height: 36px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border); color: ${isIncome ? 'var(--primary)' : 'var(--text-secondary)'};">
                    <span class="material-icons" style="font-size: 18px;">${IconHelper.getMaterialIcon(iconName)}</span>
                  </div>
                  <div style="min-width: 0;">
                    <div style="font-size: 13.5px; font-weight: 700; color: var(--text-primary); text-overflow: ellipsis; overflow: hidden; white-space: nowrap;">
                      ${tx.note || catName}
                    </div>
                    <div style="font-size: 11.5px; color: var(--text-muted); display: flex; align-items: center; gap: 8px; margin-top: 2px;">
                      <span>${dateStr} • ${timeStr}</span>
                      ${tx.paymentMode ? `<span class="tx-tag" style="font-size: 10px; padding: 1px 6px;">${tx.paymentMode}</span>` : ''}
                    </div>
                  </div>
                </div>
                <div style="text-align: right; flex-shrink: 0; margin-left: 12px;">
                  <div style="font-size: 14.5px; font-weight: 800; color: ${isIncome ? 'var(--primary)' : 'var(--error)'};">
                    ${isIncome ? '+' : '-'}${Formatters.currency(tx.amount)}
                  </div>
                </div>
              </div>
            `;
          }).join('')}
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 22px; padding-top: 14px; border-top: 1px solid var(--glass-border);">
          <button class="btn-ghost" id="drilldown-ledger-btn" style="font-size: 12.5px;">
            <span class="material-icons" style="font-size: 16px;">format_list_bulleted</span> View Ledger
          </button>
          <button class="btn-secondary" id="drilldown-dismiss-btn" style="width: auto; padding: 8px 18px; font-size: 12.5px;">
            Done
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      if (document.body.contains(overlay)) {
        document.body.removeChild(overlay);
      }
    };

    overlay.querySelector('#drilldown-close-btn')?.addEventListener('click', closeModal);
    overlay.querySelector('#drilldown-dismiss-btn')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) closeModal();
    });

    overlay.querySelector('#drilldown-ledger-btn')?.addEventListener('click', () => {
      closeModal();
      StateManager.setState({ navIndex: 1 });
    });

    overlay.querySelectorAll('.drilldown-tx-row').forEach(row => {
      row.addEventListener('click', () => {
        const syncId = row.getAttribute('data-sync-id');
        const localId = row.getAttribute('data-id');
        const tx = state.transactions.find(t => (syncId && t.sync_id === syncId) || (localId && String(t.id) === String(localId)));
        if (tx) {
          closeModal();
          import('./add-transaction.js').then(({ AddTransactionModal }) => {
            AddTransactionModal.show(tx);
          });
        }
      });
    });
  }
};
