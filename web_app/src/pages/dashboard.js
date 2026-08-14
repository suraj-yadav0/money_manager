/* Dashboard Page Module (Home screen showing balances, forecast, charts, and recent items) */
import { Chart, registerables } from 'chart.js';
import { StateManager } from '../state.js';
import { DateRangeHelper } from '../utils/date-range.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';
import { Router } from '../router.js';

// Register all Chart.js modules
Chart.register(...registerables);

// Track active chart instances to prevent canvas re-use errors
let pieChartInstance = null;
let lineChartInstance = null;

export const DashboardPage = {
  render(state) {
    const stats = this.calculateStats(state);
    const recentTx = this.getRecentTransactions(state);
    const currencySymbol = Formatters.currency(0).substring(0, 1);

    return `
      <div class="animate-fade-in" style="display:flex; flex-wrap:wrap; gap:24px; align-items:flex-start;">
        
        <!-- Left Column: Stats & Charts -->
        <div style="flex: 1 1 500px; display:flex; flex-direction:column; gap:24px; min-width:0;">
          
          <!-- Date Filters -->
          <div style="display: flex; gap: 8px; overflow-x: auto; padding-bottom: 4px; scrollbar-width: none;">
            ${this.renderFilterButton('thisWeek', 'This Week', state.dateFilter)}
            ${this.renderFilterButton('lastWeek', 'Last Week', state.dateFilter)}
            ${this.renderFilterButton('thisMonth', 'This Month', state.dateFilter)}
            ${this.renderFilterButton('lastMonth', 'Last Month', state.dateFilter)}
            ${this.renderFilterButton('thisYear', 'This Year', state.dateFilter)}
            ${this.renderFilterButton('allTime', 'All Time', state.dateFilter)}
          </div>

          <!-- Top Stats Row -->
          <div class="grid-2">
            <!-- Balance glass card -->
            <div class="glass-card balance-container" style="margin:0; height: 100%;">
              <div class="balance-title">Net Balance</div>
              <div class="balance-value" style="color: ${stats.balance >= 0 ? 'var(--success)' : 'var(--error)'}; font-size: 32px;">
                ${Formatters.currency(stats.balance)}
              </div>
              
              <div class="balance-stats-row" style="margin-top:auto;">
                <div class="balance-stat-item">
                  <div class="balance-stat-label">Income</div>
                  <div class="balance-stat-val" style="color: var(--success);">${Formatters.currency(stats.totalIncome)}</div>
                </div>
                <div class="balance-stat-item" style="text-align: right;">
                  <div class="balance-stat-label">Expenses</div>
                  <div class="balance-stat-val" style="color: var(--text-primary);">${Formatters.currency(stats.totalExpenses)}</div>
                </div>
              </div>
            </div>

            <!-- Forecast widget -->
            ${state.dateFilter === 'thisMonth' ? `
              <div class="glass-card" style="display:flex; flex-direction:column; justify-content:center; padding: 20px;">
                <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                  <div>
                    <div style="font-size: 13px; color: var(--text-muted); text-transform: uppercase;">Month-End Projection</div>
                    <div style="font-size: 24px; font-weight: 700; margin-top: 8px;">
                      ${Formatters.currency(stats.projectedBalance)}
                    </div>
                  </div>
                  <div class="forecast-badge forecast-${stats.forecastStatus}" style="padding:6px 12px;">
                    ${stats.forecastStatus === 'safe' ? 'On Track' : stats.forecastStatus === 'caution' ? 'Borderline' : 'At Risk'}
                  </div>
                </div>
              </div>
            ` : `
              <div class="glass-card" style="display:flex; align-items:center; justify-content:center; padding: 20px; color:var(--text-muted);">
                <div style="text-align:center;">
                  <span class="material-icons" style="font-size:32px; opacity:0.5; margin-bottom:8px;">auto_graph</span>
                  <div style="font-size:13px;">Forecast available for 'This Month'</div>
                </div>
              </div>
            `}
          </div>

          <!-- Charts Container -->
          ${stats.totalExpenses > 0 ? `
            <div class="grid-2">
              <div class="glass-card">
                <h3 style="font-size: 15px; margin-bottom: 16px;">Spending Breakdown</h3>
                <div style="position: relative; height: 260px; width: 100%;">
                  <canvas id="dashboard-pie-chart"></canvas>
                </div>
              </div>
              <div class="glass-card">
                <h3 style="font-size: 15px; margin-bottom: 16px;">Cumulative Spend</h3>
                <div style="position: relative; height: 260px; width: 100%;">
                  <canvas id="dashboard-line-chart"></canvas>
                </div>
              </div>
            </div>
          ` : `
            <div class="glass-card" style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
              <span class="material-icons" style="font-size: 48px; margin-bottom: 12px; color: var(--glass-border);">pie_chart_outlined</span>
              <p style="font-size: 14px;">No expense data for this period.</p>
            </div>
          `}
        </div>

        <!-- Right Column: Recent Transactions -->
        <div style="flex: 1 1 360px; max-width: 100%; display:flex; flex-direction:column; gap:16px;">
          <div class="transaction-list-header" style="margin:0;">
            <h3 class="transaction-list-title" style="font-size:18px;">Recent Transactions</h3>
            <a href="#" id="dashboard-see-all" style="font-size: 13px; font-weight: 600;">See All</a>
          </div>

          <div class="glass-card" style="padding: 10px 20px; min-height: 500px;">
            ${recentTx.length === 0 ? `
              <div style="text-align: center; padding: 40px 0; color: var(--text-muted); font-size: 13px;">No transactions found.</div>
            ` : recentTx.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
          </div>
        </div>

      </div>
    `;
  },

  renderFilterButton(filterKey, label, activeFilter) {
    const isActive = filterKey === activeFilter;
    return `
      <button class="tab-button ${isActive ? 'active' : ''}" 
              style="flex: none; padding: 8px 16px; border-radius: 20px; font-size: 13px; white-space: nowrap;"
              data-filter="${filterKey}">
        ${label}
      </button>
    `;
  },

  renderTransactionRow(tx, categories) {
    const cat = findCategory(categories, tx.categoryId || tx.category_id);
    const icon = IconHelper.getMaterialIcon(cat ? cat.icon : 'category');
    const isIncome = tx.type === 'income';
    const formattedAmount = (isIncome ? '+' : '-') + Formatters.currency(tx.amount);
    
    // Set custom icon background colors based on category names
    let iconBg = 'rgba(255, 255, 255, 0.08)';
    if (cat) {
      if (cat.type === 'income') iconBg = 'rgba(16, 185, 129, 0.15)';
      else iconBg = 'rgba(255, 95, 31, 0.15)';
    }

    return `
      <div class="transaction-row" data-sync-id="${tx.sync_id}" data-id="${tx.id || ''}">
        <div class="transaction-icon-box" style="background: ${iconBg}; color: ${isIncome ? 'var(--success)' : 'var(--primary)'};">
          <span class="material-icons">${icon}</span>
        </div>
        <div class="tx-details">
          <div class="tx-note">${tx.note || (cat ? cat.name : 'Transaction')}</div>
          <div class="tx-category">${cat ? cat.name : 'Other'}</div>
        </div>
        <div class="tx-amount-box">
          <div class="tx-amount ${isIncome ? 'income' : 'expense'}">${formattedAmount}</div>
          <div class="tx-date">${Formatters.relativeDate(tx.timestamp)}</div>
        </div>
      </div>
    `;
  },

  calculateStats(state) {
    const range = DateRangeHelper.getDateRange(state.dateFilter);
    const txList = state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return ts >= range.start && ts <= range.end;
    });

    let totalIncome = 0;
    let totalExpenses = 0;
    let categoryMap = {};

    for (const tx of txList) {
      if (tx.type === 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
        
        // Populate category totals for charts
        const cat = findCategory(state.categories, tx.categoryId || tx.category_id);
        const name = cat ? cat.name : 'Other';
        categoryMap[name] = (categoryMap[name] || 0) + tx.amount;
      }
    }

    const balance = totalIncome - totalExpenses;
    
    // Projections logic (matches Flutter)
    let dailyBurnRate = 0;
    let projectedBalance = balance;
    let forecastStatus = 'safe';

    if (state.dateFilter === 'thisMonth') {
      const daysElapsed = Formatters.daysElapsedInMonth();
      const daysRemaining = Formatters.daysRemainingInMonth();
      dailyBurnRate = daysElapsed > 0 ? totalExpenses / daysElapsed : 0;
      projectedBalance = balance - (dailyBurnRate * daysRemaining);
      
      const monthlyIncome = state.userSettings ? state.userSettings.monthlyIncome : 0;

      if (projectedBalance > monthlyIncome * 0.2) {
        forecastStatus = 'safe';
      } else if (projectedBalance > 0) {
        forecastStatus = 'caution';
      } else {
        forecastStatus = 'deficit';
      }
    }

    return {
      totalIncome,
      totalExpenses,
      balance,
      projectedBalance,
      forecastStatus,
      categoryTotals: categoryMap
    };
  },

  getRecentTransactions(state) {
    const range = DateRangeHelper.getDateRange(state.dateFilter);
    return state.transactions
      .filter(t => {
        const ts = new Date(t.timestamp);
        return ts >= range.start && ts <= range.end;
      })
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
      .slice(0, 5);
  },

  bindEvents(state) {
    // Date filter click events
    const filterButtons = document.querySelectorAll('[data-filter]');
    filterButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const filter = btn.getAttribute('data-filter');
        StateManager.setState({ dateFilter: filter });
      });
    });

    // Calendar view button click
    const calBtn = document.getElementById('dashboard-cal-btn');
    if (calBtn) {
      calBtn.addEventListener('click', () => {
        Router.navigateToOverlay('calendar');
      });
    }

    // See all transactions click
    const seeAllBtn = document.getElementById('dashboard-see-all');
    if (seeAllBtn) {
      seeAllBtn.addEventListener('click', (e) => {
        e.preventDefault();
        Router.navigateToOverlay('all-transactions');
      });
    }

    // Row edit clicks
    const rows = document.querySelectorAll('.transaction-row');
    rows.forEach(row => {
      row.addEventListener('click', () => {
        const syncId = row.getAttribute('data-sync-id');
        const localId = parseInt(row.getAttribute('data-id'), 10) || null;
        const tx = state.transactions.find(t => t.sync_id === syncId || (localId && t.id === localId));
        
        if (tx) {
          import('./add-transaction.js').then(({ AddTransactionModal }) => {
            AddTransactionModal.show(tx);
          });
        }
      });
    });

    // Render Charts
    this.renderCharts(state);
  },

  renderCharts(state) {
    const stats = this.calculateStats(state);
    if (stats.totalExpenses <= 0) return;

    // 1. Pie Chart for Category Spending
    const pieCtx = document.getElementById('dashboard-pie-chart');
    if (pieCtx) {
      if (pieChartInstance) pieChartInstance.destroy();
      
      const labels = Object.keys(stats.categoryTotals);
      const data = Object.values(stats.categoryTotals);
      
      // Beautiful Naruto color palette mapping
      const chartColors = [
        '#FF5F1F', // Naruto Orange
        '#00C6FF', // Chakra Blue
        '#FF0033', // Kurama Red
        '#10B981', // Leaf Green
        '#FFD700', // Gold
        '#9D50BB', // Purple
        '#FF69B4', // Pink
        '#8B0000', // Dark Red
        '#4B0082'  // Indigo
      ];

      pieChartInstance = new Chart(pieCtx, {
        type: 'doughnut',
        data: {
          labels,
          datasets: [{
            data,
            backgroundColor: chartColors.slice(0, labels.length),
            borderWidth: 1,
            borderColor: 'rgba(255, 255, 255, 0.1)'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'right',
              labels: {
                color: '#FFF',
                font: { family: 'Inter', size: 11 }
              }
            }
          }
        }
      });
    }

    // 2. Line Chart for Cumulative Spending Trend
    const lineCtx = document.getElementById('dashboard-line-chart');
    if (lineCtx) {
      if (lineChartInstance) lineChartInstance.destroy();

      const range = DateRangeHelper.getDateRange(state.dateFilter);
      const txList = state.transactions
        .filter(t => t.type === 'expense' && new Date(t.timestamp) >= range.start && new Date(t.timestamp) <= range.end)
        .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

      // Calculate cumulative spending per day
      const dailyMap = {};
      
      // Seed all dates in range with cumulative value
      let current = new Date(range.start);
      const end = new Date(range.end > new Date() ? new Date() : range.end); // don't forecast past today on cumulative actuals
      
      while (current <= end) {
        const key = current.toLocaleDateString('en-US', { day: 'numeric', month: 'short' });
        dailyMap[key] = 0;
        current.setDate(current.getDate() + 1);
      }

      // Populate spending amounts
      for (const tx of txList) {
        const key = new Date(tx.timestamp).toLocaleDateString('en-US', { day: 'numeric', month: 'short' });
        if (dailyMap[key] !== undefined) {
          dailyMap[key] += tx.amount;
        }
      }

      // Make cumulative
      let runningTotal = 0;
      const labels = Object.keys(dailyMap);
      const data = labels.map(label => {
        runningTotal += dailyMap[label];
        return runningTotal;
      });

      lineChartInstance = new Chart(lineCtx, {
        type: 'line',
        data: {
          labels,
          datasets: [{
            label: 'Cumulative Spending',
            data,
            borderColor: '#FF5F1F',
            backgroundColor: 'rgba(255, 95, 31, 0.1)',
            fill: true,
            tension: 0.3,
            borderWidth: 2,
            pointRadius: labels.length > 31 ? 0 : 2
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false }
          },
          scales: {
            x: {
              ticks: { color: 'rgba(255, 255, 255, 0.5)', maxRotation: 45, minRotation: 45, font: { size: 9 } },
              grid: { display: false }
            },
            y: {
              ticks: { color: 'rgba(255, 255, 255, 0.5)', font: { size: 9 } },
              grid: { color: 'rgba(255, 255, 255, 0.05)' }
            }
          }
        }
      });
    }
  }
};
