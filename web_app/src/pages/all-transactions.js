/* Modern Financial Transactions Ledger Module */
import { Chart, registerables } from 'chart.js';
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';
import { DbService } from '../db.js';

Chart.register(...registerables);

let ledgerCategoryChartInstance = null;
let ledgerTimelineChartInstance = null;

export const AllTransactionsPage = {
  activeTypeFilter: 'all', // 'all', 'income', 'expense', 'recurring'
  activeCategoryFilter: null, // string (category name) or null
  activeDateFilter: null, // string or null
  searchQuery: '',

  getCategoryBreakdown(transactions, categories, activeType, isLight) {
    const categoryMap = {};
    let totalTarget = 0;

    transactions.forEach(t => {
      const isTarget = activeType === 'income' ? t.type === 'income' : t.type === 'expense';
      if (isTarget) {
        const cat = findCategory(categories, t.categoryId || t.category_id);
        const name = cat ? cat.name : 'Other';
        const icon = cat ? cat.icon : 'category';

        if (!categoryMap[name]) {
          categoryMap[name] = { name, icon, amount: 0, count: 0 };
        }
        categoryMap[name].amount += Number(t.amount || 0);
        categoryMap[name].count += 1;
        totalTarget += Number(t.amount || 0);
      }
    });

    const colorsDark = ['#FFFFFF', '#E2E8F0', '#CBD5E1', '#94A3B8', '#64748B', '#475569', '#334155'];
    const colorsLight = ['#0F172A', '#334155', '#475569', '#64748B', '#94A3B8', '#CBD5E1', '#E2E8F0'];
    const palette = isLight ? colorsLight : colorsDark;

    const sorted = Object.values(categoryMap).sort((a, b) => b.amount - a.amount);
    const items = sorted.map((c, idx) => ({
      ...c,
      color: palette[idx % palette.length],
      percent: totalTarget > 0 ? Math.round((c.amount / totalTarget) * 100) : 0
    }));

    return { items, total: totalTarget, activeType };
  },

  getTimelineData(transactions) {
    const daysMap = {};
    const sortedTx = [...transactions].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    sortedTx.forEach(t => {
      const d = new Date(t.timestamp);
      const dStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      if (!daysMap[dStr]) {
        daysMap[dStr] = { expense: 0, income: 0, count: 0, dateStr: dStr };
      }
      if (t.type === 'expense') daysMap[dStr].expense += Number(t.amount || 0);
      else daysMap[dStr].income += Number(t.amount || 0);
      daysMap[dStr].count += 1;
    });

    const dayEntries = Object.entries(daysMap);
    const recentEntries = dayEntries.slice(-8);

    return {
      labels: recentEntries.map(([d]) => d),
      expenseData: recentEntries.map(([_, v]) => v.expense),
      incomeData: recentEntries.map(([_, v]) => v.income),
      daysMap
    };
  },

  getFilteredTransactions(state) {
    return state.transactions
      .filter(t => {
        // Type filter
        if (this.activeTypeFilter === 'income' && t.type !== 'income') return false;
        if (this.activeTypeFilter === 'expense' && t.type !== 'expense') return false;
        if (this.activeTypeFilter === 'recurring' && !(t.isRecurring || t.is_recurring)) return false;

        // Category filter
        if (this.activeCategoryFilter) {
          const cat = findCategory(state.categories, t.categoryId || t.category_id);
          const catName = cat ? cat.name.toLowerCase() : 'other';
          if (catName !== this.activeCategoryFilter.toLowerCase()) return false;
        }

        // Date filter
        if (this.activeDateFilter) {
          const dStr = new Date(t.timestamp).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
          if (dStr !== this.activeDateFilter) return false;
        }

        // Search query
        if (this.searchQuery && this.searchQuery.trim() !== '') {
          const query = this.searchQuery.toLowerCase();
          const noteMatch = t.note && t.note.toLowerCase().includes(query);
          const cat = findCategory(state.categories, t.categoryId || t.category_id);
          const catMatch = cat && cat.name.toLowerCase().includes(query);
          const modeMatch = (t.paymentMode || t.payment_mode || '').toLowerCase().includes(query);
          return noteMatch || catMatch || modeMatch;
        }

        return true;
      })
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  },

  render(state) {
    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = activeTheme === 'light';

    const list = this.getFilteredTransactions(state);
    const categoryBreakdown = this.getCategoryBreakdown(state.transactions, state.categories, this.activeTypeFilter, isLight);

    // Calculate totals on current filtered set
    let ledgerIncome = 0;
    let ledgerExpense = 0;
    list.forEach(tx => {
      if (tx.type === 'income') ledgerIncome += Number(tx.amount || 0);
      else ledgerExpense += Number(tx.amount || 0);
    });
    const netFlow = ledgerIncome - ledgerExpense;

    const activeCatObj = this.activeCategoryFilter 
      ? categoryBreakdown.items.find(c => c.name.toLowerCase() === this.activeCategoryFilter.toLowerCase())
      : null;

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 20px;">
        <!-- Header & Action Controls -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header" style="margin-bottom: 20px;">
            <div>
              <h1 class="hero-welcome-title">Transaction Ledger</h1>
              <p class="hero-subtitle">Comprehensive financial activity, visual category analytics, and audit history.</p>
            </div>

            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
              <button class="btn-secondary" id="export-ledger-btn" style="flex: 1; min-width: 120px; justify-content: center; padding: 8px 14px; font-size: 13px;">
                <span class="material-icons" style="font-size: 16px;">download</span> Export JSON
              </button>
              <button class="btn-primary" id="ledger-add-tx-btn" style="flex: 1; min-width: 140px; justify-content: center; padding: 8px 14px; font-size: 13px;">
                <span class="material-icons" style="font-size: 18px;">add</span> Add Transaction
              </button>
            </div>
          </div>

          <!-- Ledger Summary Grid -->
          <div class="ledger-summary-grid">
            <div class="ledger-stat-card">
              <span class="ledger-stat-label">Filtered Entries</span>
              <div class="ledger-stat-value" id="ledger-entries-count">${list.length} records</div>
            </div>

            <div class="ledger-stat-card">
              <span class="ledger-stat-label">Total Inflow</span>
              <div class="ledger-stat-value" style="color: var(--primary);" id="ledger-inflow-total">+${Formatters.currency(ledgerIncome)}</div>
            </div>

            <div class="ledger-stat-card">
              <span class="ledger-stat-label">Total Outflow</span>
              <div class="ledger-stat-value" style="color: var(--error);" id="ledger-outflow-total">-${Formatters.currency(ledgerExpense)}</div>
            </div>

            <div class="ledger-stat-card">
              <span class="ledger-stat-label">Net Flow</span>
              <div class="ledger-stat-value" style="color: ${netFlow >= 0 ? 'var(--primary)' : 'var(--error)'};" id="ledger-net-flow">
                ${(netFlow >= 0 ? '+' : '') + Formatters.currency(netFlow)}
              </div>
            </div>
          </div>
        </section>

        <!-- Charts & Spending Analytics Section -->
        <div class="ledger-charts-grid" id="ledger-charts-section">
          <!-- Category Spending Breakdown Card -->
          <div class="fintech-card" style="padding: 20px 22px;">
            <div class="card-header" style="margin-bottom: 16px;">
              <div class="card-title">
                <span class="material-icons">pie_chart</span>
                <span>${this.activeTypeFilter === 'income' ? 'Income by Category' : 'Spend by Category'}</span>
              </div>
              <div class="card-header-actions">
                <span class="kpi-badge neutral drilldown-hint" style="font-size: 11px; font-weight: 600;" title="Click to filter">
                  <span class="material-icons" style="font-size: 12px; margin-right: 2px;">touch_app</span><span class="hint-text">Click to filter</span>
                </span>
                <span id="ledger-cat-header-badge">
                  ${this.activeCategoryFilter ? `
                    <button class="kpi-badge" id="ledger-clear-category-pill-btn" style="cursor: pointer; background: var(--bg-surface-elevated); border: 1px solid var(--text-primary); color: var(--text-primary); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; gap: 4px;">
                      ${this.activeCategoryFilter} <span class="material-icons" style="font-size: 13px;">close</span>
                    </button>
                  ` : ''}
                </span>
              </div>
            </div>

            <!-- Split view: Donut Chart on left, Category list on right -->
            <div class="ledger-donut-split">
              <div style="position: relative; height: 180px; width: 100%; display: flex; align-items: center; justify-content: center;">
                <canvas id="ledger-category-donut-canvas"></canvas>
                <div class="nw-donut-center" style="max-width: 120px;">
                  <div class="nw-donut-center-label" id="ledger-donut-label">
                    ${activeCatObj ? activeCatObj.name : (this.activeTypeFilter === 'income' ? 'Total Inflow' : 'Total Spend')}
                  </div>
                  <div class="nw-donut-center-val" id="ledger-donut-val">
                    ${Formatters.compactCurrency(activeCatObj ? activeCatObj.amount : categoryBreakdown.total)}
                  </div>
                </div>
              </div>

              <!-- Ranked Category List -->
              <div style="display: flex; flex-direction: column; gap: 6px; max-height: 180px; overflow-y: auto; padding-right: 4px;" id="ledger-category-list">
                ${categoryBreakdown.items.length === 0 ? `
                  <div style="text-align: center; padding: 40px 10px; color: var(--text-muted); font-size: 12.5px;">
                    No category data recorded yet.
                  </div>
                ` : categoryBreakdown.items.map(cat => `
                  <div class="ledger-cat-row ${this.activeCategoryFilter?.toLowerCase() === cat.name.toLowerCase() ? 'active' : ''}" data-cat-name="${cat.name}" title="Filter by ${cat.name}" style="min-width: 0;">
                    <div style="display: flex; align-items: center; gap: 8px; min-width: 0; flex: 1;">
                      <span class="nw-color-dot" style="background: ${cat.color}; flex-shrink: 0;"></span>
                      <span style="font-size: 12px; font-weight: 600; color: var(--text-primary); text-overflow: ellipsis; overflow: hidden; white-space: nowrap; max-width: 140px;">${cat.name}</span>
                    </div>
                    <div style="display: flex; align-items: center; gap: 6px; flex-shrink: 0; margin-left: 8px;">
                      <span style="font-size: 12px; font-weight: 700; color: var(--text-primary);">${Formatters.currency(cat.amount)}</span>
                      <span style="font-size: 10.5px; color: var(--text-muted);">(${cat.percent}%)</span>
                    </div>
                  </div>
                `).join('')}
              </div>
            </div>
          </div>

          <!-- Cash Flow Pacing Timeline Card -->
          <div class="fintech-card" style="padding: 20px 22px;">
            <div class="card-header" style="margin-bottom: 14px;">
              <div class="card-title">
                <span class="material-icons">bar_chart</span>
                <span>Daily Spend Velocity</span>
              </div>
              <div class="card-header-actions">
                <span class="kpi-badge neutral drilldown-hint" style="font-size: 11px; font-weight: 600;" title="Click day to filter">
                  <span class="material-icons" style="font-size: 12px; margin-right: 2px;">touch_app</span><span class="hint-text">Click day to filter</span>
                </span>
                <span id="ledger-date-header-badge">
                  ${this.activeDateFilter ? `
                    <button class="kpi-badge" id="ledger-clear-date-pill-btn" style="cursor: pointer; background: var(--bg-surface-elevated); border: 1px solid var(--text-primary); color: var(--text-primary); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; gap: 4px;">
                      ${this.activeDateFilter} <span class="material-icons" style="font-size: 13px;">close</span>
                    </button>
                  ` : ''}
                </span>
              </div>
            </div>

            <div style="position: relative; height: 180px; width: 100%; max-width: 100%; min-width: 0; overflow: hidden;">
              <canvas id="ledger-timeline-canvas"></canvas>
            </div>
          </div>
        </div>

        <!-- Interactive Category Quick-Filter Strip -->
        <div class="ledger-category-strip" id="ledger-category-strip">
          <button class="ledger-cat-pill ${!this.activeCategoryFilter ? 'active' : ''}" data-cat="all">
            <span>All Categories</span>
            <span class="ledger-cat-pill-count">(${state.transactions.length})</span>
          </button>
          ${categoryBreakdown.items.map(cat => `
            <button class="ledger-cat-pill ${this.activeCategoryFilter?.toLowerCase() === cat.name.toLowerCase() ? 'active' : ''}" data-cat="${cat.name}">
              <span class="material-icons" style="font-size: 14px; opacity: 0.75;">${IconHelper.getMaterialIcon(cat.icon)}</span>
              <span>${cat.name}</span>
              <span class="ledger-cat-pill-count">${Formatters.compactCurrency(cat.amount)}</span>
            </button>
          `).join('')}
        </div>

        <!-- Search Bar and Type Filter Tabs -->
        <div style="display: flex; gap: 16px; align-items: center; justify-content: space-between; flex-wrap: wrap;">
          <!-- Search Input with Clear Button -->
          <div style="flex: 1 1 280px; max-width: 480px; width: 100%;">
            <div class="search-bar-wrapper" style="position: relative;">
              <span class="material-icons search-icon">search</span>
              <input type="text" class="search-input" id="ledger-search-input" placeholder="Search by note, merchant, or category..." value="${this.searchQuery}" style="padding-right: 38px;">
              <button type="button" class="btn-icon" id="ledger-search-clear-btn" style="position: absolute; right: 8px; width: 28px; height: 28px; display: ${this.searchQuery ? 'flex' : 'none'}; cursor: pointer; border: none; background: transparent;" title="Clear search">
                <span class="material-icons" style="font-size: 16px; color: var(--text-muted);">close</span>
              </button>
            </div>
          </div>

          <!-- Type Filter Chips -->
          <div class="filter-group" style="display: flex; width: 100%; max-width: 440px; padding: 4px; gap: 4px;">
            <button class="filter-chip ${this.activeTypeFilter === 'all' ? 'active' : ''}" data-type="all" style="flex: 1; justify-content: center; text-align: center; padding: 6px 10px; font-size: 12.5px;">All</button>
            <button class="filter-chip ${this.activeTypeFilter === 'income' ? 'active' : ''}" data-type="income" style="flex: 1; justify-content: center; text-align: center; padding: 6px 10px; font-size: 12.5px;">Income</button>
            <button class="filter-chip ${this.activeTypeFilter === 'expense' ? 'active' : ''}" data-type="expense" style="flex: 1; justify-content: center; text-align: center; padding: 6px 10px; font-size: 12.5px;">Expenses</button>
            <button class="filter-chip ${this.activeTypeFilter === 'recurring' ? 'active' : ''}" data-type="recurring" style="flex: 1; justify-content: center; text-align: center; padding: 6px 10px; font-size: 12.5px;">Recurring</button>
          </div>
        </div>

        <!-- Active Filter Alert Banner Container -->
        <div id="ledger-filter-banner-container">
          ${this.renderFilterBanner(list.length)}
        </div>

        <!-- Transactions Ledger List -->
        <div class="fintech-card" style="padding: 16px 20px;" id="ledger-card-body">
          ${list.length === 0 ? `
            <div style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
              <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                <span class="material-icons" style="font-size: 28px; opacity: 0.5;">search_off</span>
              </div>
              <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px;">No matching transactions found</div>
              <div style="font-size: 13px; margin-bottom: 16px;">No records match the active category and criteria.</div>
              ${(this.activeCategoryFilter || this.activeDateFilter) ? `
                <button class="btn-secondary btn-sm" id="ledger-empty-clear-filter-btn" style="display: inline-flex; align-items: center; gap: 6px; margin: 0 auto;">
                  <span class="material-icons" style="font-size: 15px;">filter_alt_off</span> Clear Active Filters
                </button>
              ` : ''}
            </div>
          ` : `
            <div class="tx-list">
              ${list.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
            </div>
          `}
        </div>
      </div>
    `;
  },

  renderFilterBanner(matchCount) {
    if (!this.activeCategoryFilter && !this.activeDateFilter) return '';
    return `
      <div class="ledger-active-filter-bar">
        <div style="display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; color: var(--text-primary); flex-wrap: wrap;">
          <span class="material-icons" style="font-size: 18px; color: var(--text-primary);">filter_alt</span>
          <span>
            Filtered by: 
            ${this.activeCategoryFilter ? `<strong>Category: ${this.activeCategoryFilter}</strong>` : ''}
            ${(this.activeCategoryFilter && this.activeDateFilter) ? ' • ' : ''}
            ${this.activeDateFilter ? `<strong>Date: ${this.activeDateFilter}</strong>` : ''}
            (${matchCount} ${matchCount === 1 ? 'transaction' : 'transactions'})
          </span>
        </div>
        <button class="btn-ghost btn-sm" id="ledger-reset-all-filters-btn" style="padding: 4px 10px; font-size: 12px; display: inline-flex; align-items: center; gap: 4px;">
          <span class="material-icons" style="font-size: 14px;">close</span> Reset Filters
        </button>
      </div>
    `;
  },

  renderCharts(state) {
    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = activeTheme === 'light';
    const textColor = isLight ? '#475569' : '#94A3B8';
    const gridColor = isLight ? 'rgba(0, 0, 0, 0.05)' : 'rgba(255, 255, 255, 0.05)';
    const tooltipBg = isLight ? '#FFFFFF' : '#11141E';
    const tooltipTitle = isLight ? '#0F172A' : '#FFFFFF';
    const tooltipBorder = isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)';

    // 1. Category Donut Chart
    const catCanvas = document.getElementById('ledger-category-donut-canvas');
    if (catCanvas) {
      if (ledgerCategoryChartInstance) {
        ledgerCategoryChartInstance.destroy();
        ledgerCategoryChartInstance = null;
      }

      const breakdown = this.getCategoryBreakdown(state.transactions, state.categories, this.activeTypeFilter, isLight);
      if (breakdown.items.length > 0) {
        ledgerCategoryChartInstance = new Chart(catCanvas, {
          type: 'doughnut',
          data: {
            labels: breakdown.items.map(i => i.name),
            datasets: [{
              data: breakdown.items.map(i => i.amount),
              backgroundColor: breakdown.items.map(i => i.color),
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
              const donutLabel = document.getElementById('ledger-donut-label');
              const donutVal = document.getElementById('ledger-donut-val');
              const rows = document.querySelectorAll('.ledger-cat-row');

              if (activeElements && activeElements.length > 0) {
                const idx = activeElements[0].index;
                const cat = breakdown.items[idx];
                if (cat) {
                  if (donutLabel) donutLabel.textContent = `${cat.name} (${cat.percent}%)`;
                  if (donutVal) donutVal.textContent = Formatters.compactCurrency(cat.amount);
                  rows.forEach((row, rIdx) => {
                    const isMatch = rIdx === idx;
                    row.style.background = isMatch ? 'var(--bg-surface-hover)' : '';
                    row.style.borderColor = isMatch ? 'var(--text-primary)' : '';
                  });
                  return;
                }
              }

              const activeCat = this.activeCategoryFilter 
                ? breakdown.items.find(c => c.name.toLowerCase() === this.activeCategoryFilter.toLowerCase())
                : null;
              if (donutLabel) donutLabel.textContent = activeCat ? activeCat.name : (this.activeTypeFilter === 'income' ? 'Total Inflow' : 'Total Spend');
              if (donutVal) donutVal.textContent = Formatters.compactCurrency(activeCat ? activeCat.amount : breakdown.total);
              rows.forEach(row => {
                row.style.background = '';
                row.style.borderColor = '';
              });
            },
            onClick: (event, elements) => {
              if (!elements || !elements.length) return;
              const idx = elements[0].index;
              const cat = breakdown.items[idx];
              if (cat) {
                if (this.activeCategoryFilter?.toLowerCase() === cat.name.toLowerCase()) {
                  this.activeCategoryFilter = null;
                } else {
                  this.activeCategoryFilter = cat.name;
                }
                this.updateLedgerView(state);
              }
            },
            plugins: {
              legend: { display: false },
              tooltip: { enabled: false }
            }
          }
        });

        catCanvas.addEventListener('mouseleave', () => {
          const donutLabel = document.getElementById('ledger-donut-label');
          const donutVal = document.getElementById('ledger-donut-val');
          const activeCat = this.activeCategoryFilter 
            ? breakdown.items.find(c => c.name.toLowerCase() === this.activeCategoryFilter.toLowerCase())
            : null;
          if (donutLabel) donutLabel.textContent = activeCat ? activeCat.name : (this.activeTypeFilter === 'income' ? 'Total Inflow' : 'Total Spend');
          if (donutVal) donutVal.textContent = Formatters.compactCurrency(activeCat ? activeCat.amount : breakdown.total);
          document.querySelectorAll('.ledger-cat-row').forEach(row => {
            row.style.background = '';
            row.style.borderColor = '';
          });
        });
      }
    }

    // 2. Timeline Bar Chart
    const timelineCanvas = document.getElementById('ledger-timeline-canvas');
    if (timelineCanvas) {
      if (ledgerTimelineChartInstance) {
        ledgerTimelineChartInstance.destroy();
        ledgerTimelineChartInstance = null;
      }

      const timeline = this.getTimelineData(state.transactions);
      if (timeline.labels.length > 0) {
        const barColor = isLight ? '#0F172A' : '#FFFFFF';
        const barHoverColor = isLight ? '#334155' : '#CBD5E1';

        ledgerTimelineChartInstance = new Chart(timelineCanvas, {
          type: 'bar',
          data: {
            labels: timeline.labels,
            datasets: [{
              label: 'Outflows',
              data: timeline.expenseData,
              backgroundColor: barColor,
              hoverBackgroundColor: barHoverColor,
              borderRadius: 4,
              maxBarThickness: 24
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            layout: {
              padding: { top: 6, right: 8, bottom: 4, left: 4 }
            },
            onHover: (event, activeElements) => {
              if (event.native && event.native.target) {
                event.native.target.style.cursor = activeElements.length ? 'pointer' : 'default';
              }
            },
            onClick: (event, elements) => {
              if (!elements || !elements.length) return;
              const idx = elements[0].index;
              const dayLabel = timeline.labels[idx];
              if (this.activeDateFilter === dayLabel) {
                this.activeDateFilter = null;
              } else {
                this.activeDateFilter = dayLabel;
              }
              this.updateLedgerView(state);
            },
            plugins: {
              legend: { display: false },
              tooltip: {
                backgroundColor: tooltipBg,
                titleColor: tooltipTitle,
                bodyColor: textColor,
                borderColor: tooltipBorder,
                borderWidth: 1,
                padding: 8,
                cornerRadius: 6,
                callbacks: {
                  label: (ctx) => ` Spent: ${Formatters.currency(ctx.parsed.y)}`
                }
              }
            },
            scales: {
              x: {
                grid: { display: false },
                ticks: {
                  color: textColor,
                  font: { family: 'Plus Jakarta Sans', size: 10 },
                  maxRotation: 0,
                  minRotation: 0,
                  autoSkip: true,
                  maxTicksLimit: 7
                }
              },
              y: {
                grid: { color: gridColor },
                border: { dash: [3, 3] },
                ticks: {
                  color: textColor,
                  font: { family: 'Plus Jakarta Sans', size: 10 },
                  maxTicksLimit: 4,
                  callback: (val) => Formatters.compactCurrency(val)
                }
              }
            }
          }
        });
      }
    }
  },

  renderTransactionRow(tx, categories) {
    const cat = findCategory(categories, tx.categoryId || tx.category_id);
    const icon = IconHelper.getMaterialIcon(cat ? cat.icon : 'category');
    const isIncome = tx.type === 'income';
    const formattedAmount = (isIncome ? '+' : '-') + Formatters.currency(tx.amount);

    return `
      <div class="tx-row ledger-tx-row" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}">
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
              ${tx.isRecurring || tx.is_recurring ? `<span class="tx-tag">Recurring</span>` : ''}
              ${tx.goalId || tx.goal_id ? `<span class="tx-tag">Goal Linked</span>` : ''}
            </div>
          </div>
        </div>
        <div class="tx-right">
          <div style="display: flex; flex-direction: column; align-items: flex-end; justify-content: center;">
            <div class="tx-amount ${isIncome ? 'income' : 'expense'}">${formattedAmount}</div>
            <div class="tx-date">${Formatters.dateTime(tx.timestamp)}</div>
          </div>
          <button class="btn-icon btn-icon-sm delete-tx-btn" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}" title="Delete transaction" style="flex-shrink: 0;">
            <span class="material-icons" style="font-size: 16px;">delete_outline</span>
          </button>
        </div>
      </div>
    `;
  },

  updateLedgerView(state) {
    const activeTheme = document.documentElement.getAttribute('data-theme') || state.theme || 'dark';
    const isLight = activeTheme === 'light';

    const list = this.getFilteredTransactions(state);
    const categoryBreakdown = this.getCategoryBreakdown(state.transactions, state.categories, this.activeTypeFilter, isLight);

    // Calculate totals on current filtered set
    let ledgerIncome = 0;
    let ledgerExpense = 0;
    list.forEach(tx => {
      if (tx.type === 'income') ledgerIncome += Number(tx.amount || 0);
      else ledgerExpense += Number(tx.amount || 0);
    });
    const netFlow = ledgerIncome - ledgerExpense;

    const entriesEl = document.getElementById('ledger-entries-count');
    if (entriesEl) entriesEl.textContent = `${list.length} records`;

    const inflowEl = document.getElementById('ledger-inflow-total');
    if (inflowEl) inflowEl.textContent = `+${Formatters.currency(ledgerIncome)}`;

    const outflowEl = document.getElementById('ledger-outflow-total');
    if (outflowEl) outflowEl.textContent = `-${Formatters.currency(ledgerExpense)}`;

    const netFlowEl = document.getElementById('ledger-net-flow');
    if (netFlowEl) {
      netFlowEl.textContent = `${(netFlow >= 0 ? '+' : '') + Formatters.currency(netFlow)}`;
      netFlowEl.style.color = netFlow >= 0 ? 'var(--primary)' : 'var(--error)';
    }

    // Update donut center label
    const donutLabel = document.getElementById('ledger-donut-label');
    const donutVal = document.getElementById('ledger-donut-val');
    const activeCatObj = this.activeCategoryFilter 
      ? categoryBreakdown.items.find(c => c.name.toLowerCase() === this.activeCategoryFilter.toLowerCase())
      : null;

    if (donutLabel) donutLabel.textContent = activeCatObj ? activeCatObj.name : (this.activeTypeFilter === 'income' ? 'Total Inflow' : 'Total Spend');
    if (donutVal) donutVal.textContent = Formatters.compactCurrency(activeCatObj ? activeCatObj.amount : categoryBreakdown.total);

    // Update Category Pills
    document.querySelectorAll('.ledger-cat-pill').forEach(pill => {
      const cat = pill.getAttribute('data-cat');
      if (cat === 'all') {
        pill.classList.toggle('active', !this.activeCategoryFilter);
      } else {
        pill.classList.toggle('active', this.activeCategoryFilter?.toLowerCase() === cat?.toLowerCase());
      }
    });

    // Update Category Rows in breakdown list
    document.querySelectorAll('.ledger-cat-row').forEach(row => {
      const cat = row.getAttribute('data-cat-name');
      row.classList.toggle('active', this.activeCategoryFilter?.toLowerCase() === cat?.toLowerCase());
    });

    // Update Filter Chips for Type
    document.querySelectorAll('.filter-chip[data-type]').forEach(chip => {
      chip.classList.toggle('active', chip.getAttribute('data-type') === this.activeTypeFilter);
    });

    // Update banner container
    const bannerContainer = document.getElementById('ledger-filter-banner-container');
    if (bannerContainer) {
      bannerContainer.innerHTML = this.renderFilterBanner(list.length);
      document.getElementById('ledger-reset-all-filters-btn')?.addEventListener('click', () => {
        this.activeCategoryFilter = null;
        this.activeDateFilter = null;
        this.updateLedgerView(state);
      });
    }

    // Update Category header badge
    const catBadgeContainer = document.getElementById('ledger-cat-header-badge');
    if (catBadgeContainer) {
      if (this.activeCategoryFilter) {
        catBadgeContainer.innerHTML = `
          <button class="kpi-badge" id="ledger-clear-category-pill-btn" style="cursor: pointer; background: var(--bg-surface-elevated); border: 1px solid var(--text-primary); color: var(--text-primary); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; gap: 4px;">
            ${this.activeCategoryFilter} <span class="material-icons" style="font-size: 13px;">close</span>
          </button>
        `;
        document.getElementById('ledger-clear-category-pill-btn')?.addEventListener('click', () => {
          this.activeCategoryFilter = null;
          this.updateLedgerView(state);
        });
      } else {
        catBadgeContainer.innerHTML = '';
      }
    }

    // Update Date header badge
    const dateBadgeContainer = document.getElementById('ledger-date-header-badge');
    if (dateBadgeContainer) {
      if (this.activeDateFilter) {
        dateBadgeContainer.innerHTML = `
          <button class="kpi-badge" id="ledger-clear-date-pill-btn" style="cursor: pointer; background: var(--bg-surface-elevated); border: 1px solid var(--text-primary); color: var(--text-primary); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; gap: 4px;">
            ${this.activeDateFilter} <span class="material-icons" style="font-size: 13px;">close</span>
          </button>
        `;
        document.getElementById('ledger-clear-date-pill-btn')?.addEventListener('click', () => {
          this.activeDateFilter = null;
          this.updateLedgerView(state);
        });
      } else {
        dateBadgeContainer.innerHTML = '';
      }
    }

    // Re-render transactions list body
    const listCardBody = document.getElementById('ledger-card-body');
    if (listCardBody) {
      if (list.length === 0) {
        listCardBody.innerHTML = `
          <div style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
            <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
              <span class="material-icons" style="font-size: 28px; opacity: 0.5;">search_off</span>
            </div>
            <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px;">No matching transactions found</div>
            <div style="font-size: 13px; margin-bottom: 16px;">No records match the active category and criteria.</div>
            ${(this.activeCategoryFilter || this.activeDateFilter) ? `
              <button class="btn-secondary btn-sm" id="ledger-empty-clear-filter-btn" style="display: inline-flex; align-items: center; gap: 6px; margin: 0 auto;">
                <span class="material-icons" style="font-size: 15px;">filter_alt_off</span> Clear Active Filters
              </button>
            ` : ''}
          </div>
        `;
        document.getElementById('ledger-empty-clear-filter-btn')?.addEventListener('click', () => {
          this.activeCategoryFilter = null;
          this.activeDateFilter = null;
          this.updateLedgerView(state);
        });
      } else {
        listCardBody.innerHTML = `
          <div class="tx-list">
            ${list.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
          </div>
        `;
      }
      this.bindRowEvents(state);
    }
  },

  bindEvents(state) {
    const searchInput = document.getElementById('ledger-search-input');
    const clearBtn = document.getElementById('ledger-search-clear-btn');

    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value;
        if (clearBtn) clearBtn.style.display = this.searchQuery ? 'flex' : 'none';
        this.updateLedgerView(state);
      });
    }

    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        this.searchQuery = '';
        if (searchInput) {
          searchInput.value = '';
          searchInput.focus();
        }
        clearBtn.style.display = 'none';
        this.updateLedgerView(state);
      });
    }

    // Type filter chips
    document.querySelectorAll('.filter-chip[data-type]').forEach(chip => {
      chip.addEventListener('click', () => {
        this.activeTypeFilter = chip.getAttribute('data-type');
        this.activeCategoryFilter = null;
        this.activeDateFilter = null;
        
        const container = document.getElementById('app-main-content');
        if (container) {
          container.innerHTML = this.render(state);
          this.bindEvents(state);
        } else {
          this.renderCharts(state);
          this.updateLedgerView(state);
        }
      });
    });

    // Category Quick-Filter Strip Pills
    document.querySelectorAll('.ledger-cat-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        const cat = pill.getAttribute('data-cat');
        if (cat === 'all') {
          this.activeCategoryFilter = null;
        } else if (this.activeCategoryFilter?.toLowerCase() === cat.toLowerCase()) {
          this.activeCategoryFilter = null;
        } else {
          this.activeCategoryFilter = cat;
        }
        this.updateLedgerView(state);
      });
    });

    // Category Rows in breakdown card
    document.querySelectorAll('.ledger-cat-row').forEach(row => {
      row.addEventListener('click', () => {
        const cat = row.getAttribute('data-cat-name');
        if (this.activeCategoryFilter?.toLowerCase() === cat.toLowerCase()) {
          this.activeCategoryFilter = null;
        } else {
          this.activeCategoryFilter = cat;
        }
        this.updateLedgerView(state);
      });
    });

    // Clear filter buttons
    document.getElementById('ledger-clear-category-pill-btn')?.addEventListener('click', () => {
      this.activeCategoryFilter = null;
      this.updateLedgerView(state);
    });

    document.getElementById('ledger-clear-date-pill-btn')?.addEventListener('click', () => {
      this.activeDateFilter = null;
      this.updateLedgerView(state);
    });

    document.getElementById('ledger-reset-all-filters-btn')?.addEventListener('click', () => {
      this.activeCategoryFilter = null;
      this.activeDateFilter = null;
      this.updateLedgerView(state);
    });

    document.getElementById('ledger-empty-clear-filter-btn')?.addEventListener('click', () => {
      this.activeCategoryFilter = null;
      this.activeDateFilter = null;
      this.updateLedgerView(state);
    });

    // Add Transaction CTA
    document.getElementById('ledger-add-tx-btn')?.addEventListener('click', () => {
      import('./add-transaction.js').then(({ AddTransactionModal }) => {
        AddTransactionModal.show(null);
      });
    });

    // Export JSON CTA
    document.getElementById('export-ledger-btn')?.addEventListener('click', () => {
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(state.transactions, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `quantro_ledger_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    this.bindRowEvents(state);
    this.renderCharts(state);
  },

  bindRowEvents(state) {
    const rows = document.querySelectorAll('.ledger-tx-row');
    rows.forEach(row => {
      row.addEventListener('click', (e) => {
        if (e.target.closest('.delete-tx-btn')) return;

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

    const delBtns = document.querySelectorAll('.delete-tx-btn');
    delBtns.forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const syncId = btn.getAttribute('data-sync-id');
        const localId = btn.getAttribute('data-id');
        if (confirm('Are you sure you want to delete this transaction?')) {
          await DbService.deleteTransaction(syncId, localId);
        }
      });
    });
  }
};

