/* Modern Calendar Financial Grid Module */
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';

export const CalendarPage = {
  currentDate: new Date(),
  selectedDay: new Date().getDate(),

  render(state) {
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth();
    const monthName = this.currentDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

    // Transactions for selected day
    const dayTransactions = this.getDayTransactions(state, year, month, this.selectedDay);
    
    // Month totals
    const monthTx = state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return ts.getFullYear() === year && ts.getMonth() === month;
    });

    let monthIncome = 0;
    let monthExpense = 0;
    monthTx.forEach(t => {
      if (t.type === 'income') monthIncome += t.amount;
      else monthExpense += t.amount;
    });

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 20px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Calendar Schedule</h1>
              <p class="hero-subtitle">Chronological expenditure heatmap and daily financial events.</p>
            </div>

            <!-- Month Navigator -->
            <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px; background: var(--bg-surface-elevated); padding: 4px 8px; border-radius: var(--radius-sm); border: 1px solid var(--glass-border);">
              <button class="btn-icon btn-icon-sm" id="cal-prev-month">
                <span class="material-icons" style="font-size: 18px;">chevron_left</span>
              </button>
              <div style="font-weight: 700; font-size: 14px; min-width: 130px; text-align: center; color: var(--text-primary); font-family: var(--font-heading);">
                ${monthName}
              </div>
              <button class="btn-icon btn-icon-sm" id="cal-next-month">
                <span class="material-icons" style="font-size: 18px;">chevron_right</span>
              </button>
            </div>
          </div>

          <!-- Calendar KPI Stat Cards -->
          <div class="kpi-grid">
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Month Inflow</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">arrow_downward</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(monthIncome)}</div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Month Outflow</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">arrow_upward</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(monthExpense)}</div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Active Days</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">calendar_month</span>
                </div>
              </div>
              <div class="kpi-value">${new Set(monthTx.map(t => new Date(t.timestamp).getDate())).size} days</div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Net Monthly</span>
                <div class="kpi-icon-box">
                  <span class="material-icons">account_balance</span>
                </div>
              </div>
              <div class="kpi-value">
                ${Formatters.currency(monthIncome - monthExpense)}
              </div>
            </div>
          </div>
        </section>

        <!-- Calendar Grid & Day Activity Split -->
        <div class="dashboard-split-grid">
          
          <!-- Calendar Matrix Card -->
          <div class="fintech-card">
            <!-- Day of Week Header -->
            <div style="display: grid; grid-template-columns: repeat(7, 1fr); text-align: center; font-size: 11px; font-weight: 700; color: var(--text-muted); margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.05em;">
              <div>Sun</div><div>Mon</div><div>Tue</div><div>Wed</div><div>Thu</div><div>Fri</div><div>Sat</div>
            </div>

            <!-- Calendar Cells -->
            <div style="display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px;" id="calendar-days-grid">
              ${this.renderCalendarCells(state, year, month)}
            </div>
          </div>

          <!-- Day Transactions Drilldown -->
          <div class="fintech-card">
            <div class="card-header">
              <div class="card-title">
                <span class="material-icons">event</span>
                <span>Day ${this.selectedDay} Activity</span>
              </div>
              <span style="font-size: 13px; font-weight: 700; color: var(--text-secondary);">
                ${dayTransactions.length} events
              </span>
            </div>

            ${dayTransactions.length === 0 ? `
              <div style="text-align: center; padding: 36px 0; color: var(--text-muted); font-size: 13px;">
                No transactions recorded on this day.
              </div>
            ` : `
              <div class="tx-list">
                ${dayTransactions.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
              </div>
            `}
          </div>

        </div>
      </div>
    `;
  },

  renderCalendarCells(state, year, month) {
    const firstDayIndex = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    
    // Group transactions by day
    const dayTotals = {};
    state.transactions.forEach(t => {
      const ts = new Date(t.timestamp);
      if (ts.getFullYear() === year && ts.getMonth() === month) {
        const d = ts.getDate();
        if (!dayTotals[d]) dayTotals[d] = { count: 0, expense: 0, income: 0 };
        dayTotals[d].count++;
        if (t.type === 'income') dayTotals[d].income += t.amount;
        else dayTotals[d].expense += t.amount;
      }
    });

    let cellsHtml = '';

    // Empty lead cells
    for (let i = 0; i < firstDayIndex; i++) {
      cellsHtml += `<div style="height: 48px; border-radius: var(--radius-xs); opacity: 0.15;"></div>`;
    }

    // Days in Month
    for (let day = 1; day <= daysInMonth; day++) {
      const isSelected = day === this.selectedDay;
      const data = dayTotals[day];
      const hasSpend = data && data.expense > 0;
      const hasIncome = data && data.income > 0;

      let borderStyle = isSelected ? '1px solid var(--primary)' : '1px solid var(--glass-border)';
      let bgStyle = isSelected ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)';

      cellsHtml += `
        <div class="cal-day-cell" data-day="${day}" 
             style="min-height: 48px; padding: 4px; border-radius: var(--radius-xs); background: ${bgStyle}; border: ${borderStyle}; cursor: pointer; display: flex; flex-direction: column; justify-content: space-between; transition: var(--transition-fast);">
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <span style="font-size: 12px; font-weight: ${isSelected ? '800' : '600'}; color: ${isSelected ? 'var(--primary)' : 'var(--text-primary)'};">${day}</span>
            ${data && data.count > 0 ? `
              <span style="width: 5px; height: 5px; border-radius: 50%; background: var(--text-primary);"></span>
            ` : ''}
          </div>
          <div style="font-size: 9px; font-weight: 600; color: var(--text-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
            ${data ? (hasIncome ? `+${Formatters.compactCurrency(data.income)}` : `-${Formatters.compactCurrency(data.expense)}`) : ''}
          </div>
        </div>
      `;
    }

    return cellsHtml;
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
            </div>
          </div>
        </div>
        <div class="tx-right">
          <div>
            <div class="tx-amount ${isIncome ? 'income' : 'expense'}">${formattedAmount}</div>
            <div class="tx-date">${Formatters.time(tx.timestamp)}</div>
          </div>
        </div>
      </div>
    `;
  },

  getDayTransactions(state, year, month, day) {
    return state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return ts.getFullYear() === year && ts.getMonth() === month && ts.getDate() === day;
    });
  },

  bindEvents(state) {
    // Prev Month
    document.getElementById('cal-prev-month')?.addEventListener('click', () => {
      this.currentDate = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() - 1, 1);
      this.selectedDay = 1;
      StateManager.notify();
    });

    // Next Month
    document.getElementById('cal-next-month')?.addEventListener('click', () => {
      this.currentDate = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() + 1, 1);
      this.selectedDay = 1;
      StateManager.notify();
    });

    // Day cell click
    const cells = document.querySelectorAll('.cal-day-cell');
    cells.forEach(cell => {
      cell.addEventListener('click', () => {
        const day = parseInt(cell.getAttribute('data-day'), 10);
        this.selectedDay = day;
        StateManager.notify();
      });
    });
  }
};
