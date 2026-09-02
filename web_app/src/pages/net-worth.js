/* Modern Net Worth & Asset Intelligence Module */
import { Chart, registerables } from 'chart.js';
import { StateManager } from '../state.js';
import { DbService, reconcileInvestmentAssets } from '../db.js';
import { Formatters } from '../utils/formatters.js';

Chart.register(...registerables);

let trajectoryChartInstance = null;
let allocationChartInstance = null;

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
    const isLight = activeTheme === 'light';

    const colorsDark = ['#FFFFFF', '#E2E8F0', '#CBD5E1', '#94A3B8', '#64748B', '#475569', '#334155'];
    const colorsLight = ['#0F172A', '#334155', '#475569', '#64748B', '#94A3B8', '#CBD5E1', '#E2E8F0'];
    const palette = isLight ? colorsLight : colorsDark;

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

    (state.bankAccounts || []).forEach(acc => {
      const isCredit = acc.account_type === 'credit_card' || acc.accountType === 'credit_card';
      if (!isCredit) {
        categoryTotals.savings += Number(acc.balance || 0);
      }
    });

    (state.assets || []).forEach(a => {
      const isLiab = a.is_liability || a.isLiability;
      if (!isLiab) {
        const val = Number(a.value || 0);
        const type = a.type || 'other';
        if (categoryTotals[type] !== undefined) {
          categoryTotals[type] += val;
        } else {
          categoryTotals.other += val;
        }
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
        color: palette[idx % palette.length]
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

    const assetItems = [
      ...bankAccounts
        .filter(acc => acc.account_type !== 'credit_card' && acc.accountType !== 'credit_card')
        .map(acc => ({
          name: acc.name || 'Bank Account',
          type: 'Cash / Bank',
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
          icon: categoryIcons[a.type] || 'account_balance_wallet',
          isBank: false
        }))
    ];

    const liabilityItems = [
      ...bankAccounts
        .filter(acc => acc.account_type === 'credit_card' || acc.accountType === 'credit_card')
        .map(acc => ({
          name: acc.name || 'Credit Card',
          type: 'Credit Card',
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
              <div class="filter-group" style="padding: 2px;">
                <button class="filter-chip ${this.selectedTimeframe === '6M' ? 'active' : ''}" data-nw-timeframe="6M">6M</button>
                <button class="filter-chip ${this.selectedTimeframe === '1Y' ? 'active' : ''}" data-nw-timeframe="1Y">1Y</button>
                <button class="filter-chip ${this.selectedTimeframe === 'ALL' ? 'active' : ''}" data-nw-timeframe="ALL">ALL</button>
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
              <div class="filter-group" style="padding: 2px;">
                <button class="filter-chip ${this.selectedAllocationView === 'class' ? 'active' : ''}" data-nw-alloc-view="class">Asset Mix</button>
                <button class="filter-chip ${this.selectedAllocationView === 'solvency' ? 'active' : ''}" data-nw-alloc-view="solvency">Solvency</button>
              </div>
            </div>

            <!-- Dynamic Donut Chart & Legend -->
            <div id="nw-allocation-content" style="display: flex; flex-direction: column; flex: 1; justify-content: center;"></div>
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
                <div class="asset-card">
                  <div style="display: flex; align-items: center; gap: 12px; min-width: 0;">
                    <div class="asset-card-icon-box">
                      <span class="material-icons" style="font-size: 18px; color: var(--text-primary);">${a.icon}</span>
                    </div>
                    <div style="min-width: 0;">
                      <div style="font-weight: 700; font-size: 14px; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${a.name}</div>
                      <div style="font-size: 11px; text-transform: uppercase; color: var(--text-muted); margin-top: 2px;">${a.type || 'Savings'}</div>
                    </div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 10px; flex-shrink: 0;">
                    <div style="font-weight: 700; font-size: 14.5px; color: var(--text-primary);">${Formatters.currency(a.value)}</div>
                    ${a.isBank ? `
                      <span style="font-size: 10px; text-transform: uppercase; color: var(--text-muted); background: var(--bg-surface-elevated); padding: 3px 6px; border-radius: var(--radius-xs); border: 1px solid var(--glass-border);">Account</span>
                    ` : `
                      <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Delete asset">
                        <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                      </button>
                    `}
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
                <div class="asset-card">
                  <div style="display: flex; align-items: center; gap: 12px; min-width: 0;">
                    <div class="asset-card-icon-box">
                      <span class="material-icons" style="font-size: 18px; color: var(--text-secondary);">${a.icon}</span>
                    </div>
                    <div style="min-width: 0;">
                      <div style="font-weight: 700; font-size: 14px; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${a.name}</div>
                      <div style="font-size: 11px; text-transform: uppercase; color: var(--text-muted); margin-top: 2px;">${a.type || 'Debt'}</div>
                    </div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 10px; flex-shrink: 0;">
                    <div style="font-weight: 700; font-size: 14.5px; color: var(--text-secondary);">${Formatters.currency(a.value)}</div>
                    ${a.isBank ? `
                      <span style="font-size: 10px; text-transform: uppercase; color: var(--text-muted); background: var(--bg-surface-elevated); padding: 3px 6px; border-radius: var(--radius-xs); border: 1px solid var(--glass-border);">Card</span>
                    ` : `
                      <button class="btn-icon btn-icon-sm delete-asset-btn" data-sync-id="${a.sync_id || ''}" data-id="${a.id || ''}" title="Delete liability">
                        <span class="material-icons" style="font-size: 16px;">delete_outline</span>
                      </button>
                    `}
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

    this.renderCharts(state);
  },

  renderCharts(state) {
    this.renderTrajectoryChart(state);
    this.renderAllocationChart(state);
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
    const isLight = activeTheme === 'light';
    const textColor = isLight ? '#475569' : '#94A3B8';
    const gridColor = isLight ? 'rgba(0, 0, 0, 0.05)' : 'rgba(255, 255, 255, 0.05)';
    const tooltipBg = isLight ? '#FFFFFF' : '#11141E';
    const tooltipTitle = isLight ? '#0F172A' : '#FFFFFF';
    const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)';
    const lineColor = isLight ? '#0F172A' : '#FFFFFF';

    const ctx = canvas.getContext('2d');
    const gradient = ctx.createLinearGradient(0, 0, 0, 240);
    gradient.addColorStop(0, isLight ? 'rgba(15, 23, 42, 0.12)' : 'rgba(255, 255, 255, 0.15)');
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
    const isLight = activeTheme === 'light';
    const textColor = isLight ? '#475569' : '#94A3B8';
    const tooltipBg = isLight ? '#FFFFFF' : '#11141E';
    const tooltipTitle = isLight ? '#0F172A' : '#FFFFFF';
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
  }
};
