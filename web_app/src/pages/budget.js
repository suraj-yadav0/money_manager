/* Modern Budget Planning & Allocations Module */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { DateRangeHelper } from '../utils/date-range.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';

export const BudgetPage = {
  currentDate: new Date(),

  render(state) {
    const targetDate = this.currentDate || new Date();
    const year = targetDate.getFullYear();
    const month = targetDate.getMonth();
    const monthName = targetDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    const now = new Date();
    const isCurrentMonth = year === now.getFullYear() && month === now.getMonth();
    const isPastMonth = year < now.getFullYear() || (year === now.getFullYear() && month < now.getMonth());
    const isFutureMonth = year > now.getFullYear() || (year === now.getFullYear() && month > now.getMonth());

    const stats = this.calculateBudgetStats(state);
    const suggestions = this.calculateAverageCategorySpending(state);
    const suggestionEntries = Object.entries(suggestions);

    // Dynamic timeline month strip centered on targetDate or current month
    const centerDate = Math.abs((year - now.getFullYear()) * 12 + (month - now.getMonth())) > 2 ? targetDate : now;
    const timelineMonths = [];
    for (let offset = -3; offset <= 2; offset++) {
      const d = new Date(centerDate.getFullYear(), centerDate.getMonth() + offset, 1);
      const isSelected = d.getFullYear() === year && d.getMonth() === month;
      const isCurrent = d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
      timelineMonths.push({
        year: d.getFullYear(),
        month: d.getMonth(),
        label: d.toLocaleDateString('en-US', { month: 'short', year: 'numeric' }),
        isSelected,
        isCurrent
      });
    }

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 28px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Budget & Allocations</h1>
              <p class="hero-subtitle">Set category thresholds, track utilization burn rates, and receive automated pacing suggestions.</p>
            </div>
            
            <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
              <!-- Timeline Month Navigator -->
              <div class="budget-timeline-nav" style="display: flex; align-items: center; gap: 4px; background: var(--bg-surface-elevated); padding: 4px 6px; border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
                <button class="btn-icon btn-icon-sm" id="budget-prev-month" title="Previous Month">
                  <span class="material-icons" style="font-size: 18px;">chevron_left</span>
                </button>
                <div style="font-weight: 700; font-size: 13.5px; min-width: 140px; text-align: center; color: var(--text-primary); font-family: var(--font-heading);">
                  ${monthName}
                </div>
                <button class="btn-icon btn-icon-sm" id="budget-next-month" title="Next Month">
                  <span class="material-icons" style="font-size: 18px;">chevron_right</span>
                </button>
              </div>

              ${!isCurrentMonth ? `
                <button class="btn-secondary btn-sm" id="budget-current-month-btn" style="padding: 7px 14px; font-size: 12.5px;" title="Jump to current month">
                  This Month
                </button>
              ` : ''}

              <button class="btn-primary" id="budget-set-all-btn">
                <span class="material-icons" style="font-size: 18px;">tune</span> Adjust Budgets
              </button>
            </div>
          </div>

          <!-- Timeline Quick-Jump Strip -->
          <div class="budget-timeline-strip">
            ${timelineMonths.map(m => `
              <button class="budget-timeline-chip ${m.isSelected ? 'active' : ''}" data-year="${m.year}" data-month="${m.month}">
                <span>${m.label}</span>
                ${m.isCurrent ? `<span class="timeline-current-pill">Live</span>` : ''}
              </button>
            `).join('')}
          </div>

          <!-- Top Budget Summary KPI Cards -->
          <div class="kpi-grid" style="margin-top: 18px;">
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Monthly Budget Pool</span>
                <div class="kpi-icon-box" style="background: var(--success-bg); color: var(--success);">
                  <span class="material-icons" style="font-size: 20px;">account_balance_wallet</span>
                </div>
              </div>
              <div class="kpi-value">${Formatters.currency(stats.totalBudget)}</div>
              <div class="kpi-footer">
                <span class="kpi-badge ${stats.percentUsed > 100 ? 'negative' : 'positive'}">
                  ${stats.percentUsed.toFixed(0)}% Allocated
                </span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Total Spent in Period</span>
                <div class="kpi-icon-box" style="background: var(--error-bg); color: var(--error);">
                  <span class="material-icons" style="font-size: 20px;">shopping_bag</span>
                </div>
              </div>
              <div class="kpi-value" style="color: ${stats.totalSpent > stats.totalBudget ? 'var(--error)' : 'var(--text-primary)'};">
                ${Formatters.currency(stats.totalSpent)}
              </div>
              <div class="kpi-footer">
                <span>${isCurrentMonth ? 'In current monthly cycle' : (isPastMonth ? 'Final closed cycle spend' : 'Planned cycle spend')}</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Remaining Margin</span>
                <div class="kpi-icon-box" style="background: ${stats.totalRemaining >= 0 ? 'var(--secondary-glow)' : 'var(--error-bg)'}; color: ${stats.totalRemaining >= 0 ? 'var(--secondary)' : 'var(--error)'};">
                  <span class="material-icons" style="font-size: 20px;">savings</span>
                </div>
              </div>
              <div class="kpi-value" style="color: ${stats.totalRemaining >= 0 ? 'var(--secondary)' : 'var(--error)'};">
                ${Formatters.currency(stats.totalRemaining)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge ${stats.totalRemaining >= 0 ? 'positive' : 'negative'}">
                  ${stats.daysLabel}
                </span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Daily Safe Allowance</span>
                <div class="kpi-icon-box" style="background: var(--indigo-glow); color: var(--indigo);">
                  <span class="material-icons" style="font-size: 20px;">today</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--text-primary);">
                ${Formatters.currency(stats.dailyAllowance)}
              </div>
              <div class="kpi-footer">
                <span>${isCurrentMonth ? 'Per day for remainder of month' : (isPastMonth ? 'Cycle completed' : 'Target daily allowance')}</span>
              </div>
            </div>
          </div>
        </section>

        <!-- Smart Budget Recommendations Banner (if any) -->
        ${suggestionEntries.length > 0 ? `
          <div class="fintech-card" style="background: var(--bg-surface-subtle); border-color: var(--glass-border-hover);">
            <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
              <span class="material-icons" style="color: var(--secondary); font-size: 22px;">tips_and_updates</span>
              <span style="font-weight: 700; font-size: 16px; color: var(--text-primary);">Smart Budget Recommendations (3-Month Prior Average)</span>
            </div>
            <div style="display: flex; flex-wrap: wrap; gap: 12px;">
              ${suggestionEntries.slice(0, 4).map(([catName, avg]) => {
                const cat = state.categories.find(c => c.name === catName);
                const currentBudget = Number(cat ? (cat.monthly_budget || cat.monthlyBudget || 0) : 0);
                if (currentBudget === avg) return '';
                return `
                  <div style="background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); padding: 8px 14px; border-radius: var(--radius-md); display: flex; align-items: center; gap: 12px;">
                    <span style="font-size: 13px; color: var(--text-secondary);">Set <b>${catName}</b> to <b>${Formatters.currency(avg)}</b></span>
                    <button class="btn-primary apply-suggestion-btn" 
                            style="padding: 4px 12px; font-size: 12px;"
                            data-cat-sync-id="${cat ? (cat.sync_id || '') : ''}"
                            data-cat-local-id="${cat ? (cat.id || '') : ''}"
                            data-amount="${avg}">
                      Apply
                    </button>
                  </div>
                `;
              }).filter(Boolean).join('')}
            </div>
          </div>
        ` : ''}

        <!-- Category Budgets Grid -->
        <div>
          <div class="card-header" style="margin-bottom: 16px;">
            <div class="card-title">
              <span class="material-icons">category</span>
              <span>Category Budget Limits (${stats.categoryStats.length})</span>
            </div>
          </div>

          ${stats.categoryStats.length === 0 ? `
            <div class="fintech-card" style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
              <div style="width: 56px; height: 56px; border-radius: 50%; background: var(--bg-surface-subtle); border: 1px solid var(--glass-border); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
                <span class="material-icons" style="font-size: 28px; opacity: 0.5;">pie_chart_outline</span>
              </div>
              <div style="font-size: 16px; font-weight: 600; color: var(--text-primary); margin-bottom: 6px;">No category budgets assigned yet</div>
              <div style="font-size: 13px; margin-bottom: 20px;">Assign target caps to expense categories to start monitoring pacing.</div>
              <button class="btn-primary" id="budget-empty-set-btn" style="width: auto;">
                <span class="material-icons" style="font-size: 16px;">tune</span> Set Category Budgets
              </button>
            </div>
          ` : `
            <div class="budget-grid">
              ${stats.categoryStats.map(item => {
                const progressClass = item.percentUsed > 100 ? 'danger' : item.percentUsed > 80 ? 'warning' : 'safe';
                const remainingAmount = item.budget - item.spent;
                return `
                  <div class="budget-card">
                    <div class="budget-card-header">
                      <div class="budget-cat-name">
                        <div class="tx-icon-box" style="width: 38px; height: 38px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border); color: var(--primary);">
                          <span class="material-icons" style="font-size: 20px;">${IconHelper.getMaterialIcon(item.icon)}</span>
                        </div>
                        <span>${item.name}</span>
                      </div>
                      <span class="kpi-badge ${item.percentUsed > 100 ? 'negative' : item.percentUsed > 80 ? 'neutral' : 'positive'}">
                        ${item.percentUsed.toFixed(0)}%
                      </span>
                    </div>

                    <div style="display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 4px;">
                      <span style="color: var(--text-muted);">Spent: <b style="color: var(--text-primary);">${Formatters.currency(item.spent)}</b></span>
                      <span style="color: var(--text-muted);">Cap: <b style="color: var(--text-primary);">${Formatters.currency(item.budget)}</b></span>
                    </div>

                    <div class="progress-track">
                      <div class="progress-bar-fill ${progressClass}" style="width: ${Math.min(100, item.percentUsed)}%;"></div>
                    </div>

                    <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 10px; font-size: 12px;">
                      <span style="color: ${remainingAmount >= 0 ? 'var(--text-secondary)' : 'var(--error)'};">
                        ${item.spent === 0 ? `${Formatters.currency(item.budget)} available` : (remainingAmount >= 0 ? `${Formatters.currency(remainingAmount)} remaining` : `${Formatters.currency(item.spent - item.budget)} over cap`)}
                      </span>
                      <button class="btn-ghost edit-single-budget-btn" 
                              data-cat-sync-id="${item.sync_id || ''}" 
                              data-cat-local-id="${item.id || ''}"
                              data-cat-name="${item.name}"
                              data-current-budget="${item.budget}">
                        Edit
                      </button>
                    </div>
                  </div>
                `;
              }).join('')}
            </div>
          `}
        </div>
      </div>
    `;
  },

  calculateBudgetStats(state) {
    const targetDate = this.currentDate || new Date();
    const year = targetDate.getFullYear();
    const month = targetDate.getMonth();
    const start = new Date(year, month, 1, 0, 0, 0, 0);
    const end = new Date(year, month + 1, 0, 23, 59, 59, 999);

    const now = new Date();
    const isCurrentMonth = year === now.getFullYear() && month === now.getMonth();
    const isPastMonth = year < now.getFullYear() || (year === now.getFullYear() && month < now.getMonth());
    const isFutureMonth = year > now.getFullYear() || (year === now.getFullYear() && month > now.getMonth());

    const expenses = (state.transactions || []).filter(t => {
      const ts = new Date(t.timestamp);
      return t.type === 'expense' && !t.goal_id && !t.goalId && ts >= start && ts <= end;
    });

    const categorySpending = {};
    for (const tx of expenses) {
      const cat = findCategory(state.categories, tx.categoryId || tx.category_id);
      const key = cat ? (cat.id || cat.sync_id || cat.name) : (tx.categoryId || 'other');
      categorySpending[key] = (categorySpending[key] || 0) + tx.amount;
      if (cat && cat.name) {
        categorySpending[cat.name] = (categorySpending[cat.name] || 0) + tx.amount;
      }
    }

    const categoryStats = [];
    let totalBudget = 0;
    let totalSpent = 0;

    // Deduplicate categories by name + type
    const uniqueCategories = [];
    const seen = new Set();
    for (const c of (state.categories || [])) {
      const key = `${(c.name || '').trim().toLowerCase()}_${(c.type || 'expense').toLowerCase()}`;
      if (!seen.has(key)) {
        seen.add(key);
        uniqueCategories.push(c);
      }
    }

    for (const cat of uniqueCategories) {
      const budget = Number(cat.monthly_budget || cat.monthlyBudget || 0);
      if (budget > 0) {
        const spent = categorySpending[cat.id] || categorySpending[cat.sync_id] || categorySpending[cat.name] || 0;
        
        categoryStats.push({
          id: cat.id,
          sync_id: cat.sync_id,
          name: cat.name,
          icon: cat.icon,
          budget: budget,
          spent,
          percentUsed: (spent / budget) * 100
        });

        totalBudget += budget;
        totalSpent += spent;
      }
    }

    categoryStats.sort((a, b) => b.percentUsed - a.percentUsed);

    const totalRemaining = totalBudget - totalSpent;
    const daysInMonth = new Date(year, month + 1, 0).getDate();

    let daysRemaining = 0;
    let daysLabel = '';
    let dailyAllowance = 0;

    if (isCurrentMonth) {
      daysRemaining = Math.max(1, daysInMonth - now.getDate() + 1);
      daysLabel = `${daysRemaining} days left in cycle`;
      dailyAllowance = totalRemaining > 0 ? totalRemaining / daysRemaining : 0;
    } else if (isPastMonth) {
      daysRemaining = 0;
      daysLabel = 'Cycle completed';
      dailyAllowance = 0;
    } else {
      daysRemaining = daysInMonth;
      daysLabel = `${daysInMonth} days in period`;
      dailyAllowance = totalBudget > 0 ? totalBudget / daysInMonth : 0;
    }

    return {
      totalBudget,
      totalSpent,
      totalRemaining,
      percentUsed: totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0,
      dailyAllowance,
      daysRemaining,
      daysLabel,
      categoryStats
    };
  },

  calculateAverageCategorySpending(state) {
    const targetDate = this.currentDate || new Date();
    const targetYear = targetDate.getFullYear();
    const targetMonth = targetDate.getMonth();
    const threeMonthsAgo = new Date(targetYear, targetMonth - 3, 1);
    const targetMonthStart = new Date(targetYear, targetMonth, 1);

    const pastExpenses = (state.transactions || []).filter(t => {
      const ts = new Date(t.timestamp);
      return t.type === 'expense' && !t.goal_id && !t.goalId && ts >= threeMonthsAgo && ts < targetMonthStart;
    });

    const categorySpending = {};
    for (const tx of pastExpenses) {
      const cat = findCategory(state.categories, tx.categoryId || tx.category_id);
      if (cat) {
        categorySpending[cat.name] = (categorySpending[cat.name] || 0) + tx.amount;
      }
    }

    const suggestions = {};
    for (const catName in categorySpending) {
      const total = categorySpending[catName];
      const avg = Math.round((total / 3) / 100) * 100;
      if (avg > 0) suggestions[catName] = avg;
    }

    return suggestions;
  },

  bindEvents(state) {
    // Prev Month
    document.getElementById('budget-prev-month')?.addEventListener('click', () => {
      const cur = this.currentDate || new Date();
      this.currentDate = new Date(cur.getFullYear(), cur.getMonth() - 1, 1);
      StateManager.notify();
    });

    // Next Month
    document.getElementById('budget-next-month')?.addEventListener('click', () => {
      const cur = this.currentDate || new Date();
      this.currentDate = new Date(cur.getFullYear(), cur.getMonth() + 1, 1);
      StateManager.notify();
    });

    // Reset to This Month
    document.getElementById('budget-current-month-btn')?.addEventListener('click', () => {
      this.currentDate = new Date();
      StateManager.notify();
    });

    // Timeline Chip clicks
    const timelineChips = document.querySelectorAll('.budget-timeline-chip[data-year][data-month]');
    timelineChips.forEach(chip => {
      chip.addEventListener('click', () => {
        const y = parseInt(chip.getAttribute('data-year'), 10);
        const m = parseInt(chip.getAttribute('data-month'), 10);
        this.currentDate = new Date(y, m, 1);
        StateManager.notify();
      });
    });

    // Open All Category Budgets Modal
    const openSetModal = () => this.showAdjustBudgetsModal(state);
    document.getElementById('budget-set-all-btn')?.addEventListener('click', openSetModal);
    document.getElementById('budget-empty-set-btn')?.addEventListener('click', openSetModal);

    // Apply suggestion button
    const applyBtns = document.querySelectorAll('.apply-suggestion-btn');
    applyBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        const syncId = btn.getAttribute('data-cat-sync-id');
        const localId = btn.getAttribute('data-cat-local-id');
        const amount = parseFloat(btn.getAttribute('data-amount')) || 0;
        await DbService.updateCategoryBudget(syncId, localId, amount);
      });
    });

    // Edit single category budget button
    const editBtns = document.querySelectorAll('.edit-single-budget-btn');
    editBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const syncId = btn.getAttribute('data-cat-sync-id');
        const localId = btn.getAttribute('data-cat-local-id');
        const name = btn.getAttribute('data-cat-name');
        const current = parseFloat(btn.getAttribute('data-current-budget')) || 0;
        this.showSingleBudgetModal(syncId, localId, name, current);
      });
    });
  },

  showSingleBudgetModal(syncId, localId, name, currentBudget) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 440px; padding: 28px 24px;">
        <div class="modal-header" style="margin-bottom: 20px;">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">tune</span>
            <span>Edit ${name} Budget</span>
          </div>
          <button class="modal-close-btn" id="modal-close-single-budget" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div class="form-group" style="margin-bottom: 20px;">
          <label class="form-label" style="margin-bottom: 8px;">Monthly Budget Cap (₹)</label>
          <div style="display: flex; align-items: center; gap: 8px;">
            <button type="button" class="btn-icon" id="single-budget-minus" title="Decrease by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">remove</span>
            </button>
            <div style="position: relative; display: flex; align-items: center; flex: 1;">
              <span style="position: absolute; left: 14px; font-weight: 700; font-size: 16px; color: var(--text-muted);">₹</span>
              <input type="number" step="500" min="0" class="form-control" id="single-budget-input" 
                     value="${currentBudget}" 
                     style="padding-left: 32px; font-size: 18px; font-weight: 700; text-align: right;" autofocus>
            </div>
            <button type="button" class="btn-icon" id="single-budget-plus" title="Increase by ₹500" style="width: 42px; height: 42px;">
              <span class="material-icons">add</span>
            </button>
          </div>
        </div>

        <!-- Quick Adjustment Increment Chips -->
        <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 24px;">
          ${[500, 1000, 2500, 5000, 10000, 20000].map(val => `
            <button type="button" class="filter-chip quick-preset-chip" data-val="${val}" style="padding: 6px 10px; font-size: 11.5px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border);">
              +₹${val.toLocaleString()}
            </button>
          `).join('')}
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; padding-top: 16px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="modal-cancel-single-budget" style="width: auto;">Cancel</button>
          <button class="btn-primary" id="modal-save-single-budget" style="width: auto;">Save Cap</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
    const input = overlay.querySelector('#single-budget-input');

    overlay.querySelector('#single-budget-minus')?.addEventListener('click', () => {
      const cur = parseFloat(input.value) || 0;
      input.value = Math.max(0, cur - 500);
    });

    overlay.querySelector('#single-budget-plus')?.addEventListener('click', () => {
      const cur = parseFloat(input.value) || 0;
      input.value = cur + 500;
    });

    overlay.querySelectorAll('.quick-preset-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const delta = parseFloat(chip.getAttribute('data-val')) || 0;
        const cur = parseFloat(input.value) || 0;
        input.value = cur + delta;
      });
    });

    const closeModal = () => {
      if (document.body.contains(overlay)) document.body.removeChild(overlay);
    };

    overlay.querySelector('#modal-close-single-budget')?.addEventListener('click', closeModal);
    overlay.querySelector('#modal-cancel-single-budget')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    overlay.querySelector('#modal-save-single-budget')?.addEventListener('click', async () => {
      const val = parseFloat(input.value) || 0;
      await DbService.updateCategoryBudget(syncId, localId, val);
      closeModal();
      StateManager.notify();
    });
  },

  showAdjustBudgetsModal(state) {
    const rawExpenseCats = state.categories.filter(c => c.type === 'expense');
    const expenseCats = [];
    const seen = new Set();
    for (const c of rawExpenseCats) {
      const nameKey = (c.name || '').trim().toLowerCase();
      if (!seen.has(nameKey)) {
        seen.add(nameKey);
        expenseCats.push(c);
      }
    }

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modern-modal-dialog animate-scale-up" style="max-width: 540px;">
        <div class="modal-header">
          <div class="modal-title">
            <span class="material-icons" style="color: var(--primary);">tune</span>
            <span>Category Budget Caps</span>
          </div>
          <button class="modal-close-btn" id="modal-close-budgets" aria-label="Close">
            <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 10px; max-height: 55vh; overflow-y: auto; padding-right: 4px;">
          ${expenseCats.map(cat => {
            const budgetVal = Number(cat.monthly_budget || cat.monthlyBudget || 0);
            return `
              <div style="display: flex; align-items: center; justify-content: space-between; background: var(--bg-surface-elevated); padding: 10px 14px; border-radius: var(--radius-md); border: 1px solid var(--glass-border); gap: 12px;">
                <div style="display: flex; align-items: center; gap: 10px; min-width: 0; flex: 1;">
                  <div class="tx-icon-box" style="width: 32px; height: 32px; border-radius: 6px;">
                    <span class="material-icons" style="font-size: 18px;">${IconHelper.getMaterialIcon(cat.icon)}</span>
                  </div>
                  <span style="font-weight: 600; font-size: 13.5px; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${cat.name}</span>
                </div>

                <!-- Stepper Buttons & 500 Step Input -->
                <div style="display: flex; align-items: center; gap: 4px;">
                  <button type="button" class="btn-icon btn-icon-sm budget-step-btn" data-step="-500" title="Decrease by ₹500" style="width: 28px; height: 28px;">
                    <span class="material-icons" style="font-size: 16px;">remove</span>
                  </button>
                  <div style="position: relative; display: flex; align-items: center; width: 110px;">
                    <span style="position: absolute; left: 8px; font-weight: 700; font-size: 12px; color: var(--text-muted);">₹</span>
                    <input type="number" step="500" min="0" class="form-control budget-modal-input" 
                           data-cat-sync-id="${cat.sync_id || ''}" 
                           data-cat-local-id="${cat.id || ''}"
                           value="${budgetVal}" 
                           style="padding: 5px 8px 5px 20px; font-weight: 700; font-size: 13px; text-align: right; width: 100%;">
                  </div>
                  <button type="button" class="btn-icon btn-icon-sm budget-step-btn" data-step="500" title="Increase by ₹500" style="width: 28px; height: 28px;">
                    <span class="material-icons" style="font-size: 16px;">add</span>
                  </button>
                </div>
              </div>
            `;
          }).join('')}
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 16px; border-top: 1px solid var(--glass-border);">
          <button class="btn-secondary" id="modal-cancel-budgets" style="width: auto;">Cancel</button>
          <button class="btn-primary" id="modal-save-budgets" style="width: auto;">Save All Changes</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    // Stepper buttons listener
    overlay.querySelectorAll('.budget-step-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const step = parseInt(btn.getAttribute('data-step'), 10);
        const row = btn.closest('div');
        const input = row?.querySelector('.budget-modal-input');
        if (input) {
          const current = parseFloat(input.value) || 0;
          input.value = Math.max(0, current + step);
        }
      });
    });

    const closeModal = () => {
      if (document.body.contains(overlay)) document.body.removeChild(overlay);
    };

    document.getElementById('modal-close-budgets')?.addEventListener('click', closeModal);
    document.getElementById('modal-cancel-budgets')?.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    document.getElementById('modal-save-budgets')?.addEventListener('click', async () => {
      const inputs = overlay.querySelectorAll('.budget-modal-input');
      for (const input of inputs) {
        const syncId = input.getAttribute('data-cat-sync-id');
        const localId = input.getAttribute('data-cat-local-id');
        const val = parseFloat(input.value) || 0;
        await DbService.updateCategoryBudget(syncId, localId, val);
      }
      closeModal();
      StateManager.notify();
    });
  }
};
