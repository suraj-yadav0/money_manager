/* Modern Financial Overview & Command Center Module */
import { Chart, registerables } from 'chart.js';
import { StateManager } from '../state.js';
import { DateRangeHelper } from '../utils/date-range.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';
import { Router } from '../router.js';

// Register Chart.js
Chart.register(...registerables);

let cashFlowChartInstance = null;
let categoryChartInstance = null;

export const DashboardPage = {
  render(state) {
    const stats = this.calculateStats(state);
    const recentTx = this.getRecentTransactions(state);
    const topCategories = this.getTopCategories(state, stats.totalExpenses);
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
                <div class="kpi-icon-box" style="background: ${stats.balance >= 0 ? 'var(--success-bg)' : 'var(--error-bg)'}; color: ${stats.balance >= 0 ? 'var(--success)' : 'var(--error)'};">
                  <span class="material-icons" style="font-size: 20px;">account_balance_wallet</span>
                </div>
              </div>
              <div class="kpi-value" style="color: ${stats.balance >= 0 ? 'var(--text-primary)' : 'var(--error)'};">
                ${Formatters.currency(stats.balance)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge ${stats.balance >= 0 ? 'positive' : 'negative'}">
                  <span class="material-icons" style="font-size: 14px;">${stats.balance >= 0 ? 'trending_up' : 'trending_down'}</span>
                  ${stats.savingsRate}% saved
                </span>
                <span>In selected period</span>
              </div>
            </div>

            <!-- 2. Monthly Income -->
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Inflow</span>
                <div class="kpi-icon-box" style="background: rgba(16, 185, 129, 0.1); color: var(--primary);">
                  <span class="material-icons" style="font-size: 20px;">arrow_downward</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--text-primary);">
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
                <div class="kpi-icon-box" style="background: rgba(244, 63, 94, 0.12); color: var(--error);">
                  <span class="material-icons" style="font-size: 20px;">arrow_upward</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--text-primary);">
                ${Formatters.currency(stats.totalExpenses)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge ${stats.burnRateStatus}">
                  Burn: ${Formatters.currency(stats.dailyBurnRate)}/day
                </span>
              </div>
            </div>

            <!-- 4. Month-End Forecast -->
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Month-End Projection</span>
                <div class="kpi-icon-box" style="background: rgba(99, 102, 241, 0.12); color: var(--indigo);">
                  <span class="material-icons" style="font-size: 20px;">auto_graph</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--text-primary);">
                ${Formatters.currency(stats.projectedBalance)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge ${stats.forecastStatus === 'safe' ? 'positive' : stats.forecastStatus === 'caution' ? 'neutral' : 'negative'}">
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
              <div class="card-header">
                <div class="card-title">
                  <span class="material-icons">query_stats</span>
                  <span>Cash Flow Trajectory</span>
                </div>
                <div style="font-size: 12px; color: var(--text-muted); font-weight: 600;">
                  Cumulative Inflows vs Outflows
                </div>
              </div>
              <div style="position: relative; height: 280px; width: 100%;">
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
              </div>

              ${stats.totalExpenses > 0 ? `
                <div style="position: relative; height: 200px; width: 100%; margin-bottom: 20px;">
                  <canvas id="category-donut-canvas"></canvas>
                </div>
                <div style="display: flex; flex-direction: column; gap: 12px;">
                  ${topCategories.map(cat => `
                    <div>
                      <div style="display: flex; justify-content: space-between; font-size: 13px; font-weight: 600; margin-bottom: 6px;">
                        <span style="display: flex; align-items: center; gap: 6px; color: var(--text-primary);">
                          <span class="material-icons" style="font-size: 16px; color: var(--primary);">${IconHelper.getMaterialIcon(cat.icon)}</span>
                          ${cat.name}
                        </span>
                        <span style="color: var(--text-primary);">${Formatters.currency(cat.amount)} (${cat.percent}%)</span>
                      </div>
                      <div class="progress-track" style="margin: 0;">
                        <div class="progress-bar-fill safe" style="width: ${cat.percent}%;"></div>
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
            <div class="fintech-card" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.08) 0%, rgba(56, 189, 248, 0.04) 100%); border-color: rgba(16, 185, 129, 0.2);">
              <div style="display: flex; gap: 12px; align-items: flex-start;">
                <div style="width: 36px; height: 36px; border-radius: 10px; background: rgba(16, 185, 129, 0.15); display: flex; align-items: center; justify-content: center; color: var(--primary); flex-shrink: 0;">
                  <span class="material-icons" style="font-size: 20px;">lightbulb</span>
                </div>
                <div>
                  <div style="font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 4px;">Smart Wealth Insight</div>
                  <div style="font-size: 13px; color: var(--text-secondary); line-height: 1.5;">
                    ${stats.savingsRate >= 20 
                      ? `Excellent savings discipline! You are currently retaining ${stats.savingsRate}% of your capital this period.`
                      : `Your burn rate is ₹${Math.round(stats.dailyBurnRate)}/day. Consider reducing non-essential expenses in your top spending category.`}
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
    
    let iconBg = isIncome ? 'rgba(16, 185, 129, 0.12)' : 'rgba(244, 63, 94, 0.12)';
    let iconColor = isIncome ? 'var(--success)' : 'var(--error)';

    return `
      <div class="tx-row" data-sync-id="${tx.sync_id || ''}" data-id="${tx.id || ''}">
        <div class="tx-left">
          <div class="tx-icon-box" style="background: ${iconBg}; color: ${iconColor};">
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

  getTopCategories(state, totalExpenses) {
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
        categoryMap[name] = { name, icon, amount: 0 };
      }
      categoryMap[name].amount += tx.amount;
    }

    return Object.values(categoryMap)
      .sort((a, b) => b.amount - a.amount)
      .slice(0, 4)
      .map(c => ({
        ...c,
        percent: Math.round((c.amount / totalExpenses) * 100)
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

    // Initialize Charts after DOM render
    this.renderCharts(state);
  },

  renderCharts(state) {
    // 1. Cash Flow Trend Chart
    const cashFlowCtx = document.getElementById('cashflow-chart-canvas');
    if (cashFlowCtx) {
      if (cashFlowChartInstance) cashFlowChartInstance.destroy();

      const isLight = state.theme === 'light';
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

      // Build daily cumulative trend
      const labels = [];
      const incomeData = [];
      const expenseData = [];
      
      let cumIncome = 0;
      let cumExpense = 0;

      // Group by date
      const daysMap = {};
      filteredTx.forEach(tx => {
        const dStr = new Date(tx.timestamp).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
        if (!daysMap[dStr]) daysMap[dStr] = { income: 0, expense: 0 };
        if (tx.type === 'income') daysMap[dStr].income += tx.amount;
        else daysMap[dStr].expense += tx.amount;
      });

      const dayEntries = Object.entries(daysMap);
      if (dayEntries.length === 0) {
        labels.push('Today');
        incomeData.push(0);
        expenseData.push(0);
      } else {
        dayEntries.forEach(([day, vals]) => {
          labels.push(day);
          cumIncome += vals.income;
          cumExpense += vals.expense;
          incomeData.push(cumIncome);
          expenseData.push(cumExpense);
        });
      }

      const gradientEmerald = cashFlowCtx.getContext('2d').createLinearGradient(0, 0, 0, 260);
      gradientEmerald.addColorStop(0, isLight ? 'rgba(5, 150, 105, 0.15)' : 'rgba(16, 185, 129, 0.18)');
      gradientEmerald.addColorStop(1, isLight ? 'rgba(5, 150, 105, 0.0)' : 'rgba(16, 185, 129, 0.0)');

      const gradientRose = cashFlowCtx.getContext('2d').createLinearGradient(0, 0, 0, 260);
      gradientRose.addColorStop(0, isLight ? 'rgba(225, 29, 72, 0.12)' : 'rgba(244, 63, 94, 0.15)');
      gradientRose.addColorStop(1, isLight ? 'rgba(225, 29, 72, 0.0)' : 'rgba(244, 63, 94, 0.0)');

      cashFlowChartInstance = new Chart(cashFlowCtx, {
        type: 'line',
        data: {
          labels,
          datasets: [
            {
              label: 'Inflows',
              data: incomeData,
              borderColor: isLight ? '#059669' : '#10B981',
              backgroundColor: gradientEmerald,
              borderWidth: 2,
              tension: 0.35,
              fill: true,
              pointRadius: labels.length > 20 ? 0 : 3.5,
              pointBackgroundColor: isLight ? '#059669' : '#10B981',
            },
            {
              label: 'Outflows',
              data: expenseData,
              borderColor: isLight ? '#E11D48' : '#F43F5E',
              backgroundColor: gradientRose,
              borderWidth: 2,
              tension: 0.35,
              fill: true,
              pointRadius: labels.length > 20 ? 0 : 3.5,
              pointBackgroundColor: isLight ? '#E11D48' : '#F43F5E',
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'top',
              labels: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 12, weight: 600 }, boxWidth: 12 }
            },
            tooltip: {
              backgroundColor: tooltipBg,
              titleColor: tooltipTitle,
              bodyColor: textColor,
              borderColor: tooltipBorder,
              borderWidth: 1,
              padding: 12,
              cornerRadius: 10,
              boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
              callbacks: {
                label: (ctx) => ` ${ctx.dataset.label}: ${Formatters.currency(ctx.parsed.y)}`
              }
            }
          },
          scales: {
            x: {
              grid: { color: gridColor },
              ticks: { color: textColor, font: { family: 'Plus Jakarta Sans', size: 11 } }
            },
            y: {
              grid: { color: gridColor },
              ticks: {
                color: textColor,
                font: { family: 'Plus Jakarta Sans', size: 11 },
                callback: (val) => Formatters.compactCurrency(val)
              }
            }
          }
        }
      });
    }

    // 2. Category Donut Chart
    const categoryCtx = document.getElementById('category-donut-canvas');
    if (categoryCtx) {
      if (categoryChartInstance) categoryChartInstance.destroy();

      const isLight = state.theme === 'light';
      const topCats = this.getTopCategories(state, 100);
      if (topCats.length > 0) {
        const labels = topCats.map(c => c.name);
        const data = topCats.map(c => c.amount);
        const colors = isLight 
          ? ['#059669', '#0284C7', '#4F46E5', '#D97706', '#E11D48', '#0D9488']
          : ['#10B981', '#38BDF8', '#818CF8', '#F59E0B', '#F43F5E', '#14B8A6'];

        categoryChartInstance = new Chart(categoryCtx, {
          type: 'doughnut',
          data: {
            labels,
            datasets: [{
              data,
              backgroundColor: colors.slice(0, labels.length),
              borderWidth: 0,
              hoverOffset: 6
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            cutout: '74%',
            plugins: {
              legend: { display: false },
              tooltip: {
                backgroundColor: isLight ? '#FFFFFF' : '#11141E',
                titleColor: isLight ? '#0F172A' : '#FFFFFF',
                bodyColor: isLight ? '#475569' : '#94A3B8',
                borderColor: isLight ? 'rgba(0, 0, 0, 0.08)' : 'rgba(255, 255, 255, 0.12)',
                borderWidth: 1,
                padding: 10,
                cornerRadius: 8,
                callbacks: {
                  label: (ctx) => ` ${ctx.label}: ${Formatters.currency(ctx.parsed)}`
                }
              }
            }
          }
        });
      }
    }
  }
};
