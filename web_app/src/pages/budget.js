/* Modern Budget Planning & Allocations Module */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { DateRangeHelper } from '../utils/date-range.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';

export const BudgetPage = {
  render(state) {
    const stats = this.calculateBudgetStats(state);
    const suggestions = this.calculateAverageCategorySpending(state);
    const suggestionEntries = Object.entries(suggestions);

    return `
      <div class="animate-fade-in" style="display: flex; flex-direction: column; gap: 28px;">
        
        <!-- Hero Header -->
        <section class="hero-section" style="padding-bottom: 0;">
          <div class="hero-header">
            <div>
              <h1 class="hero-welcome-title">Budget & Allocations</h1>
              <p class="hero-subtitle">Set category thresholds, track utilization burn rates, and receive automated pacing suggestions.</p>
            </div>
            
            <button class="btn-primary" id="budget-set-all-btn">
              <span class="material-icons" style="font-size: 18px;">tune</span> Adjust Budgets
            </button>
          </div>

          <!-- Top Budget Summary KPI Cards -->
          <div class="kpi-grid">
            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Monthly Budget Pool</span>
                <div class="kpi-icon-box" style="background: rgba(16, 185, 129, 0.12); color: var(--primary);">
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
                <span class="kpi-label">Total Spent to Date</span>
                <div class="kpi-icon-box" style="background: rgba(244, 63, 94, 0.12); color: var(--error);">
                  <span class="material-icons" style="font-size: 20px;">shopping_bag</span>
                </div>
              </div>
              <div class="kpi-value" style="color: ${stats.totalSpent > stats.totalBudget ? 'var(--error)' : 'var(--text-primary)'};">
                ${Formatters.currency(stats.totalSpent)}
              </div>
              <div class="kpi-footer">
                <span>In current monthly cycle</span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Remaining Margin</span>
                <div class="kpi-icon-box" style="background: ${stats.totalRemaining >= 0 ? 'rgba(56, 189, 248, 0.12)' : 'rgba(244, 63, 94, 0.12)'}; color: ${stats.totalRemaining >= 0 ? 'var(--secondary)' : 'var(--error)'};">
                  <span class="material-icons" style="font-size: 20px;">savings</span>
                </div>
              </div>
              <div class="kpi-value" style="color: ${stats.totalRemaining >= 0 ? 'var(--secondary)' : 'var(--error)'};">
                ${Formatters.currency(stats.totalRemaining)}
              </div>
              <div class="kpi-footer">
                <span class="kpi-badge ${stats.totalRemaining >= 0 ? 'positive' : 'negative'}">
                  ${stats.daysRemaining} days left in cycle
                </span>
              </div>
            </div>

            <div class="kpi-card">
              <div class="kpi-top">
                <span class="kpi-label">Daily Safe Allowance</span>
                <div class="kpi-icon-box" style="background: rgba(99, 102, 241, 0.12); color: var(--indigo);">
                  <span class="material-icons" style="font-size: 20px;">today</span>
                </div>
              </div>
              <div class="kpi-value" style="color: var(--text-primary);">
                ${Formatters.currency(stats.dailyAllowance)}
              </div>
              <div class="kpi-footer">
                <span>Per day for remainder of month</span>
              </div>
            </div>
          </div>
        </section>

        <!-- Smart Budget Recommendations Banner (if any) -->
        ${suggestionEntries.length > 0 ? `
          <div class="fintech-card" style="background: linear-gradient(135deg, rgba(56, 189, 248, 0.08) 0%, rgba(99, 102, 241, 0.04) 100%); border-color: rgba(56, 189, 248, 0.25);">
            <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
              <span class="material-icons" style="color: var(--secondary); font-size: 22px;">tips_and_updates</span>
              <span style="font-weight: 700; font-size: 16px; color: var(--text-primary);">Smart Budget Recommendations (3-Month Rolling Average)</span>
            </div>
            <div style="display: flex; flex-wrap: wrap; gap: 12px;">
              ${suggestionEntries.slice(0, 4).map(([catName, avg]) => {
                const cat = state.categories.find(c => c.name === catName);
                const currentBudget = Number(cat ? (cat.monthly_budget || cat.monthlyBudget || 0) : 0);
                if (currentBudget === avg) return '';
                return `
                  <div style="background: rgba(255,255,255,0.05); border: 1px solid var(--glass-border); padding: 8px 14px; border-radius: var(--radius-md); display: flex; align-items: center; gap: 12px;">
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
              <span>Category Budget Limits</span>
            </div>
          </div>

          ${stats.categoryStats.length === 0 ? `
            <div class="fintech-card" style="text-align: center; padding: 60px 20px; color: var(--text-muted);">
              <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px;">
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
                return `
                  <div class="budget-card">
                    <div class="budget-card-header">
                      <div class="budget-cat-name">
                        <div class="tx-icon-box" style="width: 36px; height: 36px; background: rgba(255,255,255,0.05); color: var(--primary);">
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
                      <span style="color: ${item.budget - item.spent >= 0 ? 'var(--text-secondary)' : 'var(--error)'};">
                        ${item.budget - item.spent >= 0 ? `${Formatters.currency(item.budget - item.spent)} remaining` : `${Formatters.currency(item.spent - item.budget)} over cap`}
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
    const range = DateRangeHelper.getDateRange('thisMonth');
    const expenses = state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return t.type === 'expense' && !t.goal_id && !t.goalId && ts >= range.start && ts <= range.end;
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
    const daysRemaining = Math.max(1, Formatters.daysRemainingInMonth());
    const dailyAllowance = totalRemaining > 0 ? totalRemaining / daysRemaining : 0;

    return {
      totalBudget,
      totalSpent,
      totalRemaining,
      percentUsed: totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0,
      dailyAllowance,
      daysRemaining,
      categoryStats
    };
  },

  calculateAverageCategorySpending(state) {
    const now = new Date();
    const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, 1);
    const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const pastExpenses = state.transactions.filter(t => {
      const ts = new Date(t.timestamp);
      return t.type === 'expense' && !t.goal_id && !t.goalId && ts >= threeMonthsAgo && ts < currentMonthStart;
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

        <!-- Quick Adjustment Preset Chips -->
        <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 24px;">
          ${[1000, 2500, 5000, 10000, 20000].map(val => `
            <button type="button" class="filter-chip quick-preset-chip" data-val="${val}" style="padding: 6px 10px; font-size: 11.5px; border-radius: var(--radius-sm); background: var(--bg-surface-elevated); border: 1px solid var(--glass-border);">
              ₹${val.toLocaleString()}
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
        input.value = chip.getAttribute('data-val');
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
