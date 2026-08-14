/* Budget Screen Module (Category budgets, utilization bars, suggestions and adjustments) */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { DateRangeHelper } from '../utils/date-range.js';
import { Formatters } from '../utils/formatters.js';
import { IconHelper, findCategory } from '../utils/icons.js';

export const BudgetPage = {
  render(state) {
    const stats = this.calculateBudgetStats(state);
    
    return `
      <div class="animate-fade-in" style="display:flex; flex-wrap:wrap; gap:24px; align-items:flex-start;">
        
        <!-- Left Column: Summary & Suggestions -->
        <div style="flex: 1 1 360px; max-width: 100%; display:flex; flex-direction:column; gap:24px; min-width:0;">
          
          <!-- Budget Stats Summary Card -->
          <div class="glass-card balance-container" style="margin:0;">
            <div class="balance-title">Monthly Budget Pool</div>
            <div class="balance-value" style="color: ${stats.totalRemaining >= 0 ? 'var(--text-primary)' : 'var(--error)'}; font-size:32px;">
              ${Formatters.currency(stats.totalBudget)}
            </div>
            
            <div style="margin-top: 16px;">
              <div style="display:flex; justify-content:space-between; font-size:13px; color:var(--text-secondary); margin-bottom: 8px;">
                <span>Spent ${Formatters.currency(stats.totalSpent)}</span>
                <span>${stats.percentUsed.toFixed(0)}% Used</span>
              </div>
              <div class="progress-container" style="height: 6px;">
                <div class="progress-bar" style="width: ${stats.percentUsed}%; background: ${stats.percentUsed >= 100 ? 'var(--error)' : 'var(--primary)'};"></div>
              </div>
            </div>

            <div class="balance-stats-row" style="margin-top:24px;">
              <div class="balance-stat-item">
                <div class="balance-stat-label">Remaining</div>
                <div class="balance-stat-val" style="color: ${stats.totalRemaining >= 0 ? 'var(--success)' : 'var(--error)'}; font-size:16px;">
                  ${Formatters.currency(stats.totalRemaining)}
                </div>
              </div>
              <div class="balance-stat-item" style="text-align: right;">
                <div class="balance-stat-label">Daily Allowance</div>
                <div class="balance-stat-val" style="font-size:16px;">${Formatters.currency(stats.dailyAllowance)}/day</div>
              </div>
            </div>
          </div>

          <!-- Suggestions Banner if any exist -->
          ${this.renderBudgetSuggestions(state)}

        </div>

        <!-- Right Column: Category Budgets list -->
        <div style="flex: 1 1 500px; display:flex; flex-direction:column; gap:16px; min-width:0;">
          <div class="transaction-list-header" style="margin:0;">
            <h3 class="transaction-list-title" style="font-size:18px;">Category Budgets</h3>
            <button class="btn btn-outline" id="budget-edit-limits-btn" style="width:auto; padding: 6px 12px; font-size:12px;">
              <span class="material-icons" style="font-size:16px;">edit</span>
              Adjust Budgets
            </button>
          </div>

          <div class="glass-card" style="padding: 10px 20px; min-height:400px;">
            ${stats.categoryStats.length === 0 ? `
              <div style="text-align: center; padding: 60px 0; color: var(--text-muted); font-size: 14px;">
                <span class="material-icons" style="font-size: 48px; opacity:0.3; margin-bottom:12px;">account_balance_wallet</span><br>
                No category budgets set.<br>Click "Adjust Budgets" to configure.
              </div>
            ` : stats.categoryStats.map(cat => this.renderCategoryBudgetRow(cat)).join('')}
          </div>
        </div>

      </div>
    `;
  },

  renderCategoryBudgetRow(cat) {
    const isOver = cat.spent > cat.budget;
    const isNear = cat.percentUsed >= 80 && !isOver;
    const barColor = isOver ? 'var(--error)' : isNear ? 'var(--warning)' : 'var(--primary)';
    
    return `
      <div class="budget-category-row">
        <div class="budget-cat-info">
          <div class="budget-cat-name">
            <span class="material-icons" style="font-size:18px; color:var(--text-muted);">${IconHelper.getMaterialIcon(cat.icon)}</span>
            <span>${cat.name}</span>
          </div>
          <div style="color: ${isOver ? 'var(--error)' : 'var(--text-primary)'}">
            ${Formatters.currency(cat.spent)} / <span style="color:var(--text-muted);">${Formatters.currency(cat.budget)}</span>
          </div>
        </div>
        <div class="progress-container">
          <div class="progress-bar" style="width: ${cat.percentUsed}%; background: ${barColor};"></div>
        </div>
        <div class="budget-cat-progress">
          <span>${cat.percentUsed.toFixed(0)}% used</span>
          ${isOver ? `
            <span class="budget-overrun">Over budget by ${Formatters.currency(cat.spent - cat.budget)}</span>
          ` : `
            <span>${Formatters.currency(cat.budget - cat.spent)} remaining</span>
          `}
        </div>
      </div>
    `;
  },

  renderBudgetSuggestions(state) {
    const avgSpending = this.calculateAverageCategorySpending(state);
    const suggestionEntries = Object.entries(avgSpending).filter(([_, avg]) => avg > 0).slice(0, 2);

    if (suggestionEntries.length === 0) return '';

    return `
      <div class="glass-card" style="background: rgba(0, 198, 255, 0.05); border-color: rgba(0, 198, 255, 0.15);">
        <div style="display:flex; align-items:center; gap:8px; color:var(--secondary); font-size:14px; font-weight:600; margin-bottom:8px;">
          <span class="material-icons" style="font-size:18px;">tips_and_updates</span>
          Smart Budget Recommendations
        </div>
        <div style="font-size:12px; color:var(--text-secondary); line-height:1.5; display:flex; flex-direction:column; gap:6px;">
          ${suggestionEntries.map(([catName, avg]) => {
            const cat = state.categories.find(c => c.name === catName);
            const currentBudget = cat ? cat.monthly_budget : 0;
            if (currentBudget === avg) return '';
            return `
              <div style="display:flex; justify-content:space-between; align-items:center;">
                <span>Set budget for <b>${catName}</b> to ${Formatters.currency(avg)} (3-month avg)</span>
                <button class="btn btn-outline apply-suggestion-btn" 
                        style="width:auto; padding:4px 8px; font-size:11px; margin-left:12px;"
                        data-cat-sync-id="${cat ? cat.sync_id : ''}"
                        data-cat-local-id="${cat ? cat.id : ''}"
                        data-amount="${avg}">
                  Apply
                </button>
              </div>
            `;
          }).join('')}
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

    for (const cat of state.categories) {
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

    // Sort by percent used (highest first)
    categoryStats.sort((a, b) => b.percentUsed - a.percentUsed);

    const totalRemaining = totalBudget - totalSpent;
    const daysRemaining = Formatters.daysRemainingInMonth();
    const dailyAllowance = daysRemaining > 0 ? totalRemaining / daysRemaining : 0;

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

  // Calculate 3-month average category spending to suggest budgets
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
      const avg = total / 3;
      // Round to nearest 100
      suggestions[catName] = Math.round(avg / 100) * 100;
    }

    return suggestions;
  },

  bindEvents(state) {
    // Edit Limits button click
    const adjustBtn = document.getElementById('budget-edit-limits-btn');
    if (adjustBtn) {
      adjustBtn.addEventListener('click', () => {
        this.showAdjustBudgetsModal(state);
      });
    }

    // Apply suggestion buttons click
    const suggestionBtns = document.querySelectorAll('.apply-suggestion-btn');
    suggestionBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        const syncId = btn.getAttribute('data-cat-sync-id');
        const localId = parseInt(btn.getAttribute('data-cat-local-id'), 10) || null;
        const amount = parseFloat(btn.getAttribute('data-amount')) || 0;

        await DbService.updateCategoryBudget(syncId, localId, amount);
      });
    });
  },

  showAdjustBudgetsModal(state) {
    // Show overlay modal list of all expense categories and inputs to edit budget limits
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    
    const expenseCats = state.categories.filter(c => c.type === 'expense');

    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1E1E2C; max-height:85vh; display:flex; flex-direction:column; width:95%; max-width:440px; padding:24px 16px;">
        <div class="modal-header" style="margin-bottom:12px;">
          <h3 style="color:#FFF;">Adjust Category Budgets</h3>
          <button class="modal-close" id="adjust-modal-close">&times;</button>
        </div>
        <p style="color:var(--text-secondary); font-size:12px; margin-bottom:16px;">
          Set monthly spending limits for categories. Set to 0 to remove budget.
        </p>
        
        <div style="flex:1; overflow-y:auto; padding-right:8px; display:flex; flex-direction:column; gap:12px;" id="adjust-categories-list">
          ${expenseCats.map(cat => `
            <div style="display:flex; align-items:center; justify-content:space-between; gap:16px; border-bottom:1px solid var(--divider); padding-bottom:8px;">
              <div style="display:flex; align-items:center; gap:8px;">
                <span class="material-icons" style="color:var(--primary); font-size:20px;">${IconHelper.getMaterialIcon(cat.icon)}</span>
                <span style="font-size:14px; font-weight:600;">${cat.name}</span>
              </div>
              <div style="display:flex; align-items:center; max-width:120px;">
                <span style="color:var(--text-muted); margin-right:4px;">₹</span>
                <input type="number" class="form-input budget-input-field" 
                       style="padding:8px 12px; text-align:right;"
                       data-cat-sync-id="${cat.sync_id}"
                       data-cat-local-id="${cat.id || ''}"
                       value="${cat.monthly_budget || 0}">
              </div>
            </div>
          `).join('')}
        </div>
        
        <div style="display:flex; gap:12px; justify-content:flex-end; margin-top:20px; border-top:1px solid var(--divider); padding-top:12px;">
          <button class="btn btn-outline" id="adjust-cancel-btn" style="width:auto; padding:10px 20px;">Cancel</button>
          <button class="btn btn-primary" id="adjust-save-btn" style="width:auto; padding:10px 20px;">Save Changes</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      document.body.removeChild(overlay);
    };

    document.getElementById('adjust-modal-close').addEventListener('click', closeModal);
    document.getElementById('adjust-cancel-btn').addEventListener('click', closeModal);

    document.getElementById('adjust-save-btn').addEventListener('click', async () => {
      const inputs = overlay.querySelectorAll('.budget-input-field');
      const promises = [];

      inputs.forEach(input => {
        const syncId = input.getAttribute('data-cat-sync-id');
        const localId = parseInt(input.getAttribute('data-cat-local-id'), 10) || null;
        const value = parseFloat(input.value) || 0;
        
        promises.push(DbService.updateCategoryBudget(syncId, localId, value));
      });

      await Promise.all(promises);
      closeModal();
    });
  }
};
