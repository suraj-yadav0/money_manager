/* Calendar Screen Module (monthly calendar grid, daily transaction indicators and listings) */
import { StateManager } from '../state.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper } from '../utils/icons.js';
import { Router } from '../router.js';

export const CalendarPage = {
  selectedYear: new Date().getFullYear(),
  selectedMonth: new Date().getMonth(), // 0-11
  selectedDay: new Date().getDate(),    // 1-31

  render(state) {
    const daysInMonth = new Date(this.selectedYear, this.selectedMonth + 1, 0).getDate();
    const firstDayIndex = new Date(this.selectedYear, this.selectedMonth, 1).getDay(); // 0=Sunday, 1=Monday
    
    // Convert firstDayIndex so Monday = 0, Sunday = 6 to match ISO week layout
    const startOffset = firstDayIndex === 0 ? 6 : firstDayIndex - 1;

    const monthLabel = new Date(this.selectedYear, this.selectedMonth, 1).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    const dailyTx = this.getTransactionsForSelectedDay(state);
    const dayStats = this.calculateDailyTotals(state);

    return `
      <div class="modal-card animate-fade-in" style="background:#131124; max-height:90vh; display:flex; flex-direction:column; width:100%; max-width:600px; padding:32px 40px;">
        <div class="modal-header" style="border-bottom:1px solid var(--divider); padding-bottom:12px; margin-bottom:12px;">
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="material-icons" style="color:var(--primary);">calendar_today</span>
            <h3 style="color:#FFF; font-size:20px;">Calendar View</h3>
          </div>
          <button class="modal-close" id="cal-close-btn">&times;</button>
        </div>

        <div style="flex:1; overflow-y:auto; display:flex; flex-direction:column; gap:16px;">
          <!-- Month selector -->
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <button class="btn-icon" id="cal-prev-month" style="width:36px; height:36px;"><span class="material-icons">chevron_left</span></button>
            <div style="font-size:16px; font-weight:700;">${monthLabel}</div>
            <button class="btn-icon" id="cal-next-month" style="width:36px; height:36px;"><span class="material-icons">chevron_right</span></button>
          </div>

          <!-- Calendar Grid -->
          <div>
            <!-- Weekday headers -->
            <div style="display:grid; grid-template-columns:repeat(7, 1fr); text-align:center; font-size:11px; font-weight:600; color:var(--text-muted); margin-bottom:8px;">
              <div>Mon</div><div>Tue</div><div>Wed</div><div>Thu</div><div>Fri</div><div>Sat</div><div>Sun</div>
            </div>
            
            <!-- Calendar days grid -->
            <div style="display:grid; grid-template-columns:repeat(7, 1fr); gap:8px; text-align:center;" id="calendar-days-grid">
              ${this.renderCalendarDays(state, startOffset, daysInMonth)}
            </div>
          </div>

          <!-- Selected Day Stats -->
          <div style="display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.03); border-radius:12px; padding:12px 16px; border:1px solid var(--glass-border);">
            <div style="font-weight:600; font-size:13px;">
              ${this.selectedDay} ${new Date(this.selectedYear, this.selectedMonth, 1).toLocaleDateString('en-US', { month: 'short' })} Summary
            </div>
            <div style="display:flex; gap:16px; font-size:13px; font-weight:700;">
              ${dayStats.income > 0 ? `<span style="color:var(--success);">+${Formatters.currency(dayStats.income)}</span>` : ''}
              ${dayStats.expense > 0 ? `<span style="color:var(--text-primary);">${Formatters.currency(dayStats.expense)}</span>` : ''}
              ${dayStats.income === 0 && dayStats.expense === 0 ? '<span style="color:var(--text-muted);">No activity</span>' : ''}
            </div>
          </div>

          <!-- Selected Day Transactions list -->
          <div class="glass-card" style="padding:10px 20px; flex:1; min-height:120px; overflow-y:auto;">
            ${dailyTx.length === 0 ? `
              <div style="text-align:center; padding:20px 0; color:var(--text-muted); font-size:13px;">No transactions recorded on this day.</div>
            ` : dailyTx.map(tx => this.renderTransactionRow(tx, state.categories)).join('')}
          </div>
        </div>
      </div>
    `;
  },

  renderCalendarDays(state, offset, daysInMonth) {
    let cellsHtml = '';

    // Empty offset cells
    for (let i = 0; i < offset; i++) {
      cellsHtml += `<div style="height:40px;"></div>`;
    }

    // Days cells
    for (let day = 1; day <= daysInMonth; day++) {
      const isSelected = day === this.selectedDay;
      const dayTx = this.getTransactionsForDay(state, day);
      
      const hasIncome = dayTx.some(t => t.type === 'income');
      const hasExpense = dayTx.some(t => t.type === 'expense');

      let dotHtml = '';
      if (hasIncome && hasExpense) {
        dotHtml = `<div style="display:flex; justify-content:center; gap:2px; margin-top:2px;">
                     <span style="width:4px; height:4px; border-radius:50%; background:var(--success);"></span>
                     <span style="width:4px; height:4px; border-radius:50%; background:var(--primary);"></span>
                   </div>`;
      } else if (hasIncome) {
        dotHtml = `<div style="margin-top:2px;"><span style="display:inline-block; width:4px; height:4px; border-radius:50%; background:var(--success);"></span></div>`;
      } else if (hasExpense) {
        dotHtml = `<div style="margin-top:2px;"><span style="display:inline-block; width:4px; height:4px; border-radius:50%; background:var(--primary);"></span></div>`;
      }

      cellsHtml += `
        <div class="calendar-day-cell ${isSelected ? 'active' : ''}" 
             data-day="${day}"
             style="height:44px; display:flex; flex-direction:column; align-items:center; justify-content:center; border-radius:8px; cursor:pointer; font-weight:600; font-size:13px; background:${isSelected ? 'var(--primary)' : 'transparent'}; color:${isSelected ? '#FFF' : 'var(--text-primary)'}; transition:var(--transition-fast);">
          <span>${day}</span>
          ${dotHtml}
        </div>
      `;
    }

    return cellsHtml;
  },

  renderTransactionRow(tx, categories) {
    const cat = categories.find(c => c.id === tx.categoryId || c.sync_id === tx.categoryId);
    const icon = IconHelper.getMaterialIcon(cat ? cat.icon : 'category');
    const isIncome = tx.type === 'income';
    const formattedAmount = (isIncome ? '+' : '-') + Formatters.currency(tx.amount);
    
    let iconBg = 'rgba(255, 255, 255, 0.08)';
    if (cat) {
      if (cat.type === 'income') iconBg = 'rgba(16, 185, 129, 0.15)';
      else iconBg = 'rgba(255, 95, 31, 0.15)';
    }

    return `
      <div class="calendar-tx-row" data-sync-id="${tx.sync_id}" data-id="${tx.id || ''}"
           style="display:flex; align-items:center; justify-content:space-between; padding:12px 0; border-bottom:1px solid var(--divider); cursor:pointer;">
        <div class="transaction-icon-box" style="background: ${iconBg}; color: ${isIncome ? 'var(--success)' : 'var(--primary)'}; width:36px; height:36px; font-size:18px;">
          <span class="material-icons" style="font-size:18px;">${icon}</span>
        </div>
        <div class="tx-details" style="margin-left:10px;">
          <div class="tx-note" style="font-size:13px;">${tx.note || (cat ? cat.name : 'Transaction')}</div>
          <div class="tx-category" style="font-size:11px;">${cat ? cat.name : 'Other'}</div>
        </div>
        <div style="text-align:right;">
          <div class="tx-amount ${isIncome ? 'income' : 'expense'}" style="font-size:14px; font-weight:600;">${formattedAmount}</div>
          <div class="tx-date" style="font-size:10px; color:var(--text-muted);">${Formatters.time(new Date(tx.timestamp))}</div>
        </div>
      </div>
    `;
  },

  getTransactionsForDay(state, day) {
    return state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return ts.getFullYear() === this.selectedYear &&
             ts.getMonth() === this.selectedMonth &&
             ts.getDate() === day;
    });
  },

  getTransactionsForSelectedDay(state) {
    return this.getTransactionsForDay(state, this.selectedDay)
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  },

  calculateDailyTotals(state) {
    const list = this.getTransactionsForSelectedDay(state);
    let income = 0;
    let expense = 0;

    for (const t of list) {
      if (t.type === 'income') income += t.amount;
      else expense += t.amount;
    }

    return { income, expense };
  },

  bindEvents(state) {
    // Close button
    document.getElementById('cal-close-btn').addEventListener('click', () => {
      Router.closeOverlay();
    });

    // Month navigation
    document.getElementById('cal-prev-month').addEventListener('click', () => {
      this.selectedMonth--;
      if (this.selectedMonth < 0) {
        this.selectedMonth = 11;
        this.selectedYear--;
      }
      this.selectedDay = 1;
      StateManager.notify();
    });

    document.getElementById('cal-next-month').addEventListener('click', () => {
      this.selectedMonth++;
      if (this.selectedMonth > 11) {
        this.selectedMonth = 0;
        this.selectedYear++;
      }
      this.selectedDay = 1;
      StateManager.notify();
    });

    // Grid day cell click events
    const dayCells = document.querySelectorAll('.calendar-day-cell');
    dayCells.forEach(cell => {
      cell.addEventListener('click', () => {
        const day = parseInt(cell.getAttribute('data-day'), 10);
        this.selectedDay = day;
        StateManager.notify();
      });
    });

    // Row edit clicks
    const rows = document.querySelectorAll('.calendar-tx-row');
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
  }
};
