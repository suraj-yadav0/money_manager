/* Goals Screen Module (savings targets, progress bars, contributions history, and CRUD) */
import { StateManager } from '../state.js';
import { DbService } from '../db.js';
import { Formatters } from '../utils/formatters.js';

export const GoalsPage = {
  activeGoalFilter: 'active', // 'active', 'completed', 'archived'

  render(state) {
    const goalsList = this.getFilteredGoals(state);

    return `
      <div class="animate-fade-in" style="display:flex; flex-direction:column; gap:20px;">
        <!-- Filters tab bar and Add Goal button -->
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div class="tab-bar" style="padding: 2px; border-radius: 20px;">
            <button class="tab-button ${this.activeGoalFilter === 'active' ? 'active' : ''}" 
                    style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                    id="goal-filter-active">Active</button>
            <button class="tab-button ${this.activeGoalFilter === 'completed' ? 'active' : ''}" 
                    style="padding: 6px 12px; font-size: 11px; border-radius: 16px;" 
                    id="goal-filter-completed">Completed</button>
          </div>

          <button class="btn btn-primary" id="goal-create-btn" style="width:auto; padding: 8px 16px; font-size:12px;">
            <span class="material-icons" style="font-size:16px;">add</span>
            New Goal
          </button>
        </div>

        <!-- Goals Grid/List -->
        <div class="goal-card-grid">
          ${goalsList.length === 0 ? `
            <div class="glass-card" style="text-align: center; padding: 40px 20px; color: var(--text-muted);">
              <span class="material-icons" style="font-size: 48px; margin-bottom: 12px; color: var(--glass-border);">track_changes</span>
              <p style="font-size: 14px;">No goals found in this view.</p>
            </div>
          ` : goalsList.map(goal => this.renderGoalCard(goal, state.goalContributions)).join('')}
        </div>
      </div>
    `;
  },

  renderGoalCard(goal, contributions) {
    const percent = Math.min(100, (goal.saved_amount / goal.target_amount) * 100) || 0;
    const daysLeft = Math.ceil((new Date(goal.deadline) - new Date()) / (1000 * 60 * 60 * 24));
    const isCompleted = goal.is_completed || goal.saved_amount >= goal.target_amount;
    const goalContribs = contributions.filter(c => c.goal_id === goal.id || c.goal_id === goal.sync_id);

    return `
      <div class="glass-card" style="position:relative;">
        <div class="goal-card-header">
          <div>
            <div class="goal-name">${goal.name}</div>
            <div class="goal-target">Target: ${Formatters.currency(goal.target_amount)}</div>
          </div>
          <div style="text-align:right;">
            <div style="font-size: 12px; font-weight: 600; color: ${isCompleted ? 'var(--success)' : 'var(--primary)'}">
              ${isCompleted ? 'Completed' : daysLeft > 0 ? `${daysLeft} days left` : 'Overdue'}
            </div>
            <div style="font-size: 10px; color: var(--text-muted); margin-top:2px;">Deadline: ${Formatters.date(goal.deadline)}</div>
          </div>
        </div>

        <div style="margin: 16px 0;">
          <div class="progress-container">
            <div class="progress-bar" style="width: ${percent}%; background: ${isCompleted ? 'var(--success)' : 'var(--primary)'};"></div>
          </div>
          <div class="goal-progress-info">
            <span>${Formatters.currency(goal.saved_amount)} saved</span>
            <span>${percent.toFixed(0)}%</span>
          </div>
        </div>

        <!-- Action Row -->
        <div style="display:flex; justify-content:space-between; align-items:center; margin-top:16px; border-top:1px solid var(--divider); padding-top:12px;">
          <button class="btn btn-outline view-goal-contribs-btn" 
                  style="width:auto; padding:6px 12px; font-size:12px; border:none;"
                  data-sync-id="${goal.sync_id}"
                  data-id="${goal.id || ''}">
            History (${goalContribs.length})
          </button>
          
          <div style="display:flex; gap:8px;">
            ${!isCompleted ? `
              <button class="btn btn-primary add-goal-contrib-btn" 
                      style="width:auto; padding:6px 12px; font-size:12px;"
                      data-sync-id="${goal.sync_id}"
                      data-id="${goal.id || ''}">
                <span class="material-icons" style="font-size:14px;">add</span> Add
              </button>
            ` : goal.is_active !== false ? `
              <button class="btn btn-secondary archive-goal-btn" 
                      style="width:auto; padding:6px 12px; font-size:12px;"
                      data-sync-id="${goal.sync_id}"
                      data-id="${goal.id || ''}">
                Archive
              </button>
            ` : ''}
            <button class="btn-icon delete-goal-btn" 
                    style="width:32px; height:32px; font-size:16px; border:none; background:rgba(239,68,68,0.1); color:var(--error);"
                    data-sync-id="${goal.sync_id}"
                    data-id="${goal.id || ''}">
              <span class="material-icons" style="font-size:16px;">delete_outline</span>
            </button>
          </div>
        </div>
      </div>
    `;
  },

  getFilteredGoals(state) {
    return state.goals.filter(goal => {
      const isComp = goal.is_completed === true || goal.saved_amount >= goal.target_amount;
      if (this.activeGoalFilter === 'active') return goal.is_active !== false && !isComp;
      if (this.activeGoalFilter === 'completed') return isComp;
      return true;
    });
  },

  bindEvents(state) {
    // Goal view filters
    const filterActive = document.getElementById('goal-filter-active');
    if (filterActive) {
      filterActive.addEventListener('click', () => {
        this.activeGoalFilter = 'active';
        StateManager.notify();
      });
    }

    const filterCompleted = document.getElementById('goal-filter-completed');
    if (filterCompleted) {
      filterCompleted.addEventListener('click', () => {
        this.activeGoalFilter = 'completed';
        StateManager.notify();
      });
    }

    // Create Goal click
    const createBtn = document.getElementById('goal-create-btn');
    if (createBtn) {
      createBtn.addEventListener('click', () => {
        this.showCreateGoalModal();
      });
    }

    // Delete goal button click
    const deleteBtns = document.querySelectorAll('.delete-goal-btn');
    deleteBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = parseInt(btn.getAttribute('data-id'), 10) || null;
        if (confirm('Delete this goal and all contributions? This cannot be undone.')) {
          await DbService.deleteGoal(syncId, localId);
        }
      });
    });

    // Archive goal button click
    const archiveBtns = document.querySelectorAll('.archive-goal-btn');
    archiveBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = parseInt(btn.getAttribute('data-id'), 10) || null;
        await DbService.archiveGoal(syncId, localId);
      });
    });

    // Add contribution click
    const addContribBtns = document.querySelectorAll('.add-goal-contrib-btn');
    addContribBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = parseInt(btn.getAttribute('data-id'), 10) || null;
        const goal = state.goals.find(g => g.sync_id === syncId || (localId && g.id === localId));
        if (goal) this.showAddContributionModal(goal);
      });
    });

    // View contribution history click
    const viewHistoryBtns = document.querySelectorAll('.view-goal-contribs-btn');
    viewHistoryBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = parseInt(btn.getAttribute('data-id'), 10) || null;
        const goal = state.goals.find(g => g.sync_id === syncId || (localId && g.id === localId));
        if (goal) this.showContributionHistoryModal(goal, state.goalContributions);
      });
    });
  },

  showCreateGoalModal() {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1E1E2C;">
        <div class="modal-header">
          <h3 style="color:#FFF;">Create New Savings Goal</h3>
          <button class="modal-close" id="goal-modal-close">&times;</button>
        </div>
        
        <div class="form-group">
          <label class="form-label">Goal Name</label>
          <input type="text" class="form-input" id="goal-name-field" placeholder="Buy laptop, Maldives trip, etc.">
        </div>
        
        <div class="form-group">
          <label class="form-label">Target Amount (₹)</label>
          <input type="number" class="form-input" id="goal-target-field" placeholder="100000">
        </div>
        
        <div class="form-group">
          <label class="form-label">Deadline Date</label>
          <input type="date" class="form-input" id="goal-date-field" style="color-scheme:dark;">
        </div>
        
        <div style="display:flex; gap:12px; justify-content:flex-end; margin-top:20px;">
          <button class="btn btn-outline" id="goal-cancel-btn" style="width:auto; padding:10px 20px;">Cancel</button>
          <button class="btn btn-primary" id="goal-save-btn" style="width:auto; padding:10px 20px;">Create Goal</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      document.body.removeChild(overlay);
    };

    document.getElementById('goal-modal-close').addEventListener('click', closeModal);
    document.getElementById('goal-cancel-btn').addEventListener('click', closeModal);

    document.getElementById('goal-save-btn').addEventListener('click', async () => {
      const name = document.getElementById('goal-name-field').value.trim();
      const targetAmount = parseFloat(document.getElementById('goal-target-field').value) || 0;
      const deadline = document.getElementById('goal-date-field').value;

      if (!name) {
        alert('Please enter goal name.');
        return;
      }
      if (targetAmount <= 0) {
        alert('Please enter target amount.');
        return;
      }
      if (!deadline) {
        alert('Please select a deadline.');
        return;
      }

      await DbService.addGoal({
        name,
        targetAmount,
        target_amount: targetAmount,
        deadline: new Date(deadline).toISOString()
      });

      closeModal();
    });
  },

  showAddContributionModal(goal) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1E1E2C;">
        <div class="modal-header">
          <h3 style="color:#FFF;">Add Savings to "${goal.name}"</h3>
          <button class="modal-close" id="contrib-modal-close">&times;</button>
        </div>
        
        <div class="form-group">
          <label class="form-label">Contribution Amount (₹)</label>
          <input type="number" class="form-input" id="contrib-amount-field" placeholder="5000">
        </div>
        
        <div class="form-group">
          <label class="form-label">Note (Optional)</label>
          <input type="text" class="form-input" id="contrib-note-field" placeholder="Saved from bonus, cash back, etc.">
        </div>
        
        <div style="display:flex; gap:12px; justify-content:flex-end; margin-top:20px;">
          <button class="btn btn-outline" id="contrib-cancel-btn" style="width:auto; padding:10px 20px;">Cancel</button>
          <button class="btn btn-primary" id="contrib-save-btn" style="width:auto; padding:10px 20px;">Add Savings</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      document.body.removeChild(overlay);
    };

    document.getElementById('contrib-modal-close').addEventListener('click', closeModal);
    document.getElementById('contrib-cancel-btn').addEventListener('click', closeModal);

    document.getElementById('contrib-save-btn').addEventListener('click', async () => {
      const amount = parseFloat(document.getElementById('contrib-amount-field').value) || 0;
      const note = document.getElementById('contrib-note-field').value.trim();

      if (amount <= 0) {
        alert('Please enter a valid amount.');
        return;
      }

      await DbService.addGoalContribution(goal.sync_id, goal.id, amount, note);
      
      // Also register this savings as an EXPENSE linked to a Goal (matches Flutter's AddTransactionScreen.dart target action)
      const now = new Date().toISOString();
      const savingsCategory = StateManager.state.categories.find(c => c.name === 'Savings');
      
      await DbService.addTransaction({
        amount: amount,
        type: 'expense',
        categoryId: savingsCategory ? savingsCategory.id : 1,
        goalId: goal.id,
        goal_id: goal.id,
        timestamp: now,
        note: `Goal Contribution: ${goal.name}${note ? ' - ' + note : ''}`,
        paymentMode: 'Bank Transfer'
      });

      closeModal();
    });
  },

  showContributionHistoryModal(goal, allContributions) {
    const goalContribs = allContributions
      .filter(c => c.goal_id === goal.id || c.goal_id === goal.sync_id)
      .sort((a, b) => new Date(b.created_at || b.createdAt) - new Date(a.created_at || a.createdAt));

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal-card animate-fade-in" style="background:#1E1E2C; display:flex; flex-direction:column; max-height:80vh; width:95%; max-width:400px; padding:24px 16px;">
        <div class="modal-header" style="margin-bottom:12px;">
          <h3 style="color:#FFF;">Savings History: ${goal.name}</h3>
          <button class="modal-close" id="history-modal-close">&times;</button>
        </div>
        
        <div style="flex:1; overflow-y:auto; padding-right:4px; display:flex; flex-direction:column; gap:12px;" id="history-contribs-list">
          ${goalContribs.length === 0 ? `
            <div style="text-align:center; padding:20px 0; color:var(--text-muted); font-size:13px;">No contributions found.</div>
          ` : goalContribs.map(c => `
            <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid var(--divider); padding-bottom:8px;">
              <div>
                <div style="font-weight:600; font-size:14px; color:var(--success);">+${Formatters.currency(c.amount)}</div>
                <div style="font-size:11px; color:var(--text-muted); margin-top:2px;">${c.note || 'Savings Contribution'}</div>
              </div>
              <div style="display:flex; align-items:center; gap:12px;">
                <div style="font-size:11px; color:var(--text-muted);">${Formatters.shortDate(c.created_at || c.createdAt)}</div>
                <button class="btn-icon delete-contrib-row-btn" 
                        style="width:28px; height:28px; font-size:14px; border:none; background:rgba(239,68,68,0.1); color:var(--error);"
                        data-sync-id="${c.sync_id}"
                        data-id="${c.id || ''}"
                        data-goal-sync-id="${goal.sync_id}"
                        data-goal-local-id="${goal.id || ''}">
                  <span class="material-icons" style="font-size:14px;">delete_outline</span>
                </button>
              </div>
            </div>
          `).join('')}
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const closeModal = () => {
      document.body.removeChild(overlay);
    };

    document.getElementById('history-modal-close').addEventListener('click', closeModal);

    // Bind delete contribution click buttons
    const deleteRowBtns = overlay.querySelectorAll('.delete-contrib-row-btn');
    deleteRowBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        const syncId = btn.getAttribute('data-sync-id');
        const localId = parseInt(btn.getAttribute('data-id'), 10) || null;
        const goalSyncId = btn.getAttribute('data-goal-sync-id');
        const goalLocalId = parseInt(btn.getAttribute('data-goal-local-id'), 10) || null;

        if (confirm('Delete this contribution record?')) {
          await DbService.deleteGoalContribution(syncId, localId, goalSyncId, goalLocalId);
          closeModal();
          // Re-open history to show updated state
          this.showContributionHistoryModal(goal, StateManager.state.goalContributions);
        }
      });
    });
  }
};
