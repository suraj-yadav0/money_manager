/* Modern Transaction Creation & Edit Slide-Up Modal Component */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { CategorizationEngine } from '../utils/categorization-engine.js';
import { IconHelper } from '../utils/icons.js';

export const AddTransactionModal = {
  activeTx: null,
  selectedType: 'expense',
  selectedCategoryId: null,
  paymentMode: 'Cash',
  autoSuggested: false,

  show(tx = null) {
    this.activeTx = tx;
    this.autoSuggested = false;

    if (tx) {
      this.selectedType = tx.type;
      this.selectedCategoryId = tx.categoryId || tx.category_id;
      this.paymentMode = tx.paymentMode || tx.payment_mode || 'Cash';
    } else {
      this.selectedType = 'expense';
      this.paymentMode = 'Cash';
      const defaultExpense = StateManager.state.categories.find(c => c.type === 'expense');
      this.selectedCategoryId = defaultExpense ? (defaultExpense.id || defaultExpense.sync_id) : null;
    }

    this.render();
    this.bindEvents();
  },

  render() {
    this.close();

    const state = StateManager.state;
    const categories = state.categories.filter(c => c.type === this.selectedType);
    const goals = state.goals.filter(g => g.is_active !== false && !g.is_completed);

    const isEdit = this.activeTx !== null;
    const amountVal = isEdit ? this.activeTx.amount : '';
    const noteVal = isEdit ? (this.activeTx.note || '') : '';
    
    let dateVal = new Date().toISOString().substring(0, 10);
    if (isEdit && this.activeTx.timestamp) {
      try {
        dateVal = new Date(this.activeTx.timestamp).toISOString().substring(0, 10);
      } catch (_) {}
    }

    const modalHtml = `
      <div class="modal-overlay active" id="tx-modal-overlay">
        <div class="modern-modal-dialog animate-scale-up" style="max-width: 520px;">
          <div class="modal-header">
            <div class="modal-title">
              <span class="material-icons" style="color: var(--primary);">${isEdit ? 'edit_note' : 'add_circle'}</span>
              <span>${isEdit ? 'Edit Transaction' : 'Record Transaction'}</span>
            </div>
            <button class="modal-close-btn" id="tx-modal-close-btn" aria-label="Close">
              <span class="material-icons" style="font-size: 20px; line-height: 1;">close</span>
            </button>
          </div>

          <!-- Type Toggle (Expense / Income) -->
          <div class="filter-group" style="margin-bottom: 20px; width: 100%; display: flex; padding: 4px;">
            <button class="filter-chip ${this.selectedType === 'expense' ? 'active' : ''}" id="tx-type-expense" style="flex: 1; text-align: center; padding: 8px 12px; font-size: 13px; font-weight: 600;">
              Expense
            </button>
            <button class="filter-chip ${this.selectedType === 'income' ? 'active' : ''}" id="tx-type-income" style="flex: 1; text-align: center; padding: 8px 12px; font-size: 13px; font-weight: 600;">
              Income
            </button>
          </div>

          <!-- Amount Input with Currency -->
          <div class="form-group" style="margin-bottom: 20px;">
            <label class="form-label">Transaction Amount</label>
            <div style="position: relative; display: flex; align-items: center;">
              <span style="position: absolute; left: 18px; font-size: 24px; font-weight: 700; color: var(--text-primary);">₹</span>
              <input type="number" step="any" class="form-control" id="tx-amount-input" 
                     placeholder="0.00" value="${amountVal}" 
                     style="padding-left: 44px; font-size: 26px; font-weight: 700; font-family: var(--font-heading);" autofocus>
            </div>
          </div>

          <!-- Note Input with Auto-Categorization -->
          <div class="form-group">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <label class="form-label">Note / Merchant</label>
              <span id="tx-category-suggestion-badge" style="font-size: 11px; font-weight: 700; color: var(--primary); display: none;">
                Auto-Matched
              </span>
            </div>
            <input type="text" class="form-control" id="tx-note-input" placeholder="e.g. Starbucks, Zomato, Rent, Salary" value="${noteVal}">
          </div>

          <!-- Category Selector Grid -->
          <div class="form-group">
            <label class="form-label">Select Category</label>
            <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; max-height: 140px; overflow-y: auto; padding-right: 4px;" id="tx-categories-grid">
              ${categories.map(cat => {
                const isSelected = String(cat.id) === String(this.selectedCategoryId) || (cat.sync_id && String(cat.sync_id) === String(this.selectedCategoryId));
                return `
                  <div class="category-select-pill" 
                       data-cat-id="${cat.id !== undefined ? cat.id : cat.sync_id}"
                       style="display: flex; align-items: center; gap: 8px; padding: 8px 10px; border-radius: var(--radius-md); background: ${isSelected ? 'var(--bg-surface-elevated)' : 'var(--bg-surface-subtle)'}; border: 1px solid ${isSelected ? 'var(--primary)' : 'var(--glass-border)'}; cursor: pointer; transition: var(--transition-fast);">
                    <span class="material-icons" style="font-size: 18px; color: ${isSelected ? 'var(--text-primary)' : 'var(--text-muted)'};">${IconHelper.getMaterialIcon(cat.icon)}</span>
                    <span style="font-size: 12px; font-weight: 600; color: ${isSelected ? 'var(--text-primary)' : 'var(--text-secondary)'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${cat.name}</span>
                  </div>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Date Input -->
          <div class="form-group">
            <label class="form-label">Date</label>
            <input type="date" class="form-control" id="tx-date-input" value="${dateVal}">
          </div>

          <!-- Payment Mode Pill Selector (Clean, 100% Reliable across Dark/Light) -->
          <div class="form-group">
            <label class="form-label">Payment Mode</label>
            <div style="display: flex; gap: 8px; flex-wrap: wrap;" id="tx-payment-mode-group">
              ${['Cash', 'UPI', 'Credit Card', 'Debit Card', 'Net Banking'].map(mode => {
                const isSelected = (this.paymentMode || 'Cash') === mode;
                return `
                  <button type="button" class="filter-chip payment-mode-pill ${isSelected ? 'active' : ''}" 
                          data-mode="${mode}" 
                          style="padding: 7px 14px; font-size: 12px; cursor: pointer; border-radius: var(--radius-sm);">
                    ${mode}
                  </button>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Additional Options (Goal link & Recurring) -->
          <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 10px; padding: 10px 14px; background: var(--bg-surface-subtle); border-radius: var(--radius-md); border: 1px solid var(--glass-border);">
            <label style="display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--text-secondary); cursor: pointer;">
              <input type="checkbox" id="tx-recurring-check" ${this.activeTx?.isRecurring ? 'checked' : ''}>
              <span>Recurring Monthly Transaction</span>
            </label>

            ${goals.length > 0 ? `
              <select class="form-control" id="tx-goal-link-select" style="width: auto; padding: 6px 32px 6px 10px; font-size: 12px;">
                <option value="">No Goal Linked</option>
                ${goals.map(g => `<option value="${g.id || g.sync_id}" ${String(this.activeTx?.goalId) === String(g.id || g.sync_id) ? 'selected' : ''}>${g.name}</option>`).join('')}
              </select>
            ` : ''}
          </div>

          <!-- Modal Action Buttons -->
          <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 24px; padding-top: 16px; border-top: 1px solid var(--glass-border);">
            ${isEdit ? `
              <button class="btn-ghost" id="tx-delete-btn" style="color: var(--error); padding: 8px 16px;">
                <span class="material-icons" style="font-size: 16px;">delete</span> Delete
              </button>
            ` : '<div></div>'}

            <div style="display: flex; gap: 12px;">
              <button class="btn-secondary" id="tx-cancel-btn" style="width: auto;">Cancel</button>
              <button class="btn-primary" id="tx-save-btn" style="width: auto;">
                ${isEdit ? 'Update Record' : 'Record Transaction'}
              </button>
            </div>
          </div>
        </div>
      </div>
    `;

    const div = document.createElement('div');
    div.id = 'add-tx-modal-container';
    div.innerHTML = modalHtml;
    document.body.appendChild(div);
  },

  bindEvents() {
    const overlay = document.getElementById('tx-modal-overlay');

    // Close buttons
    document.getElementById('tx-modal-close-btn')?.addEventListener('click', () => this.close());
    document.getElementById('tx-cancel-btn')?.addEventListener('click', () => this.close());
    overlay?.addEventListener('click', (e) => {
      if (e.target === overlay) this.close();
    });

    // Type Toggle
    document.getElementById('tx-type-expense')?.addEventListener('click', () => {
      this.selectedType = 'expense';
      const defaultExpense = StateManager.state.categories.find(c => c.type === 'expense');
      this.selectedCategoryId = defaultExpense ? (defaultExpense.id || defaultExpense.sync_id) : null;
      this.render();
      this.bindEvents();
    });

    document.getElementById('tx-type-income')?.addEventListener('click', () => {
      this.selectedType = 'income';
      const defaultIncome = StateManager.state.categories.find(c => c.type === 'income');
      this.selectedCategoryId = defaultIncome ? (defaultIncome.id || defaultIncome.sync_id) : null;
      this.render();
      this.bindEvents();
    });

    // Note Input with Auto-Categorization
    const noteInput = document.getElementById('tx-note-input');
    if (noteInput) {
      noteInput.addEventListener('input', (e) => {
        const note = e.target.value;
        const suggested = CategorizationEngine.suggestCategory(
          note,
          StateManager.state.categories.filter(c => c.type === this.selectedType),
          StateManager.state.categorizationRules
        );

        const badge = document.getElementById('tx-category-suggestion-badge');
        if (suggested) {
          this.selectedCategoryId = suggested.id || suggested.sync_id;
          this.autoSuggested = true;
          if (badge) {
            badge.textContent = `Matched: ${suggested.name}`;
            badge.style.display = 'block';
          }
          this.highlightSelectedCategory(this.selectedCategoryId);
        } else if (badge) {
          badge.style.display = 'none';
        }
      });
    }

    // Category Pill Clicks
    const catPills = document.querySelectorAll('.category-select-pill');
    catPills.forEach(pill => {
      pill.addEventListener('click', () => {
        const catId = pill.getAttribute('data-cat-id');
        this.selectedCategoryId = catId;
        this.autoSuggested = false;
        this.highlightSelectedCategory(catId);
      });
    });

    // Payment Mode Pill Clicks
    const modePills = document.querySelectorAll('.payment-mode-pill');
    modePills.forEach(pill => {
      pill.addEventListener('click', () => {
        this.paymentMode = pill.getAttribute('data-mode') || 'Cash';
        modePills.forEach(p => p.classList.toggle('active', p === pill));
      });
    });

    // Save Button
    document.getElementById('tx-save-btn')?.addEventListener('click', async () => {
      const amount = parseFloat(document.getElementById('tx-amount-input')?.value);
      const note = document.getElementById('tx-note-input')?.value.trim() || '';
      const date = document.getElementById('tx-date-input')?.value || new Date().toISOString();
      const paymentMode = this.paymentMode || 'Cash';
      const isRecurring = document.getElementById('tx-recurring-check')?.checked || false;
      const goalId = document.getElementById('tx-goal-link-select')?.value || null;

      if (isNaN(amount) || amount <= 0) {
        alert('Please enter a valid transaction amount.');
        return;
      }

      const cleanCatId = /^\d+$/.test(String(this.selectedCategoryId)) ? parseInt(this.selectedCategoryId, 10) : this.selectedCategoryId;
      const cleanGoalId = goalId ? (/^\d+$/.test(String(goalId)) ? parseInt(goalId, 10) : goalId) : null;

      const txPayload = {
        amount,
        type: this.selectedType,
        categoryId: cleanCatId,
        category_id: cleanCatId,
        timestamp: new Date(date).toISOString(),
        note,
        paymentMode,
        payment_mode: paymentMode,
        isRecurring,
        is_recurring: isRecurring,
        goalId: cleanGoalId,
        goal_id: cleanGoalId,
      };

      if (this.activeTx) {
        await DbService.addTransaction({
          ...txPayload,
          sync_id: this.activeTx.sync_id,
          id: this.activeTx.id
        });
      } else {
        await DbService.addTransaction(txPayload);
      }

      this.close();
    });

    // Delete Button
    document.getElementById('tx-delete-btn')?.addEventListener('click', async () => {
      if (!this.activeTx) return;
      if (confirm('Are you sure you want to delete this transaction?')) {
        await DbService.deleteTransaction(this.activeTx.sync_id, this.activeTx.id);
        this.close();
      }
    });
  },

  highlightSelectedCategory(selectedCatId) {
    const pills = document.querySelectorAll('.category-select-pill');
    pills.forEach(pill => {
      const catId = pill.getAttribute('data-cat-id');
      const isSelected = String(catId) === String(selectedCatId);
      pill.style.background = isSelected ? 'rgba(16, 185, 129, 0.15)' : 'rgba(255,255,255,0.03)';
      pill.style.borderColor = isSelected ? 'var(--primary)' : 'var(--glass-border)';
      const icon = pill.querySelector('.material-icons');
      if (icon) icon.style.color = isSelected ? 'var(--primary)' : 'var(--text-muted)';
      const text = pill.querySelector('span:last-child');
      if (text) text.style.color = isSelected ? 'var(--text-primary)' : 'var(--text-secondary)';
    });
  },

  close() {
    const el = document.getElementById('add-tx-modal-container');
    if (el) el.remove();
  }
};
