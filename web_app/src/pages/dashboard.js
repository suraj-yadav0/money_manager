/* Modern Financial Overview & Command Center Module */
import { Chart, registerables } from 'chart.js';
import { StateManager } from '../state.js';
import { DateRangeHelper } from '../utils/date-range.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory, isInvestmentCategory } from '../utils/icons.js';
import { Router } from '../router.js';
import { reconcileGoalSavedAmounts, reconcileInvestmentAssets } from '../db.js';

// Register Chart.js
Chart.register(...registerables);

let cashFlowChartInstance = null;
let categoryChartInstance = null;

export const DashboardPage = {
  cashFlowViewMode: 'trajectory', // 'trajectory', 'net', 'daily'

  render(state) {
    reconcileGoalSavedAmounts(state);
    reconcileInvestmentAssets(state);
    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = activeTheme === 'light';
    const stats = this.calculateStats(state);
    const recentTx = this.getRecentTransactions(state);
    const topCategories = this.getTopCategories(state, stats.totalExpenses, isLight);
    const activeGoals = state.goals.filter(g => g.is_active !== false && !g.is_completed).slice(0, 2);

    return `
      <div class="animate-fade-in">
        <!-- Hero Header -->
        <section class="hero-section">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Financial Overview</h1>
              <p class="hero-subtitle">Unified capital tracking, automated cash flow forecasting & real-time analytics.</p>
            </div>

            <!-- Date Filter Pills -->
            <div class="filter-group">
              ${this.renderFilterChip('thisWeek', '7 Days', state.dateFilter)}
              ${this.renderFilterChip('thisMonth', 'This Month', state.dateFilter)}
              ${this.renderFilterChip('lastMonth', 'Last Month', state.dateFilter)}
              ${this.renderFilterChip('thisYear', 'This Year', state.dateFilter)}
              ${this.renderFilterChip('allTime', 'All Time', state.dateFilter)}
            </div>
          </div>

          <!-- 4 KPI Stat Cards -->
          <div class="kpi-grid">
            <!-- 1. Net Cash / Balance -->
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Net Balance</span>
                <div class="kpi-icon-box">
                  <span class="material-icons" style="font-size: 20px;">account_balance_wallet</span>
                </div>
              </div>
              <div class="kpi-value">
                ${Formatters.currency(stats.balance)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge positive">
                  <span class="material-icons" style="font-size: 14px;">trending_up</span>
                  ${stats.savingsRate}% saved
                </span>
                <span>In selected period</span>
              </div>
            </div>

            <!-- 2. Monthly Income -->
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Inflow</span>
                <div class="kpi-icon-box">
                  <span class="material-icons" style="font-size: 20px;">arrow_downward</span>
                </div>
              </div>
              <div class="kpi-value">
                ${Formatters.currency(stats.totalIncome)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge neutral">
                  Baseline: ${Formatters.currency(state.userSettings?.monthlyIncome || 0)}
                </span>
              </div>
            </div>

            <!-- 3. Total Outflow -->
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Outflow</span>
                <div class="kpi-icon-box">
                  <span class="material-icons" style="font-size: 20px;">arrow_upward</span>
                </div>
              </div>
              <div class="kpi-value">
                ${Formatters.currency(stats.totalExpenses)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge neutral">
                  Burn: ${Formatters.currency(stats.dailyBurnRate)}/day
                </span>
              </div>
            </div>

            <!-- 4. Month-End Forecast -->
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Month-End Projection</span>
                <div class="kpi-icon-box">
                  <span class="material-icons" style="font-size: 20px;">auto_graph</span>
                </div>
              </div>
              <div class="kpi-value">
                ${Formatters.currency(stats.projectedBalance)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge neutral">
                  ${stats.forecastStatus === 'safe' ? 'Healthy Trajectory' : stats.forecastStatus === 'caution' ? 'Moderate Margin' : 'Deficit Risk'}
                </span>
              </div>
            </div>
          </div>
        </section>

        <!-- Main Content Split Section -->
        <div class="dashboard-split-grid">
          
          <!-- Left Column (Cash Flow Chart & Recent Transactions) -->
          <div style="display: flex; flex-direction: column; gap: 24px;">
            
            <!-- Cash Flow Chart Card -->
            <div class="fintech-card">
              <div class="card-header" style="flex-wrap: wrap; gap: 10px;">
                <div class="card-title">
                  <span class="material-icons">query_stats</span>
                  <span>Cash Flow Analysis</span>
                </div>
                <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                  <!-- View Mode Switcher -->
                  <div class="filter-group" style="margin: 0;" id="dashboard-cf-mode-group">
                    <button class="filter-chip ${this.cashFlowViewMode === 'trajectory' ? 'active' : ''}" data-cf-mode="trajectory" style="padding: 3px 10px; font-size: 11.5px;">Trajectory</button>
                    <button class="filter-chip ${this.cashFlowViewMode === 'net' ? 'active' : ''}" data-cf-mode="net" style="padding: 3px 10px; font-size: 11.5px;">Net Spread</button>
                    <button class="filter-chip ${this.cashFlowViewMode === 'daily' ? 'active' : ''}" data-cf-mode="daily" style="padding: 3px 10px; font-size: 11.5px;">Daily Bars</button>
                  </div>
                  <span class="kpi-badge neutral" style="font-size: 11px; font-weight: 600;">
                    <span class="material-icons" style="font-size: 12px; margin-right: 2px;">touch_app</span>Click to drill down
                  </span>
                </div>
              </div>

              <!-- Dynamic Mini Summary Row -->
              <div class="cf-mini-summary" id="cf-mini-summary"></div>

              <div style="position: relative; height: 260px; width: 100%; max-width: 100%; min-width: 0; overflow: hidden;">
                <canvas id="cashflow-chart-canvas"></canvas>
              </div>
            </div>

            <!-- Recent Activity Feed -->
            <div class="fintech-card">
              <div class="card-header">
                <div class="card-title">
                  <span class="material-icons">receipt_long</span>
                  <span>Recent Activity</span>
                </div>
                <button class="btn-ghost" id="view-all-tx-btn">
                  View Full Ledger <span class="material-icons" style="font-size: 16px;">arrow_forward</span>
                </button>
              </div>

              ${recentTx.length === 0 ? `
                <div style="text-align: center; padding: 48px 20px; color: var(--text-muted);">
                  <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                    <span class="material-icons" style="font-size: 28px; opacity: 0.5;">receipt</span>
                  </div>
                  <div style="font-size: 15px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px;">No transactions recorded yet</div>
                  <div style="font-size: 13px; margin-bottom: 20px;">Add your first transaction or sync with your cloud account.</div>
                  <button class="btn-primary" id="empty-add-tx-btn" style="width: auto;">
                    <span class="material-icons" style="font-size: 16px;">add</span> Add Transaction
                  </button>
                </div>
              ` : `
                <div class="tx-list">
                  ${recentTx.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
                </div>
              `}
            </div>
          </div>

          <!-- Right Column (Category Breakdown, Goals & Intelligence) -->
          <div style="display: flex; flex-direction: column; gap: 24px;">
            
            <!-- Category Spending Donut & Top List -->
            <div class="fintech-card">
              <div class="card-header">
                <div class="card-title">
                  <span class="material-icons">donut_large</span>
                  <span>Spending by Category</span>
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                  <span class="kpi-badge neutral" style="font-size: 11px; font-weight: 600;">
                    ${topCategories.length} Categories
                  </span>
                  <span class="kpi-badge neutral" style="font-size: 11px; font-weight: 600;">
                    <span class="material-icons" style="font-size: 12px; margin-right: 2px;">touch_app</span>Click to drill down
                  </span>
                </div>
              </div>

              ${stats.totalExpenses > 0 ? `
                <div style="position: relative; height: 210px; width: 100%; max-width: 100%; min-width: 0; display: flex; align-items: center; justify-content: center; margin-bottom: 16px;">
                  <canvas id="category-donut-canvas"></canvas>
                  <div class="nw-donut-center" style="max-width: 150px;">
                    <div class="nw-donut-center-label" id="dashboard-cat-donut-label" style="max-width: 145px; font-size: 9.5px; letter-spacing: 0.3px;">Total Spend</div>
                    <div class="nw-donut-center-val" id="dashboard-cat-donut-val" style="font-size: 17px;">${Formatters.compactCurrency(stats.totalExpenses)}</div>
                  </div>
                </div>
                <div style="display: flex; flex-direction: column; gap: 6px;" id="dashboard-category-list">
                  ${topCategories.map((cat, idx) => `
                    <div class="category-breakdown-row" data-cat-name="${cat.name}" data-cat-idx="${idx}" title="Click to view all ${cat.name} expenses">
                      <div style="display: flex; justify-content: space-between; font-size: 13px; font-weight: 600; margin-bottom: 6px;">
                        <span style="display: flex; align-items: center; gap: 8px; color: var(--text-primary); min-width: 0;">
                          <span class="nw-color-dot" style="background: ${cat.color}; flex-shrink: 0;"></span>
                          <span class="material-icons" style="font-size: 15px; opacity: 0.8; flex-shrink: 0;">${IconHelper.getMaterialIcon(cat.icon)}</span>
                          <span style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${cat.name}</span>
                        </span>
                        <span style="color: var(--text-primary); display: flex; align-items: center; gap: 6px; flex-shrink: 0; margin-left: 8px;">
                          <span>${Formatters.currency(cat.amount)}</span>
                          <span style="font-size: 11px; color: var(--text-muted); font-weight: 500;">(${cat.percent}%)</span>
                          <span class="material-icons" style="font-size: 14px; color: var(--text-muted);">chevron_right</span>
                        </span>
                      </div>
                      <div class="progress-track" style="margin: 0; height: 5px;">
                        <div class="progress-bar-fill" style="width: ${cat.percent}%; background: ${cat.color};"></div>
                      </div>
                    </div>
                  `).join('')}
                </div>
              ` : `
                <div style="text-align: center; padding: 36px 0; color: var(--text-muted); font-size: 13px;">
                  No expense records in this period.
                </div>
              `}
            </div>

            <!-- Active Savings Goals Quick Preview -->
            <div class="fintech-card">
              <div class="card-header">
                <div class="card-title">
                  <span class="material-icons">savings</span>
                  <span>Savings Goals</span>
                </div>
                <button class="btn-ghost" id="view-all-goals-btn">
                  Manage <span class="material-icons" style="font-size: 16px;">arrow_forward</span>
                </button>
              </div>

              ${activeGoals.length === 0 ? `
                <div style="text-align: center; padding: 24px 0; color: var(--text-muted); font-size: 13px;">
                  No active savings goals. Create one to track your milestones!
                </div>
              ` : `
                <div style="display: flex; flex-direction: column; gap: 14px;">
                  ${activeGoals.map(goal => {
                    const pct = Math.min(100, Math.round(((goal.savedAmount || goal.saved_amount || 0) / (goal.targetAmount || goal.target_amount || 1)) * 100));
                    return `
                      <div style="background: rgba(255,255,255,0.03); border: 1px solid var(--glass-border); padding: 14px; border-radius: var(--radius-md);">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                          <span style="font-weight: 700; font-size: 14px; color: var(--text-primary);">${goal.name}</span>
                          <span style="font-size: 12px; font-weight: 700; color: var(--primary);">${pct}%</span>
                        </div>
                        <div class="progress-track" style="margin: 6px 0 8px;">
                          <div class="progress-bar-fill safe" style="width: ${pct}%;"></div>
                        </div>
                        <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--text-muted);">
                          <span>${Formatters.currency(goal.savedAmount || goal.saved_amount || 0)} saved</span>
                          <span>Target: ${Formatters.currency(goal.targetAmount || goal.target_amount || 0)}</span>
                        </div>
                      </div>
                    `;
                  }).join('')}
                </div>
              `}
            </div>

            <!-- Financial Intelligence Advice Card -->
            <div class="fintech-card">
              <div style="display: flex; gap: 14px; align-items: flex-start;">
                <div class="tx-icon-box" style="width: 36px; height: 36px; border-radius: 8px; background: rgba(0, 229, 153, 0.12); color: var(--success);">
                  <span class="material-icons" style="font-size: 18px;">trending_up</span>
                </div>
                <div>
                  <div style="font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 3px;">Smart Wealth Intelligence</div>
                  <div style="font-size: 13px; color: var(--text-secondary); line-height: 1.5;">
                    ${(() => {
                      const totalInvested = (state.transactions || [])
                        .filter(t => t.type === 'expense' && isInvestmentCategory(state.categories, t.categoryId || t.category_id))
                        .reduce((sum, t) => sum + Number(t.amount || 0), 0);
                      if (totalInvested > 0) {
                        return `🚀 <b>Wealth Compounding:</b> You channeled ${Formatters.currency(totalInvested)} into investments. This directly expands your Net Worth and compounds future wealth!`;
                      } else if (stats.savingsRate >= 20) {
                        return `Excellent savings discipline! You are currently retaining ${stats.savingsRate}% of your capital this period.`;
                      } else {
                        return `Your daily consumption burn rate is ${Formatters.currency(Math.round(stats.dailyBurnRate))}/day. Setting category budget limits will help retain more capital for investments.`;
                      }
                    })()}
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    `;
  },

  renderFilterChip(key, label, activeKey) {
    const isActive = key === activeKey;
    return `
      <button class="filter-chip ${isActive ? 'active' : ''}" data-filter="${key}">
        ${label}
      </button>
    `;
  },

  renderTransactionRow(tx, categories) {
    const cat = findCategory(categories, tx.categoryId || tx.category_id);
    const icon = IconHelper.getMaterialIcon(cat ? cat.icon : 'category');
    const isIncome = tx.type === 'income';
    const formattedAmount = (isIncome ? '+' : '-') + Formatters.currency(tx.amount);

    return `
      <div class="tx-row" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}">
        <div class="tx-left">
          <div class="tx-icon-box">
            <span class="material-icons">${icon}</span>
          </div>
          <div class="tx-info">
            <div class="tx-title">${tx.note || (cat ? cat.name : 'Transaction')}</div>
            <div class="tx-meta">
              <span class="tx-tag">${cat ? cat.name : 'Other'}</span>
              <span>•</span>
              <span>${tx.paymentMode || tx.payment_mode || 'Cash'}</span>
            </div>
          </div>
        </div>
        <div class="tx-right">
          <div>
            <div class="tx-amount ${isIncome ? 'income' : 'expense'}">${formattedAmount}</div>
            <div class="tx-date">${Formatters.relativeDate(tx.timestamp)}</div>
          </div>
          <span class="material-icons" style="color: var(--text-muted); font-size: 18px;">chevron_right</span>
        </div>
      </div>
    `;
  },

  getRecentTransactions(state) {
    return [...state.transactions]
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
      .slice(0, 6);
  },

  getTopCategories(state, totalExpenses, isLight = false) {
    if (!totalExpenses || totalExpenses <= 0) return [];

    const categoryMap = {};
    const range = DateRangeHelper.getDateRange(state.dateFilter);
    const txList = state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return t.type === 'expense' && ts >= range.start && ts <= range.end;
    });

    for (const tx of txList) {
      const cat = findCategory(state.categories, tx.categoryId || tx.category_id);
      const name = cat ? cat.name : 'Other';
      const icon = cat ? cat.icon : 'category';
      if (!categoryMap[name]) {
        categoryMap[name] = { name, icon, amount: 0, count: 0 };
      }
      categoryMap[name].amount += Number(tx.amount || 0);
      categoryMap[name].count += 1;
    }

    const colorsDark = ['#FFFFFF', '#E2E8F0', '#CBD5E1', '#94A3B8', '#64748B', '#475569', '#334155'];
    const colorsLight = ['#0F172A', '#334155', '#475569', '#64748B', '#94A3B8', '#CBD5E1', '#E2E8F0'];
    const palette = isLight ? colorsLight : colorsDark;

    const sorted = Object.values(categoryMap).sort((a, b) => b.amount - a.amount);
    
    let displayList = [];
    if (sorted.length > 5) {
      const top4 = sorted.slice(0, 4);
      const remainder = sorted.slice(4);
      const remainderAmount = remainder.reduce((sum, c) => sum + c.amount, 0);
      const remainderCount = remainder.reduce((sum, c) => sum + c.count, 0);
      displayList = [
        ...top4,
        {
          name: `Other (${remainder.length} categories)`,
          icon: 'more_horiz',
          amount: remainderAmount,
          count: remainderCount
        }
      ];
    } else {
      displayList = sorted;
    }

    return displayList.map((c, idx) => ({
      ...c,
      color: palette[idx % palette.length],
      percent: totalExpenses > 0 ? Math.round((c.amount / totalExpenses) * 100) : 0
    }));
  },

  calculateStats(state) {
    const range = DateRangeHelper.getDateRange(state.dateFilter);
    const txList = state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return ts >= range.start && ts <= range.end;
    });

    let totalIncome = 0;
    let totalExpenses = 0;

    for (const tx of txList) {
      if (tx.type === 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
      }
    }

    const balance = totalIncome - totalExpenses;
    const savingsRate = totalIncome > 0 ? Math.max(0, Math.round(((totalIncome - totalExpenses) / totalIncome) * 100)) : 0;

    let dailyBurnRate = 0;
    let projectedBalance = balance;
    let forecastStatus = 'safe';
    let burnRateStatus = 'positive';

    if (state.dateFilter === 'thisMonth') {
      const daysElapsed = Math.max(1, Formatters.daysElapsedInMonth());
      const daysRemaining = Formatters.daysRemainingInMonth();
      dailyBurnRate = totalExpenses / daysElapsed;
      projectedBalance = balance - (dailyBurnRate * daysRemaining);
      
      const monthlyIncome = state.userSettings?.monthlyIncome || state.userSettings?.monthly_income || 0;

      if (projectedBalance > monthlyIncome * 0.2) {
        forecastStatus = 'safe';
      } else if (projectedBalance > 0) {
        forecastStatus = 'caution';
      } else {
        forecastStatus = 'deficit';
      }

      if (dailyBurnRate > (monthlyIncome / 30)) {
        burnRateStatus = 'negative';
      }
    }

    return {
      totalIncome,
      totalExpenses,
      balance,
      savingsRate,
      dailyBurnRate,
      projectedBalance,
      forecastStatus,
      burnRateStatus
    };
  },

  bindEvents(state) {
    // Filter chip clicks
    const chips = document.querySelectorAll('.filter-chip[data-filter]');
    chips.forEach(chip => {
      chip.addEventListener('click', () => {
        const filter = chip.getAttribute('data-filter');
        StateManager.setState({ dateFilter: filter });
      });
    });

    // View All Transactions CTA
    document.getElementById('view-all-tx-btn')?.addEventListener('click', () => {
      StateManager.setState({ navIndex: 1 });
    });

    // View All Goals CTA
    document.getElementById('view-all-goals-btn')?.addEventListener('click', () => {
      StateManager.setState({ navIndex: 3 });
    });

    // Empty state Add Tx CTA
    document.getElementById('empty-add-tx-btn')?.addEventListener('click', () => {
      import('./add-transaction.js').then(({ AddTransactionModal }) => {
        AddTransactionModal.show(null);
      });
    });

    // Transaction row click to edit
    const rows = document.querySelectorAll('.tx-row');
    rows.forEach(row => {
      row.addEventListener('click', () => {
        const syncId = row.getAttribute('data-sync-id');
        const localId = row.getAttribute('data-id');
        const tx = state.transactions.find(t => (syncId && t.sync_id === syncId) || (localId && String(t.id) === String(localId)));
        if (tx) {
          import('./add-transaction.js').then(({ AddTransactionModal }) => {
            AddTransactionModal.show(tx);
          });
        }
      });
    });

    // Cash flow view mode switch buttons
    document.querySelectorAll('#dashboard-cf-mode-group [data-cf-mode]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const mode = btn.getAttribute('data-cf-mode');
        if (this.cashFlowViewMode !== mode) {
          this.cashFlowViewMode = mode;
          document.querySelectorAll('#dashboard-cf-mode-group [data-cf-mode]').forEach(b => {
            b.classList.toggle('active', b.getAttribute('data-cf-mode') === mode);
          });
          this.renderCashFlowChart(state);
        }
      });
    });

    // Category breakdown row hover sync & drill down
    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = activeTheme === 'light';
    const stats = this.calculateStats(state);
    const topCats = this.getTopCategories(state, stats.totalExpenses, isLight);

    const catRows = document.querySelectorAll('#dashboard-category-list .category-breakdown-row');
    catRows.forEach(row => {
      const idx = Number(row.getAttribute('data-cat-idx'));
      const cat = topCats[idx];

      row.addEventListener('mouseenter', () => {
        if (cat) {
          const donutLabel = document.getElementById('dashboard-cat-donut-label');
          const donutVal = document.getElementById('dashboard-cat-donut-val');
          if (donutLabel) donutLabel.textContent = `${cat.name} (${cat.percent}%)`;
          if (donutVal) donutVal.textContent = Formatters.currency(cat.amount);
          if (categoryChartInstance) {
            categoryChartInstance.setActiveElements([{ datasetIndex: 0, index: idx }]);
            categoryChartInstance.update();
          }
        }
      });

      row.addEventListener('mouseleave', () => {
        const donutLabel = document.getElementById('dashboard-cat-donut-label');
        const donutVal = document.getElementById('dashboard-cat-donut-val');
        if (donutLabel) donutLabel.textContent = 'Total Spend';
        if (donutVal) donutVal.textContent = Formatters.compactCurrency(stats.totalExpenses);
        if (categoryChartInstance) {
          categoryChartInstance.setActiveElements([]);
          categoryChartInstance.update();
        }
      });

      row.addEventListener('click', () => {
        if (cat) {
          this.showCategoryDrillDown(cat, state);
        }
      });
    });

    // Initialize Charts after DOM render
    this.renderCharts(state);
  },

  renderCharts(state) {
    this.renderCashFlowChart(state);
    this.renderCategoryChart(state);
  },

  renderCashFlowChart(state) {
    const cashFlowCtx = document.getElementById('cashflow-chart-canvas');
    if (!cashFlowCtx) return;

    if (cashFlowChartInstance) {
      cashFlowChartInstance.destroy();
      cashFlowChartInstance = null;
    }

    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = activeTheme === 'light';
    const textColor = isLight ? '#475569' : '#94A3B8';
    const gridColor = isLight ? 'rgba(0, 0, 0, 0.05)' : 'rgba(255, 255, 255, 0.05)';
    const tooltipBg = isLight ? '#FFFFFF' : '#11141E';
    const tooltipTitle = isLight ? '#0F172A' : '#FFFFFF';
    const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)';

    const range = DateRangeHelper.getDateRange(state.dateFilter);
    const filteredTx = state.transactions
      .filter(t => {
        const ts = new Date(t.timestamp);
        return ts >= range.start && ts <= range.end;
      })
      .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    // Group by date
    const daysMap = {};
    filteredTx.forEach(tx => {
      const dStr = new Date(tx.timestamp).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      if (!daysMap[dStr]) {
        daysMap[dStr] = {
          income: 0,
          expense: 0,
          transactions: [],
          dateObj: new Date(tx.timestamp)
        };
      }
      if (tx.type === 'income') daysMap[dStr].income += Number(tx.amount || 0);
      else daysMap[dStr].expense += Number(tx.amount || 0);
      daysMap[dStr].transactions.push(tx);
    });

    const dayEntries = Object.entries(daysMap);
    const labels = [];
    let cumIncome = 0;
    let cumExpense = 0;
    const incomeCumulative = [];
    const expenseCumulative = [];
    const dailyNetList = [];
    const dailyIncomeList = [];
    const dailyExpenseList = [];

    if (dayEntries.length === 0) {
      labels.push('Today');
      incomeCumulative.push(0);
      expenseCumulative.push(0);
      dailyNetList.push(0);
      dailyIncomeList.push(0);
      dailyExpenseList.push(0);
    } else {
      dayEntries.forEach(([day, vals]) => {
        labels.push(day);
        cumIncome += vals.income;
        cumExpense += vals.expense;
        incomeCumulative.push(cumIncome);
        expenseCumulative.push(cumExpense);
        dailyNetList.push(vals.income - vals.expense);
        dailyIncomeList.push(vals.income);
        dailyExpenseList.push(vals.expense);
      });
    }

    const netPeriod = cumIncome - cumExpense;

    // Update Mini Summary
    const summaryContainer = document.getElementById('cf-mini-summary');
    if (summaryContainer) {
      if (this.cashFlowViewMode === 'trajectory') {
        summaryContainer.innerHTML = `
          <div class="cf-mini-item"><span>Total Inflow</span><strong>+${Formatters.currency(cumIncome)}</strong></div>
          <div class="cf-mini-item"><span>Total Outflow</span><strong>-${Formatters.currency(cumExpense)}</strong></div>
          <div class="cf-mini-item"><span>Net Margin</span><strong style="color: ${netPeriod >= 0 ? 'var(--primary)' : 'var(--error)'};">${(netPeriod >= 0 ? '+' : '') + Formatters.currency(netPeriod)}</strong></div>
        `;
      } else if (this.cashFlowViewMode === 'net') {
        let maxSurplusDay = null;
        let maxDeficitDay = null;
        dayEntries.forEach(([day, vals]) => {
          const net = vals.income - vals.expense;
          if (net > 0 && (!maxSurplusDay || net > (maxSurplusDay[1].income - maxSurplusDay[1].expense))) {
            maxSurplusDay = [day, vals];
          }
          if (net < 0 && (!maxDeficitDay || net < (maxDeficitDay[1].income - maxDeficitDay[1].expense))) {
            maxDeficitDay = [day, vals];
          }
        });
        summaryContainer.innerHTML = `
          <div class="cf-mini-item"><span>Net Period Cashflow</span><strong style="color: ${netPeriod >= 0 ? 'var(--primary)' : 'var(--error)'};">${(netPeriod >= 0 ? '+' : '') + Formatters.currency(netPeriod)}</strong></div>
          <div class="cf-mini-item"><span>Top Surplus</span><strong>${maxSurplusDay ? `${maxSurplusDay[0]} (+${Formatters.compactCurrency(maxSurplusDay[1].income - maxSurplusDay[1].expense)})` : 'None'}</strong></div>
          <div class="cf-mini-item"><span>Top Outflow</span><strong>${maxDeficitDay ? `${maxDeficitDay[0]} (-${Formatters.compactCurrency(maxDeficitDay[1].expense - maxDeficitDay[1].income)})` : 'None'}</strong></div>
        `;
      } else {
        summaryContainer.innerHTML = `
          <div class="cf-mini-item"><span>Active Days</span><strong>${dayEntries.length}</strong></div>
          <div class="cf-mini-item"><span>Daily Avg Inflow</span><strong>${Formatters.compactCurrency(dayEntries.length ? cumIncome / dayEntries.length : 0)}</strong></div>
          <div class="cf-mini-item"><span>Daily Avg Outflow</span><strong>${Formatters.compactCurrency(dayEntries.length ? cumExpense / dayEntries.length : 0)}</strong></div>
        `;
      }
    }

    // Chart Options & Datasets by Mode
    let chartConfig = null;

    if (this.cashFlowViewMode === 'trajectory') {
      const gradientInflows = cashFlowCtx.getContext('2d').createLinearGradient(0, 0, 0, 240);
      gradientInflows.addColorStop(0, isLight ? 'rgba(15, 23, 42, 0.12)' : 'rgba(255, 255, 255, 0.15)');
      gradientInflows.addColorStop(1, 'transparent');

      const gradientOutflows = cashFlowCtx.getContext('2d').createLinearGradient(0, 0, 0, 240);
      gradientOutflows.addColorStop(0, isLight ? 'rgba(100, 116, 139, 0.08)' : 'rgba(148, 163, 184, 0.08)');
      gradientOutflows.addColorStop(1, 'transparent');

      chartConfig = {
        type: 'line',
        data: {
          labels,
          datasets: [
            {
              label: 'Inflows',
              data: incomeCumulative,
              borderColor: isLight ? '#0F172A' : '#FFFFFF',
              backgroundColor: gradientInflows,
              borderWidth: 2,
              tension: 0.35,
              fill: true,
              pointRadius: labels.length > 15 ? 0 : 3.5,
              pointHoverRadius: 6,
              pointBackgroundColor: isLight ? '#0F172A' : '#FFFFFF'
            },
            {
              label: 'Outflows',
              data: expenseCumulative,
              borderColor: isLight ? '#64748B' : '#94A3B8',
              backgroundColor: gradientOutflows,
              borderWidth: 2,
              tension: 0.35,
              fill: true,
              pointRadius: labels.length > 15 ? 0 : 3.5,
              pointHoverRadius: 6,
              pointBackgroundColor: isLight ? '#64748B' : '#94A3B8'
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: { mode: 'index', intersect: false },
          layout: { padding: { top: 6, right: 8, bottom: 4, left: 4 } },
          onHover: (event, activeElements) => {
            if (event.native && event.native.target) {
              event.native.target.style.cursor = activeElements.length ? 'pointer' : 'default';
            }
          },
          onClick: (event, elements) => {
            if (!elements || !elements.length) return;
            const idx = elements[0].index;
            const dayLabel = labels[idx];
            const dayData = daysMap[dayLabel];
            if (dayData?.transactions?.length > 0) {
              this.showDateDrillDown(dayLabel, dayData, state);
            }
          },
          plugins: {
            legend: {
              position: 'top',
              labels: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 11.5, weight: 600 }, boxWidth: 10, padding: 12 }
            },
            tooltip: {
              backgroundColor: tooltipBg,
              titleColor: tooltipTitle,
              bodyColor: textColor,
              borderColor: tooltipBorder,
              borderWidth: 1,
              padding: 10,
              cornerRadius: 6,
              callbacks: {
                label: (ctx) => ` ${ctx.dataset.label}: ${Formatters.currency(ctx.parsed.y)}`
              }
            }
          },
          scales: {
            x: {
              grid: { color: gridColor },
              ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 10 }, maxRotation: 0, minRotation: 0, autoSkip: true, maxTicksLimit: 7 }
            },
            y: {
              grid: { color: gridColor },
              border: { dash: [3, 3] },
              ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 10 }, maxTicksLimit: 5, callback: (val) => Formatters.compactCurrency(val) }
            }
          }
        }
      };
    } else if (this.cashFlowViewMode === 'net') {
      const netBarColors = dailyNetList.map(net => {
        if (net >= 0) return isLight ? '#0F172A' : '#FFFFFF';
        return 'rgba(239, 68, 68, 0.85)';
      });

      chartConfig = {
        type: 'bar',
        data: {
          labels,
          datasets: [
            {
              label: 'Net Flow',
              data: dailyNetList,
              backgroundColor: netBarColors,
              borderRadius: 4,
              maxBarThickness: 22
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          layout: { padding: { top: 6, right: 8, bottom: 4, left: 4 } },
          onHover: (event, activeElements) => {
            if (event.native && event.native.target) {
              event.native.target.style.cursor = activeElements.length ? 'pointer' : 'default';
            }
          },
          onClick: (event, elements) => {
            if (!elements || !elements.length) return;
            const idx = elements[0].index;
            const dayLabel = labels[idx];
            const dayData = daysMap[dayLabel];
            if (dayData?.transactions?.length > 0) {
              this.showDateDrillDown(dayLabel, dayData, state);
            }
          },
          plugins: {
            legend: { display: false },
            tooltip: {
              backgroundColor: tooltipBg,
              titleColor: tooltipTitle,
              bodyColor: textColor,
              borderColor: tooltipBorder,
              borderWidth: 1,
              padding: 10,
              cornerRadius: 6,
              callbacks: {
                label: (ctx) => {
                  const val = ctx.parsed.y;
                  const prefix = val >= 0 ? '+' : '';
                  const status = val >= 0 ? 'Surplus' : 'Deficit';
                  return ` Net Flow: ${prefix}${Formatters.currency(val)} (${status})`;
                }
              }
            }
          },
          scales: {
            x: {
              grid: { display: false },
              ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 10 }, maxRotation: 0, minRotation: 0, autoSkip: true, maxTicksLimit: 7 }
            },
            y: {
              grid: {
                color: (ctx) => ctx.tick?.value === 0 ? (isLight ? 'rgba(0,0,0,0.35)' : 'rgba(255,255,255,0.35)') : gridColor
              },
              border: { dash: [3, 3] },
              ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 10 }, maxTicksLimit: 5, callback: (val) => Formatters.compactCurrency(val) }
            }
          }
        }
      };
    } else {
      chartConfig = {
        type: 'bar',
        data: {
          labels,
          datasets: [
            {
              label: 'Inflows',
              data: dailyIncomeList,
              backgroundColor: isLight ? '#0F172A' : '#FFFFFF',
              borderRadius: 4,
              maxBarThickness: 16
            },
            {
              label: 'Outflows',
              data: dailyExpenseList,
              backgroundColor: isLight ? '#64748B' : 'rgba(148, 163, 184, 0.75)',
              borderRadius: 4,
              maxBarThickness: 16
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          layout: { padding: { top: 6, right: 8, bottom: 4, left: 4 } },
          onHover: (event, activeElements) => {
            if (event.native && event.native.target) {
              event.native.target.style.cursor = activeElements.length ? 'pointer' : 'default';
            }
          },
          onClick: (event, elements) => {
            if (!elements || !elements.length) return;
            const idx = elements[0].index;
            const dayLabel = labels[idx];
            const dayData = daysMap[dayLabel];
            if (dayData?.transactions?.length > 0) {
              this.showDateDrillDown(dayLabel, dayData, state);
            }
          },
          plugins: {
            legend: {
              position: 'top',
              labels: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 11.5, weight: 600 }, boxWidth: 10, padding: 12 }
            },
            tooltip: {
              backgroundColor: tooltipBg,
              titleColor: tooltipTitle,
              bodyColor: textColor,
              borderColor: tooltipBorder,
              borderWidth: 1,
              padding: 10,
              cornerRadius: 6,
              callbacks: {
                label: (ctx) => ` ${ctx.dataset.label}: ${Formatters.currency(ctx.parsed.y)}`
              }
            }
          },
          scales: {
            x: {
              grid: { display: false },
              ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 10 }, maxRotation: 0, minRotation: 0, autoSkip: true, maxTicksLimit: 7 }
            },
            y: {
              grid: { color: gridColor },
              border: { dash: [3, 3] },
              ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 10 }, maxTicksLimit: 5, callback: (val) => Formatters.compactCurrency(val) }
            }
          }
        }
      };
    }

    cashFlowChartInstance = new Chart(cashFlowCtx, chartConfig);
  },

  renderCategoryChart(state) {
    const categoryCtx = document.getElementById('category-donut-canvas');
    if (!categoryCtx) return;

    if (categoryChartInstance) {
      categoryChartInstance.destroy();
      categoryChartInstance = null;
    }

    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = activeTheme === 'light';
    const stats = this.calculateStats(state);
    const topCats = this.getTopCategories(state, stats.totalExpenses, isLight);

    if (topCats.length > 0) {
      const labels = topCats.map(c => c.name);
      const data = topCats.map(c => c.amount);
      const colors = topCats.map(c => c.color);

      categoryChartInstance = new Chart(categoryCtx, {
        type: 'doughnut',
        data: {
          labels,
          datasets: [{
            data,
            backgroundColor: colors,
            borderWidth: 0,
            hoverOffset: 8
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: '74%',
          onHover: (event, activeElements) => {
            if (event.native && event.native.target) {
              event.native.target.style.cursor = activeElements.length ? 'pointer' : 'default';
            }
            const donutLabel = document.getElementById('dashboard-cat-donut-label');
            const donutVal = document.getElementById('dashboard-cat-donut-val');
            const catRows = document.querySelectorAll('#dashboard-category-list .category-breakdown-row');

            if (activeElements && activeElements.length > 0) {
              const idx = activeElements[0].index;
              const cat = topCats[idx];
              if (cat) {
                if (donutLabel) donutLabel.textContent = `${cat.name} (${cat.percent}%)`;
                if (donutVal) donutVal.textContent = Formatters.currency(cat.amount);
                catRows.forEach((r, rIdx) => {
                  r.classList.toggle('active', rIdx === idx);
                });
                return;
              }
            }

            if (donutLabel) donutLabel.textContent = 'Total Spend';
            if (donutVal) donutVal.textContent = Formatters.compactCurrency(stats.totalExpenses);
            catRows.forEach(r => r.classList.remove('active'));
          },
          onClick: (event, elements) => {
            if (!elements || !elements.length) return;
            const idx = elements[0].index;
            const cat = topCats[idx];
            if (cat) {
              this.showCategoryDrillDown(cat, state);
            }
          },
          plugins: {
            legend: { display: false },
            tooltip: { enabled: false }
          }
        }
      });

      categoryCtx.addEventListener('mouseleave', () => {
        const donutLabel = document.getElementById('dashboard-cat-donut-label');
        const donutVal = document.getElementById('dashboard-cat-donut-val');
        if (donutLabel) donutLabel.textContent = 'Total Spend';
        if (donutVal) donutVal.textContent = Formatters.compactCurrency(stats.totalExpenses);
        document.querySelectorAll('#dashboard-category-list .category-breakdown-row').forEach(r => {
          r.classList.remove('active');
        });
      });
    }
  },

  showCategoryDrillDown(cat, state) {
    const range = DateRangeHelper.getDateRange(state.dateFilter);
    const categoryTransactions = state.transactions
      .filter(t => {
        const ts = new Date(t.timestamp);
        if (t.type !== 'expense') return false;
        if (ts < range.start || ts > range.end) return false;
        const c = findCategory(state.categories, t.categoryId || t.category_id);
        const name = c ? c.name : 'Other';
        return name.toLowerCase() === cat.name.toLowerCase();
      })
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    const totalSpent = categoryTransactions.reduce((sum, t) => sum + Number(t.amount || 0), 0);
    const txCount = categoryTransactions.length;
    const avgSpend = txCount > 0 ? totalSpent / txCount : 0;

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog drilldown-dialog animate-scale-up">
        <div class="modal-header" style="margin-bottom: 18px; padding-bottom: 14px;">
          <div class="modal-title" style="font-size: 18px;">
            <div class="tx-icon-box" style="width: 38px; height: 38px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border); color: var(--primary);">
              <span class="material-icons" style="font-size: 20px;">${IconHelper.getMaterialIcon(cat.icon)}</span>
            </div>
            <div>
              <div style="color: var(--text-primary); font-weight: 800;">${cat.name} Spending</div>
              <div style="font-size: 12px; font-weight: 500; color: var(--text-muted); margin-top: 2px;">
                ${txCount} ${txCount === 1 ? 'expense' : 'expenses'} in active view
              </div>
            </div>
          </div>
          <button class="modal-close-btn" id="drilldown-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 18px;">close</span>
          </button>
        </div>

        <div class="drilldown-summary-grid">
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Total Spent</div>
            <div class="drilldown-stat-value" style="color: var(--error);">${Formatters.currency(totalSpent)}</div>
          </div>
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Category Share</div>
            <div class="drilldown-stat-value" style="color: var(--text-primary);">${cat.percent || 0}%</div>
          </div>
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Avg / Expense</div>
            <div class="drilldown-stat-value" style="color: var(--text-primary);">${Formatters.currency(avgSpend)}</div>
          </div>
        </div>

        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
          <div style="font-size: 13px; font-weight: 700; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
            <span class="material-icons" style="font-size: 16px; color: var(--primary);">calendar_month</span>
            <span>Itemized Expenses by Date</span>
          </div>
          <span style="font-size: 11.5px; color: var(--text-muted);">Click row to view / edit</span>
        </div>

        <div class="drilldown-tx-list">
          ${categoryTransactions.length === 0 ? `
            <div style="text-align: center; padding: 40px 16px; color: var(--text-muted); font-size: 13px;">
              No individual expenses recorded in this category for this period.
            </div>
          ` : categoryTransactions.map(tx => {
            const d = new Date(tx.timestamp);
            const dateStr = d.toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' });
            const timeStr = d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
            const dayNum = d.getDate();
            const monthStr = d.toLocaleDateString('en-US', { month: 'short' });

            return `
              <div class="drilldown-tx-row" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}">
                <div style="display: flex; align-items: center; gap: 12px; min-width: 0;">
                  <div class="drilldown-date-badge">
                    <span class="drilldown-date-day">${dayNum}</span>
                    <span class="drilldown-date-month">${monthStr}</span>
                  </div>
                  <div style="min-width: 0;">
                    <div style="font-size: 13.5px; font-weight: 700; color: var(--text-primary); text-overflow: ellipsis; overflow: hidden; white-space: nowrap;">
                      ${tx.note || cat.name}
                    </div>
                    <div style="font-size: 11.5px; color: var(--text-muted); display: flex; align-items: center; gap: 8px; margin-top: 2px;">
                      <span>${dateStr} • ${timeStr}</span>
                      ${tx.paymentMode ? `<span class="tx-tag" style="font-size: 10px; padding: 1px 6px;">${tx.paymentMode}</span>` : ''}
                    </div>
                  </div>
                </div>
                <div style="text-align: right; flex-shrink: 0; margin-left: 12px;">
                  <div style="font-size: 14.5px; font-weight: 800; color: var(--error);">
                    -${Formatters.currency(tx.amount)}
                  </div>
                </div>
              </div>
            `;
          }).join('')}
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 22px; padding-top: 14px; border-top: 1px solid var(--glass-border);">
          <button class="btn-ghost" id="drilldown-ledger-btn" style="font-size: 12.5px;">
            <span class="material-icons" style="font-size: 16px;">format_list_bulleted</span> Open Full Ledger
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
  },

  showDateDrillDown(dayLabel, dayData, state) {
    const txList = (dayData.transactions || []).sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    const totalIncome = dayData.income || 0;
    const totalExpense = dayData.expense || 0;
    const netFlow = totalIncome - totalExpense;

    let fullDateTitle = dayLabel;
    if (dayData.dateObj) {
      fullDateTitle = dayData.dateObj.toLocaleDateString('en-US', {
        weekday: 'long',
        month: 'long',
        day: 'numeric',
        year: 'numeric'
      });
    }

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog drilldown-dialog animate-scale-up">
        <div class="modal-header" style="margin-bottom: 18px; padding-bottom: 14px;">
          <div class="modal-title" style="font-size: 18px;">
            <div class="tx-icon-box" style="width: 38px; height: 38px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border); color: var(--primary);">
              <span class="material-icons" style="font-size: 20px;">event</span>
            </div>
            <div>
              <div style="color: var(--text-primary); font-weight: 800;">${fullDateTitle}</div>
              <div style="font-size: 12px; font-weight: 500; color: var(--text-muted); margin-top: 2px;">
                ${txList.length} ${txList.length === 1 ? 'transaction' : 'transactions'} on this date
              </div>
            </div>
          </div>
          <button class="modal-close-btn" id="drilldown-close-btn" aria-label="Close">
            <span class="material-icons" style="font-size: 18px;">close</span>
          </button>
        </div>

        <div class="drilldown-summary-grid">
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Total Inflow</div>
            <div class="drilldown-stat-value" style="color: var(--primary);">+${Formatters.currency(totalIncome)}</div>
          </div>
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Total Outflow</div>
            <div class="drilldown-stat-value" style="color: var(--error);">-${Formatters.currency(totalExpense)}</div>
          </div>
          <div class="drilldown-stat-card">
            <div class="drilldown-stat-label">Net Daily Flow</div>
            <div class="drilldown-stat-value" style="color: ${netFlow >= 0 ? 'var(--primary)' : 'var(--error)'};">
              ${netFlow >= 0 ? '+' : ''}${Formatters.currency(netFlow)}
            </div>
          </div>
        </div>

        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
          <div style="font-size: 13px; font-weight: 700; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
            <span class="material-icons" style="font-size: 16px; color: var(--primary);">receipt_long</span>
            <span>Activity Breakdown</span>
          </div>
          <span style="font-size: 11.5px; color: var(--text-muted);">Click row to view / edit</span>
        </div>

        <div class="drilldown-tx-list">
          ${txList.length === 0 ? `
            <div style="text-align: center; padding: 40px 16px; color: var(--text-muted); font-size: 13px;">
              No transactions recorded for this date.
            </div>
          ` : txList.map(tx => {
            const isIncome = tx.type === 'income';
            const cat = findCategory(state.categories, tx.categoryId || tx.category_id);
            const iconName = cat ? cat.icon : 'category';
            const catName = cat ? cat.name : 'General';
            const d = new Date(tx.timestamp);
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
                      <span>${catName} • ${timeStr}</span>
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
            <span class="material-icons" style="font-size: 16px;">format_list_bulleted</span> Open Full Ledger
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
