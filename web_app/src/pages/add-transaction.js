/* Add & Edit Transaction Slide-Up Modal Component with Auto-Categorization */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { CategorizationEngine } from '../utils/categorization-engine.js';
import { IconHelper } from '../utils/icons.js';

export const AddTransactionModal = {
  activeTx: null, // If set, we are editing this transaction
  selectedType: 'expense',
  selectedCategoryId: null,
  autoSuggested: false,

  show(tx = null) {
    this.activeTx = tx;
    this.autoSuggested = false;

    if (tx) {
      this.selectedType = tx.type;
      this.selectedCategoryId = tx.categoryId || tx.category_id;
    } else {
      this.selectedType = 'expense';
      // Pick first expense category by default
      const defaultExpense = StateManager.state.categories.find(c => c.type === 'expense');
      this.selectedCategoryId = defaultExpense ? (defaultExpense.id || defaultExpense.sync_id) : null;
    }

    this.render();
    this.bindEvents();
  },

  render() {
    // Remove existing modal if any exists
    this.close();

    const state = StateManager.state;
    const categories = state.categories.filter(c => c.type === this.selectedType);
    const goals = state.goals.filter(g => g.is_active !== false && !g.is_completed);

    const isEdit = this.activeTx !== null;
    const amountVal = isEdit ? this.activeTx.amount : '';
    const noteVal = isEdit ? (this.activeTx.note || '') : '';
    
    // Default date input value (YYYY-MM-DD)
    let dateVal = new Date().toISOString().substring(0, 10);
    if (isEdit && this.activeTx.timestamp) {
      dateVal = new Date(this.activeTx.timestamp).toISOString().substring(0, 10);
    }
    
    const paymentModeVal = isEdit ? (this.activeTx.paymentMode || this.activeTx.payment_mode || 'Cash') : 'Cash';
    const isRecur = isEdit ? (this.activeTx.isRecurring || this.activeTx.is_recurring === true) : false;
    const linkedGoalId = isEdit ? (this.activeTx.goalId || this.activeTx.goal_id) : '';

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.id = 'tx-modal-overlay';
    
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1E1E2C; max-height:92vh; display:flex; flex-direction:column; width:95%; max-width:440px; padding:24px 20px;">
        <div class="modal-header" style="margin-bottom:12px;">
          <h3 style="color:#FFF;">${isEdit ? 'Edit Transaction' : 'Add Transaction'}</h3>
          <button class="modal-close" id="tx-modal-close">&times;</button>
        </div>

        <div style="flex:1; overflow-y:auto; padding-right:4px; display:flex; flex-direction:column; gap:16px;" id="tx-modal-fields">
          <!-- Income / Expense Tab -->
          <div class="tab-bar">
            <button class="tab-button ${this.selectedType === 'expense' ? 'active' : ''}" id="tx-type-expense">Expense</button>
            <button class="tab-button ${this.selectedType === 'income' ? 'active' : ''}" id="tx-type-income">Income</button>
          </div>

          <!-- Amount Input -->
          <div class="form-group" style="margin-bottom: 8px;">
            <label class="form-label">Amount (₹)</label>
            <input type="number" class="onboarding-income-input" id="tx-amount-field" 
                   placeholder="0" value="${amountVal}" 
                   style="font-size:36px; padding:8px 0; text-align:left; border-bottom-color:var(--primary);">
          </div>

          <!-- Note Field (Triggers categorization engine) -->
          <div class="form-group">
            <label class="form-label">Note / Description</label>
            <div class="form-input-container">
              <span class="material-icons form-input-icon">description</span>
              <input type="text" class="form-input" id="tx-note-field" placeholder="zomato lunch, salary, uber, etc." value="${noteVal}">
            </div>
            <!-- Auto category suggestion status -->
            <div id="tx-suggest-badge" style="display:none; align-items:center; gap:4px; color:var(--secondary); font-size:11px; margin-top:6px; font-weight:600;">
              <span class="material-icons" style="font-size:14px;">insights</span>
              Auto-categorized category selected
            </div>
          </div>

          <!-- Category Grid Select -->
          <div class="form-group">
            <label class="form-label">Category</label>
            <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:10px; max-height:160px; overflow-y:auto; padding:4px;" id="tx-category-grid">
              ${categories.map(cat => {
                const catId = cat.id || cat.sync_id;
                const isSelected = catId == this.selectedCategoryId;
                return `
                  <div class="category-select-btn ${isSelected ? 'active' : ''}" 
                       data-cat-id="${catId}"
                       style="display:flex; flex-direction:column; align-items:center; justify-content:center; padding:10px; border-radius:12px; border:1px solid ${isSelected ? 'var(--primary)' : 'var(--glass-border)'}; background:${isSelected ? 'rgba(255,95,31,0.15)' : 'var(--glass-bg)'}; cursor:pointer; text-align:center; transition:var(--transition-fast);">
                    <span class="material-icons" style="font-size:22px; color:${isSelected ? 'var(--primary)' : 'var(--text-secondary)'}; margin-bottom:4px;">
                      ${IconHelper.getMaterialIcon(cat.icon)}
                    </span>
                    <span style="font-size:10px; font-weight:600; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; width:100%; color:${isSelected ? '#FFF' : 'var(--text-muted)'};">
                      ${cat.name}
                    </span>
                  </div>
                `;
              }).join('')}
            </div>
          </div>

          <!-- Date field -->
          <div class="form-group">
            <label class="form-label">Date & Time</label>
            <div class="form-input-container">
              <span class="material-icons form-input-icon">calendar_today</span>
              <input type="date" class="form-input" id="tx-date-field" value="${dateVal}" style="color-scheme:dark;">
            </div>
          </div>

          <!-- Payment Mode -->
          <div class="form-group">
            <label class="form-label">Payment Mode</label>
            <select class="form-input" id="tx-payment-field" style="background:var(--input-bg); color:#FFF; border:1px solid var(--input-border);">
              <option value="Cash" ${paymentModeVal === 'Cash' ? 'selected' : ''}>💵 Cash</option>
              <option value="UPI" ${paymentModeVal === 'UPI' ? 'selected' : ''}>📱 UPI (GPay/PhonePe)</option>
              <option value="Card" ${paymentModeVal === 'Card' ? 'selected' : ''}>💳 Debit/Credit Card</option>
              <option value="Bank Transfer" ${paymentModeVal === 'Bank Transfer' ? 'selected' : ''}>🏛️ Bank Transfer</option>
              <option value="Other" ${paymentModeVal === 'Other' ? 'selected' : ''}>📦 Other</option>
            </select>
          </div>

          <!-- Goals Link Selector (Only for expenses) -->
          <div class="form-group" id="tx-goal-group" style="display: ${this.selectedType === 'expense' ? 'block' : 'none'};">
            <label class="form-label">Link to Savings Goal</label>
            <select class="form-input" id="tx-goal-field" style="background:var(--input-bg); color:#FFF; border:1px solid var(--input-border);">
              <option value="">-- No Goal linked --</option>
              ${goals.map(g => `
                <option value="${g.id || g.sync_id}" ${linkedGoalId == (g.id || g.sync_id) ? 'selected' : ''}>
                  🎯 ${g.name}
                </option>
              `).join('')}
            </select>
          </div>

          <!-- Recurring checkbox -->
          <div style="display:flex; align-items:center; gap:8px;">
            <input type="checkbox" id="tx-recur-field" ${isRecur ? 'checked' : ''} style="width:18px; height:18px; cursor:pointer;">
            <label for="tx-recur-field" style="font-size:14px; color:var(--text-secondary); cursor:pointer;">Mark as Recurring (Monthly Template)</label>
          </div>
        </div>

        <div style="display:flex; gap:12px; justify-content:space-between; margin-top:20px; border-top:1px solid var(--divider); padding-top:12px;">
          ${isEdit ? `
            <button class="btn btn-danger" id="tx-delete-btn" style="width:auto; padding:10px 16px;">
              <span class="material-icons" style="font-size:18px;">delete</span>
            </button>
          ` : '<div></div>'}
          
          <div style="display:flex; gap:12px;">
            <button class="btn btn-outline" id="tx-cancel-btn" style="width:auto; padding:10px 20px;">Cancel</button>
            <button class="btn btn-primary" id="tx-save-btn" style="width:auto; padding:10px 20px;">Save</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
  },

  close() {
    const modal = document.getElementById('tx-modal-overlay');
    if (modal) {
      document.body.removeChild(modal);
    }
  },

  bindEvents() {
    const state = StateManager.state;
    
    // Close overlay click
    document.getElementById('tx-modal-close').addEventListener('click', () => this.close());
    document.getElementById('tx-cancel-btn').addEventListener('click', () => this.close());

    // Type Toggles
    document.getElementById('tx-type-expense').addEventListener('click', () => {
      this.selectedType = 'expense';
      const defaultExpense = state.categories.find(c => c.type === 'expense');
      this.selectedCategoryId = defaultExpense ? (defaultExpense.id || defaultExpense.sync_id) : null;
      this.render();
      this.bindEvents();
    });

    document.getElementById('tx-type-income').addEventListener('click', () => {
      this.selectedType = 'income';
      const defaultIncome = state.categories.find(c => c.type === 'income');
      this.selectedCategoryId = defaultIncome ? (defaultIncome.id || defaultIncome.sync_id) : null;
      this.render();
      this.bindEvents();
    });

    // Category Grid Item Clicks
    const catBtns = document.querySelectorAll('.category-select-btn');
    catBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        catBtns.forEach(b => {
          b.classList.remove('active');
          b.style.borderColor = 'var(--glass-border)';
          b.style.background = 'var(--glass-bg)';
        });
        
        btn.classList.add('active');
        btn.style.borderColor = 'var(--primary)';
        btn.style.background = 'rgba(255, 95, 31, 0.15)';
        
        const catId = btn.getAttribute('data-cat-id');
        this.selectedCategoryId = catId;
        this.autoSuggested = false; // user manual overwrite
        
        const badge = document.getElementById('tx-suggest-badge');
        if (badge) badge.style.display = 'none';
      });
    });

    // Auto Categorization note listener
    const noteField = document.getElementById('tx-note-field');
    noteField.addEventListener('input', (e) => {
      const text = e.target.value;
      const suggested = CategorizationEngine.suggestCategory(text, state.categories, state.categorizationRules);
      
      // We only suggest category if the user is typing a note and hasn't manually overridden yet
      if (suggested && suggested.type === this.selectedType) {
        const suggestedId = suggested.id || suggested.sync_id;
        
        if (this.selectedCategoryId != suggestedId) {
          this.selectedCategoryId = suggestedId;
          this.autoSuggested = true;
          
          // Re-render categories selection highlight without full re-render
          const btns = document.querySelectorAll('.category-select-btn');
          btns.forEach(btn => {
            const catId = btn.getAttribute('data-cat-id');
            if (catId == suggestedId) {
              btn.classList.add('active');
              btn.style.borderColor = 'var(--primary)';
              btn.style.background = 'rgba(255, 95, 31, 0.15)';
            } else {
              btn.classList.remove('active');
              btn.style.borderColor = 'var(--glass-border)';
              btn.style.background = 'var(--glass-bg)';
            }
          });

          const badge = document.getElementById('tx-suggest-badge');
          if (badge) badge.style.display = 'flex';
        }
      }
    });

    // Save Action
    const saveBtn = document.getElementById('tx-save-btn');
    saveBtn.addEventListener('click', async () => {
      const amount = parseFloat(document.getElementById('tx-amount-field').value) || 0;
      const note = document.getElementById('tx-note-field').value.trim();
      const date = document.getElementById('tx-date-field').value;
      const paymentMode = document.getElementById('tx-payment-field').value;
      const isRecurring = document.getElementById('tx-recur-field').checked;
      
      const goalField = document.getElementById('tx-goal-field');
      const goalId = goalField ? goalField.value : '';

      if (amount <= 0) {
        alert('Please enter transaction amount.');
        return;
      }
      if (!this.selectedCategoryId) {
        alert('Please select a category.');
        return;
      }

      // Check if user manually corrected categories from a auto-categorized template
      // We will check if the user modified the auto-suggested category
      if (this.autoSuggested && note) {
        // If they left it auto-suggested, let's strengthen rule weights
        await CategorizationEngine.learnFromCorrection(note, this.selectedCategoryId);
      } else if (!this.autoSuggested && note) {
        // If they corrected it, learn the new keyword rule!
        await CategorizationEngine.learnFromCorrection(note, this.selectedCategoryId);
      }

      const txPayload = {
        amount,
        type: this.selectedType,
        categoryId: parseInt(this.selectedCategoryId, 10) || this.selectedCategoryId,
        category_id: parseInt(this.selectedCategoryId, 10) || this.selectedCategoryId,
        timestamp: new Date(date).toISOString(),
        note: note || '',
        paymentMode,
        payment_mode: paymentMode,
        isRecurring,
        is_recurring: isRecurring,
        goalId: goalId ? (parseInt(goalId, 10) || goalId) : null,
        goal_id: goalId ? (parseInt(goalId, 10) || goalId) : null,
      };

      if (this.activeTx) {
        // Edit Action
        // We delete first and add a new one, or updates it directly
        // For simplicity and Firestore consistency, we update or replace it in guest mode
        if (state.isGuestMode) {
          // Replace locally
          const idx = state.transactions.findIndex(t => t.id === this.activeTx.id);
          if (idx !== -1) {
            state.transactions[idx] = { ...this.activeTx, ...txPayload, updated_at: new Date().toISOString() };
            StateManager.saveGuestState();
            StateManager.notify();
          }
        } else {
          // Update in Firestore
          await DbService.addTransaction({
            ...txPayload,
            sync_id: this.activeTx.sync_id
          });
        }
      } else {
        // Add new
        await DbService.addTransaction(txPayload);
      }

      this.close();
    });

    // Delete Button click
    const deleteBtn = document.getElementById('tx-delete-btn');
    if (deleteBtn && this.activeTx) {
      deleteBtn.addEventListener('click', async () => {
        if (confirm('Are you sure you want to delete this transaction?')) {
          await DbService.deleteTransaction(this.activeTx.sync_id, this.activeTx.id);
          this.close();
        }
      });
    }
  }
};
